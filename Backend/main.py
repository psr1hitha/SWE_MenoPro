from fastapi import FastAPI, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
import firebase_admin
from firebase_admin import credentials, firestore
import jwt
import datetime
from typing import Optional

# Initialize Firebase
cred = credentials.Certificate("serviceAccount.json")
firebase_admin.initialize_app(cred)
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
    bmi: Optional[float] = None
    is_smoker: Optional[bool] = None
    alcohol_per_week: Optional[int] = None
    caffeine_per_week: Optional[int] = None
    race: Optional[str] = None

class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

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


