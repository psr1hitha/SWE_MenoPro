import os
import datetime
import jwt
import joblib
import numpy as np
import pandas as pd
import bcrypt
import firebase_admin
from firebase_admin import credentials, firestore, db as realtime_db
from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import Optional

# ── App + security setup ──
app = FastAPI()
security = HTTPBearer()
SECRET_KEY = os.environ.get("JWT_SECRET", "change-me-in-production")

# ── Firebase init ──
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
cred_path = os.path.join(BASE_DIR, "firebase_credentials.json")

if not firebase_admin._apps:
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred, {
        "databaseURL": os.environ.get(
            "FIREBASE_DB_URL",
            "https://menopro-a2b17-default-rtdb.firebaseio.com/"
        )
    })

db = firestore.client()

# ── Load model artifacts ONCE at startup ──
model = joblib.load(os.path.join(BASE_DIR, "rf_model.pkl"))
scaler = joblib.load(os.path.join(BASE_DIR, "scaler.pkl"))
feature_columns = joblib.load(os.path.join(BASE_DIR, "feature_columns.pkl"))

RACE_MAP = {
    "White": 1, "Black or African American": 2, "Asian": 3,
    "Hispanic or Latino": 4, "Native American": 5, "Pacific Islander": 6,
    "Middle Eastern": 7, "Mixed": 8, "Other": 9, "Prefer not to say": 0,
}


# ═════════════════════════════════════════════════════
#                    REQUEST MODELS
# ═════════════════════════════════════════════════════

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
    display_name: Optional[str] = None  # for community chat


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
    display_name: Optional[str] = None


class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str


class PredictRequest(BaseModel):
    user_email: str


class LogHotFlashRequest(BaseModel):
    user_email: str
    date: Optional[str] = None  # YYYY-MM-DD; defaults to today
    note: Optional[str] = None


# ═════════════════════════════════════════════════════
#                    HELPERS
# ═════════════════════════════════════════════════════

# ── Password helpers ──
def hash_password(pw: str) -> str:
    return bcrypt.hashpw(pw.encode(), bcrypt.gensalt()).decode()


def verify_password(pw: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(pw.encode(), hashed.encode())
    except Exception:
        return pw == hashed  # legacy plain-text compatibility


# ── JWT helpers ──
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


# ── Risk bucket mapping ──
def probability_to_risk(p: float) -> tuple[int, str, str]:
    """Returns (percent 0-100, risk_level, message)."""
    percent = round(p * 100)
    if p >= 0.8:
        return percent, "Imminent", "Hot flash imminent!"
    elif p >= 0.6:
        return percent, "Soon", "Hot flash likely soon (within 15 min)"
    elif p >= 0.3:
        return percent, "Moderate", "Moderate risk (within 30 min)"
    else:
        return percent, "Low Risk", "Low risk"


# ── Profile feature builder ──
def build_profile_features(user: dict) -> dict:
    return {
        "s_age": user.get("age", 0),
        "s_bmi": user.get("bmi", 0.0),
        "s_race": RACE_MAP.get(user.get("race", ""), 0),
        "s_stage": user.get("menopause_stage", 1),
        "s_smoking": 1 if user.get("is_smoker", False) else 0,
        "s_alcohol": user.get("alcohol_per_week", 0),
        "s_medication": user.get("medication", 0),
        "s_stress": user.get("stress_level", 0),
        "s_caffeine": user.get("caffeine_per_week", 0),
        "s_exercise": user.get("exercise_level", 0),
        "s_thyroid": user.get("thyroid", 0),
        "s_diabetes": user.get("diabetes", 0),
        "s_cardiovascular": user.get("cardiovascular", 0),
        "s_mental_health": user.get("mental_health", 0),
        "s_surgical": user.get("surgical", 0),
    }


# ── Derive missing sensor fields from epoch ──
def epoch_to_derived_fields(epoch: int, skin_temp_c: float) -> dict:
    """
    Build the 4 sensor fields the Arduino doesn't send:
        t_sec         → seconds since local midnight
        hour          → decimal hour (0.0–23.99)
        core_temp_est → rough estimate from skin temp
        is_sleep      → 1 between 22:00 and 07:00
    """
    dt = datetime.datetime.fromtimestamp(epoch)
    t_sec = dt.hour * 3600 + dt.minute * 60 + dt.second
    hour = dt.hour + dt.minute / 60.0 + dt.second / 3600.0
    is_sleep = 1 if (dt.hour >= 22 or dt.hour < 7) else 0
    core_temp_est = min(max(skin_temp_c + 2.7, 36.0), 37.5)
    return {
        "t_sec": t_sec,
        "hour": hour,
        "is_sleep": is_sleep,
        "core_temp_est": core_temp_est,
    }


# ── Fetch + pair sensor history from Arduino's Firebase structure ──
def fetch_paired_sensor_history(limit_rows: int = 30) -> pd.DataFrame:
    """
    Arduino writes temp and HR to separate keys like:
        /sensor_data/history/1714678923_temp  → {temperature_c, epoch, ...}
        /sensor_data/history/1714678923_hr    → {heart_rate, epoch, ...}

    Pair them by nearest epoch and return a chronological DataFrame
    with all 6 sensor fields the model expects.
    """
    ref = realtime_db.reference("/sensor_data/history")
    all_entries = ref.get()
    if not all_entries:
        return pd.DataFrame()

    temps, hrs = [], []
    for key, val in all_entries.items():
        if not val or "epoch" not in val:
            continue
        if key.endswith("_temp") and "temperature_c" in val:
            temps.append({"epoch": int(val["epoch"]),
                          "skin_temp": float(val["temperature_c"])})
        elif key.endswith("_hr") and "heart_rate" in val:
            hrs.append({"epoch": int(val["epoch"]),
                        "heart_rate": int(val["heart_rate"])})

    if not temps or not hrs:
        return pd.DataFrame()

    temps_df = pd.DataFrame(temps).sort_values("epoch").reset_index(drop=True)
    hrs_df = pd.DataFrame(hrs).sort_values("epoch").reset_index(drop=True)

    paired = pd.merge_asof(
        temps_df, hrs_df,
        on="epoch",
        direction="nearest",
        tolerance=10,
    )
    paired = paired.dropna(subset=["heart_rate"])
    if paired.empty:
        return pd.DataFrame()

    paired["heart_rate"] = paired["heart_rate"].astype(int)
    paired = paired.tail(limit_rows).reset_index(drop=True)

    derived = paired.apply(
        lambda r: epoch_to_derived_fields(int(r["epoch"]), float(r["skin_temp"])),
        axis=1, result_type="expand"
    )

    return pd.concat([paired, derived], axis=1)


# ── Compute delta features from paired history ──
def compute_deltas(sensors: pd.DataFrame) -> dict:
    skin = sensors["skin_temp"].values
    hr = sensors["heart_rate"].values
    core = sensors["core_temp_est"].values
    return {
        "skin_temp_d2":      skin[-1] - skin[-6],
        "skin_temp_d5":      skin[-1] - skin[-11],
        "skin_temp_d10":     skin[-1] - skin[-21],
        "heart_rate_d2":     hr[-1]   - hr[-6],
        "heart_rate_d5":     hr[-1]   - hr[-11],
        "heart_rate_d10":    hr[-1]   - hr[-21],
        "core_temp_est_d2":  core[-1] - core[-6],
        "core_temp_est_d5":  core[-1] - core[-11],
        "core_temp_est_d10": core[-1] - core[-21],
    }


# ═════════════════════════════════════════════════════
#                    ENDPOINTS
# ═════════════════════════════════════════════════════

@app.get("/")
def root():
    return {"message": "MenoPro API is running!"}


# ── Sign up ──
@app.post("/signup")
def signup(data: SignUpRequest):
    existing = db.collection("users").where("email", "==", data.email).get()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")

    db.collection("users").add({
        "first_name": data.first_name,
        "last_name": data.last_name,
        "email": data.email,
        "password": hash_password(data.password),
        "age": data.age,
        "height": data.height,
        "weight": data.weight,
        "bmi": data.bmi,
        "is_smoker": data.is_smoker,
        "alcohol_per_week": data.alcohol_per_week,
        "caffeine_per_week": data.caffeine_per_week,
        "race": data.race,
        "display_name": data.display_name or data.first_name,
    })
    return {"message": "Signup successful", "token": create_token(data.email)}


# ── Login ──
@app.post("/login")
def login(data: LoginRequest):
    users = db.collection("users").where("email", "==", data.email).get()
    if not users:
        raise HTTPException(status_code=404, detail="User not found")

    user = users[0].to_dict()
    if not verify_password(data.password, user["password"]):
        raise HTTPException(status_code=401, detail="Incorrect password")

    return {"message": "Login successful", "token": create_token(data.email)}


# ── Profile ──
@app.get("/profile")
def get_profile(email: str = Depends(get_current_user)):
    doc = get_user_doc(email)
    data = doc.to_dict()
    data.pop("password", None)
    return data


@app.patch("/profile")
def update_profile(data: UpdateProfileRequest, email: str = Depends(get_current_user)):
    doc = get_user_doc(email)
    updates = {k: v for k, v in data.dict().items() if v is not None}
    if not updates:
        raise HTTPException(status_code=400, detail="No fields to update")
    doc.reference.update(updates)
    return {"message": "Profile updated successfully"}


# ── Change password ──
@app.post("/change-password")
def change_password(data: ChangePasswordRequest, email: str = Depends(get_current_user)):
    doc = get_user_doc(email)
    user = doc.to_dict()

    if not verify_password(data.current_password, user["password"]):
        raise HTTPException(status_code=401, detail="Current password is incorrect")
    if len(data.new_password) < 7:
        raise HTTPException(status_code=400, detail="Password must be at least 7 characters")

    doc.reference.update({"password": hash_password(data.new_password)})
    return {"message": "Password changed successfully"}


# ── PREDICT (v2 classifier, reads Arduino sensor history) ──
@app.post("/predict")
def predict(data: PredictRequest):
    # 1. Pull user profile from Firestore
    users = db.collection("users").where("email", "==", data.user_email).get()
    if not users:
        raise HTTPException(status_code=404, detail="User not found")
    user = users[0].to_dict()

    # 2. Pull + pair sensor history from Realtime DB
    sensors = fetch_paired_sensor_history(limit_rows=30)

    if sensors.empty:
        raise HTTPException(
            status_code=503,
            detail="No sensor data available. Make sure Arduino is running."
        )

    if len(sensors) < 21:
        return {
            "status": "calibrating",
            "message": f"Need {21 - len(sensors)} more paired readings before prediction",
            "readings_available": len(sensors),
            "risk_percent": None,
            "risk_level": None,
        }

    # 3. Compute rate-of-change features
    deltas = compute_deltas(sensors)

    # 4. Build 30-feature vector
    current = sensors.iloc[-1]
    sensor_feats = {
        "t_sec":         current["t_sec"],
        "hour":          current["hour"],
        "skin_temp":     current["skin_temp"],
        "heart_rate":    current["heart_rate"],
        "core_temp_est": current["core_temp_est"],
        "is_sleep":      current["is_sleep"],
    }
    features = {**sensor_feats, **build_profile_features(user), **deltas}

    # 5. Force column order to match training, scale, predict
    X = pd.DataFrame([features])[feature_columns]
    X_scaled = scaler.transform(X)
    probability = float(model.predict_proba(X_scaled)[0][1])

    # 6. Map to percent + risk bucket
    percent, risk_level, message = probability_to_risk(probability)

    # 7. Save to prediction history
    db.collection("predictions").add({
        "user_email": data.user_email,
        "skin_temp_c": round(float(current["skin_temp"]), 2),
        "heart_rate": int(current["heart_rate"]),
        "risk_percent": percent,
        "risk_level": risk_level,
        "timestamp": datetime.datetime.utcnow(),
    })

    return {
        "status": "ok",
        "risk_percent": percent,
        "risk_level": risk_level,
        "message": message,
        "skin_temp_c": round(float(current["skin_temp"]), 2),
        "heart_rate": int(current["heart_rate"]),
    }


# ── Prediction history ──
@app.get("/history")
def get_history(email: str = Depends(get_current_user)):
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
        if "timestamp" in entry and entry["timestamp"]:
            entry["timestamp"] = entry["timestamp"].isoformat()
        results.append(entry)

    return {"predictions": results}


# ═════════════════════════════════════════════════════
#                HOT FLASH EVENTS (CALENDAR)
# ═════════════════════════════════════════════════════

@app.post("/hot-flash-events")
def log_hot_flash(data: LogHotFlashRequest, email: str = Depends(get_current_user)):
    """Manually log a hot flash for a given date (defaults to today)."""
    if data.user_email != email:
        raise HTTPException(status_code=403, detail="Forbidden")

    log_date = data.date or datetime.date.today().isoformat()

    # Use deterministic doc ID so re-logging the same day overwrites instead of duplicating
    doc_id = f"{email}_{log_date}"
    db.collection("hot_flash_events").document(doc_id).set({
        "user_email": email,
        "date": log_date,
        "note": data.note or "",
        "source": "manual",
        "created_at": datetime.datetime.utcnow(),
    })
    return {"message": "Hot flash logged", "date": log_date}


@app.delete("/hot-flash-events/{event_date}")
def unlog_hot_flash(event_date: str, email: str = Depends(get_current_user)):
    """Remove a manual hot flash log for a given date."""
    doc_id = f"{email}_{event_date}"
    db.collection("hot_flash_events").document(doc_id).delete()
    return {"message": "Hot flash unlogged", "date": event_date}


@app.get("/hot-flash-events")
def get_hot_flash_events(email: str = Depends(get_current_user)):
    """
    Return all dates this user had a hot flash, combining:
      - manual logs from /hot_flash_events collection
      - auto-detected from /predictions where risk_level in {Imminent, Soon}
    Deduplicated by date.
    """
    dates = set()

    # Manual logs
    manual = db.collection("hot_flash_events").where("user_email", "==", email).get()
    for doc in manual:
        d = doc.to_dict().get("date")
        if d:
            dates.add(d)

    # Auto-detected from predictions (risk_level Soon or Imminent => risk >= 60%)
    preds = (
        db.collection("predictions")
        .where("user_email", "==", email)
        .where("risk_level", "in", ["Soon", "Imminent"])
        .get()
    )
    for doc in preds:
        ts = doc.to_dict().get("timestamp")
        if ts:
            # ts is a datetime (Firestore timestamp); convert to YYYY-MM-DD
            if hasattr(ts, "date"):
                dates.add(ts.date().isoformat())
            else:
                # If it came back as a string, take the first 10 chars
                dates.add(str(ts)[:10])

    return {"dates": sorted(dates)}