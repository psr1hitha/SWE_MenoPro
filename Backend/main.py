from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import firebase_admin
from firebase_admin import credentials, firestore, db as realtime_db
import jwt
import datetime
import os
import numpy as np
import joblib
from typing import Optional

# Initialize Firebase with both Firestore and Realtime Database
cred = credentials.Certificate("serviceAccount.json")
firebase_admin.initialize_app(cred, {
    "databaseURL": "https://menopro-a2b17-default-rtdb.firebaseio.com"
})
db = firestore.client()

app = FastAPI()

SECRET_KEY = "menopro-secret-key"
security = HTTPBearer()

# ── Models ───
class SignUpRequest(BaseModel):
    first_name: str
    last_name: str
    email: str
    password: str
    age: int
    height: float
    weight: float
    bmi: float
    is_smoker: bool
    alcohol_per_week: int
    caffeine_per_week: int
    race: str

class LoginRequest(BaseModel):
    email: str
    password: str

class UpdateProfileRequest(BaseModel):
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    age: Optional[int] = None
    height: Optional[float] = None
    weight: Optional[float] = None
    bmi: Optional[float] = None
    is_smoker: Optional[bool] = None
    alcohol_per_week: Optional[int] = None
    caffeine_per_week: Optional[int] = None
    race: Optional[str] = None

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

class PredictRequest(BaseModel):
    user_email: str  # Only need email — sensor data comes from Firebase Realtime DB

# Race string-to-integer encoding (must match training data encoding)
RACE_MAP = {
    "White": 1,
    "Black or African American": 2,
    "Asian": 3,
    "Hispanic or Latino": 4,
    "Native American": 5,
    "Pacific Islander": 6,
    "Middle Eastern": 7,
    "Mixed": 8,
    "Other": 9,
    "Prefer not to say": 0,
}

# ── JWT helpers ───
def create_token(email: str) -> str:
    payload = {
        "email": email,
        "exp": datetime.datetime.utcnow() + datetime.timedelta(days=30)
    }
    return jwt.encode(payload, SECRET_KEY, algorithm="HS256")

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=["HS256"])
        return payload["email"]
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid token")

def get_user_doc(email: str):
    users = db.collection("users").where("email", "==", email).get()
    if not users:
        raise HTTPException(status_code=404, detail="User not found")
    return users[0]

# ── Root ────
@app.get("/")
def root():
    return {"message": "Menopro API is running!"}

# ── Sign up ────
@app.post("/signup")
def signup(data: SignUpRequest):
    existing = db.collection("users").where("email", "==", data.email).get()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    db.collection("users").add({
        "first_name": data.first_name,
        "last_name": data.last_name,
        "email": data.email,
        "password": data.password,
        "age": data.age,
        "height": data.height,
        "weight": data.weight,
        "bmi": data.bmi,
        "is_smoker": data.is_smoker,
        "alcohol_per_week": data.alcohol_per_week,
        "caffeine_per_week": data.caffeine_per_week,
        "race": data.race
    })
    token = create_token(data.email)
    return {"message": "Signup successful", "token": token}

# ── Login ────
@app.post("/login")
def login(data: LoginRequest):
    users = db.collection("users").where("email", "==", data.email).get()
    if not users:
        raise HTTPException(status_code=404, detail="User not found")

    user = users[0].to_dict()
    if user["password"] != data.password:
        raise HTTPException(status_code=401, detail="Incorrect password")

    token = create_token(data.email)
    return {"message": "Login successful", "token": token}

# ── Get profile ────
@app.get("/profile")
def get_profile(email: str = Depends(get_current_user)):
    doc = get_user_doc(email)
    data = doc.to_dict()
    data.pop("password", None)
    return data

# ── Update profile ────
@app.patch("/profile")
def update_profile(data: UpdateProfileRequest, email: str = Depends(get_current_user)):
    doc = get_user_doc(email)
    updates = {k: v for k, v in data.dict().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    doc.reference.update(updates)
    return {"message": "Profile updated successfully"}

# ── Predict hot flash ────
@app.post("/predict")
def predict(data: PredictRequest):
    # Read latest sensor data from Firebase Realtime Database
    temp_ref = realtime_db.reference("/sensor_data/temperature")
    hr_ref = realtime_db.reference("/sensor_data/heart_rate")

    temp_data = temp_ref.get()
    hr_data = hr_ref.get()

    # Validate sensor data exists
    if temp_data is None or hr_data is None:
        raise HTTPException(status_code=503, detail="Sensor data not available. Make sure Arduino is running.")

    # Extract sensor values — temperature is already in Celsius from Arduino
    skin_temp_c = temp_data.get("temperature_c", None)
    heart_rate = hr_data.get("heart_rate", None)

    # Validate that both values are present
    if skin_temp_c is None or heart_rate is None:
        raise HTTPException(status_code=503, detail="Invalid sensor data format from Arduino.")

    # Get current hour for circadian features
    current_hour = datetime.datetime.now().hour + datetime.datetime.now().minute / 60.0

    # Infer sleep state based on hour (10 PM to 7 AM)
    is_sleep = 1 if (current_hour >= 22 or current_hour < 7) else 0

    # Fetch user profile from Firestore for static features
    users = db.collection("users").where("email", "==", data.user_email).get()
    if not users:
        raise HTTPException(status_code=404, detail="User not found")

    user = users[0].to_dict()

    # Encode race string to integer using the training mapping
    race_encoded = RACE_MAP.get(user.get("race", ""), 0)

    # Build the feature vector in the exact order used during training:
    # subject_id, t_sec, hour, skin_temp, heart_rate, core_temp_est, is_sleep,
    # s_age, s_bmi, s_race, s_stage, s_smoking, s_alcohol, s_medication,
    # s_stress, s_caffeine, s_exercise, s_thyroid, s_diabetes,
    # s_cardiovascular, s_mental_health, s_surgical
    features = [
        0,                                          # subject_id (placeholder)
        0,                                          # t_sec (placeholder)
        current_hour,                               # hour
        skin_temp_c,                                # skin_temp (Celsius, read directly from Arduino)
        heart_rate,                                 # heart_rate
        37.0,                                       # core_temp_est (clinical default)
        is_sleep,                                   # is_sleep
        user.get("age", 0),                         # s_age
        user.get("bmi", 0.0),                       # s_bmi
        race_encoded,                               # s_race
        1,                                          # s_stage (default: perimenopause)
        1 if user.get("is_smoker", False) else 0,   # s_smoking
        user.get("alcohol_per_week", 0),            # s_alcohol
        0,                                          # s_medication (not collected)
        0,                                          # s_stress (not collected)
        user.get("caffeine_per_week", 0),           # s_caffeine
        0,                                          # s_exercise (not collected)
        0,                                          # s_thyroid (not collected)
        0,                                          # s_diabetes (not collected)
        0,                                          # s_cardiovascular (not collected)
        0,                                          # s_mental_health (not collected)
        0,                                          # s_surgical (not collected)
    ]

    # Load the trained model and scaler from disk
    base_dir = os.path.dirname(os.path.abspath(__file__))
    model_path = os.path.join(base_dir, "rf_model.pkl")
    scaler_path = os.path.join(base_dir, "scaler.pkl")

    if not os.path.exists(model_path) or not os.path.exists(scaler_path):
        raise HTTPException(status_code=500, detail="Model files not found on server")

    model = joblib.load(model_path)
    scaler = joblib.load(scaler_path)

    # Scale input and run inference
    X = np.array(features).reshape(1, -1)
    X_scaled = scaler.transform(X)

    prediction = model.predict(X_scaled)[0]
    probability = model.predict_proba(X_scaled)[0][1]  # probability of hot flash (class 1)

    # Save prediction result to Firestore for history tracking
    db.collection("predictions").add({
        "user_email": data.user_email,
        "skin_temp_c": round(skin_temp_c, 2),
        "heart_rate": heart_rate,
        "hot_flash_predicted": bool(prediction),
        "probability": round(float(probability), 4),
        "timestamp": datetime.datetime.utcnow()
    })

    return {
        "hot_flash_predicted": bool(prediction),
        "probability": float(probability),
        "skin_temp_c": round(skin_temp_c, 2),
        "heart_rate": heart_rate,
    }

# ── Get prediction history ────
@app.get("/history")
def get_history(email: str = Depends(get_current_user)):
    # Fetch the last 20 predictions for this user, sorted by most recent
    predictions = (
        db.collection("predictions")
        .where("user_email", "==", email)
        .order_by("timestamp", direction=firestore.Query.DESCENDING)
        .limit(20)
        .get()
    )

    results = []
    for doc in predictions:
        entry = doc.to_dict()
        # Convert Firestore timestamp to readable ISO string
        if "timestamp" in entry and entry["timestamp"]:
            entry["timestamp"] = entry["timestamp"].isoformat()
        results.append(entry)

    return {"predictions": results}

# ── Change password ───
@app.post("/change-password")
def change_password(data: ChangePasswordRequest, email: str = Depends(get_current_user)):
    doc = get_user_doc(email)
    user = doc.to_dict()

    if user["password"] != data.current_password:
        raise HTTPException(status_code=401, detail="Current password is incorrect")
    if len(data.new_password) < 7:
        raise HTTPException(status_code=400, detail="Password must be at least 7 characters")

    doc.reference.update({"password": data.new_password})
    return {"message": "Password changed successfully"}