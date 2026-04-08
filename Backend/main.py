from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
cred = credentials.Certificate("serviceAccount.json")
firebase_admin.initialize_app(cred)
db = firestore.client()

app = FastAPI()

# Sign up request structure
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

# Login request structure
class LoginRequest(BaseModel):
    email: str
    password: str

# Test root
@app.get("/")
def root():
    return {"message": "Menopro API is running!"}

# Sign up API
@app.post("/signup")
def signup(data: SignUpRequest):
    # Check if email already exists
    users_ref = db.collection("users")
    existing = users_ref.where("email", "==", data.email).get()
    if existing:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    # Save to Firestore
    users_ref.add({
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
    return {"message": "Signup successful", "email": data.email}

# Login API
@app.post("/login")
def login(data: LoginRequest):
    # Find user by email
    users_ref = db.collection("users")
    users = users_ref.where("email", "==", data.email).get()
    
    if not users:
        raise HTTPException(status_code=404, detail="User not found")
    
    user = users[0].to_dict()
    
    if user["password"] != data.password:
        raise HTTPException(status_code=401, detail="Incorrect password")
    
    return {"message": "Login successful", "email": data.email}