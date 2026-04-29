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
    menopause_stage: Optional[int] = 2
    stress_level: Optional[int] = 1
    medication: Optional[int] = 0
    exercise_level: Optional[int] = 2
    thyroid: Optional[bool] = False
    diabetes: Optional[bool] = False
    cardiovascular: Optional[bool] = False
    mental_health: Optional[bool] = False
    surgical: Optional[bool] = False

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
        "menopause_stage": data.menopause_stage,
        "stress_level": data.stress_level,
        "medication": data.medication,
        "exercise_level": data.exercise_level,
        "thyroid": data.thyroid,
        "diabetes": data.diabetes,
        "cardiovascular": data.cardiovascular,
        "mental_health": data.mental_health,
        "surgical": data.surgical,
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

# ═════════════════════════════════════════════════════
#               COMMUNITY — REQUEST MODELS
# ═════════════════════════════════════════════════════

class CreatePostRequest(BaseModel):
    title: str
    body: str
    is_anonymous: bool = False


class UpdatePostRequest(BaseModel):
    title: Optional[str] = None
    body: Optional[str] = None
    is_anonymous: Optional[bool] = None

class CreateCommentRequest(BaseModel):
    post_id: str
    body: str
    is_anonymous: bool = False


class ReportRequest(BaseModel):
    target_id: str          # post or comment doc ID
    target_type: str        # "post" or "comment"
    reason: Optional[str] = None


# ═════════════════════════════════════════════════════
#               COMMUNITY — HELPERS
# ═════════════════════════════════════════════════════

def _resolve_display_name(user: dict, is_anonymous: bool) -> str:
    """Return the author label based on anonymity choice."""
    if is_anonymous:
        return "Anonymous"
    return user.get("display_name") or user.get("first_name") or "User"


def _serialize_post(doc, viewer_email: str = "") -> dict:
    d = doc.to_dict()
    d["id"] = doc.id
    if "created_at" in d and d["created_at"]:
        d["created_at"] = d["created_at"].isoformat()
    if "updated_at" in d and d["updated_at"]:
        d["updated_at"] = d["updated_at"].isoformat()
    # Check is_owner BEFORE removing author_email
    d["is_owner"] = (viewer_email != "" and viewer_email == d.get("author_email", ""))
    d["liked_by_viewer"] = viewer_email in d.get("liked_by", [])
    d.pop("liked_by", None)
    # Remove author_email only for anonymous posts AFTER is_owner is set
    if d.get("is_anonymous"):
        d.pop("author_email", None)
    return d


def _serialize_comment(doc, viewer_email: str = "") -> dict:
    d = doc.to_dict()
    d["id"] = doc.id
    if "created_at" in d and d["created_at"]:
        d["created_at"] = d["created_at"].isoformat()
    # Check is_owner BEFORE removing author_email
    d["is_owner"] = (viewer_email != "" and viewer_email == d.get("author_email", ""))
    # Remove author_email only for anonymous comments AFTER is_owner is set
    if d.get("is_anonymous"):
        d.pop("author_email", None)
    return d


# ═════════════════════════════════════════════════════
#               COMMUNITY — ENDPOINTS
# ═════════════════════════════════════════════════════

# ── Create post ──
@app.post("/community/posts")
def create_post(data: CreatePostRequest, email: str = Depends(get_current_user)):
    user_doc = get_user_doc(email)
    user = user_doc.to_dict()

    display_name = _resolve_display_name(user, data.is_anonymous)

    _, ref = db.collection("community_posts").add({
        "title": data.title,
        "body": data.body,
        "is_anonymous": data.is_anonymous,
        "author_email": email,
        "author_name": display_name,
        "like_count": 0,
        "liked_by": [],
        "comment_count": 0,
        "created_at": datetime.datetime.utcnow(),
        "updated_at": datetime.datetime.utcnow(),
    })
    return {"message": "Post created", "post_id": ref.id}


# ── Get feed ──
@app.get("/community/posts")
def get_posts(
    limit: int = 20,
    author_me: bool = False,
    email: str = Depends(get_current_user),
):
    query = db.collection("community_posts").order_by(
        "created_at", direction=firestore.Query.DESCENDING
    )
    if author_me:
        query = query.where("author_email", "==", email)

    docs = query.limit(limit).get()
    return {"posts": [_serialize_post(d, email) for d in docs]}


# ── Get single post ──
@app.get("/community/posts/{post_id}")
def get_post(post_id: str, email: str = Depends(get_current_user)):
    doc = db.collection("community_posts").document(post_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Post not found")
    return _serialize_post(doc, email)


# ── Update post (owner only) ──
@app.patch("/community/posts/{post_id}")
def update_post(
    post_id: str,
    data: UpdatePostRequest,
    email: str = Depends(get_current_user),
):
    doc = db.collection("community_posts").document(post_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Post not found")
    if doc.to_dict().get("author_email") != email:
        raise HTTPException(status_code=403, detail="Not your post")

    # Use exclude_unset=True so only fields actually sent are updated
    updates = data.dict(exclude_unset=False)
    # Remove None values but keep False (is_anonymous can be False)
    updates = {k: v for k, v in updates.items() if v is not None}

    # Always include title and body if provided
    if data.title is not None:
        updates["title"] = data.title
    if data.body is not None:
        updates["body"] = data.body

    # If anonymity changed, update author_name accordingly
    if data.is_anonymous is not None:
        user = get_user_doc(email).to_dict()
        updates["is_anonymous"] = data.is_anonymous
        updates["author_name"] = _resolve_display_name(user, data.is_anonymous)

    updates["updated_at"] = datetime.datetime.utcnow()
    doc.reference.update(updates)
    return {"message": "Post updated"}


# ── Delete post (owner only) ──
@app.delete("/community/posts/{post_id}")
def delete_post(post_id: str, email: str = Depends(get_current_user)):
    doc = db.collection("community_posts").document(post_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Post not found")
    if doc.to_dict().get("author_email") != email:
        raise HTTPException(status_code=403, detail="Not your post")

    # Also delete all comments for this post
    comments = db.collection("community_comments").where("post_id", "==", post_id).get()
    for c in comments:
        c.reference.delete()

    doc.reference.delete()
    return {"message": "Post deleted"}


# ── Like toggle ──
@app.post("/community/posts/{post_id}/like")
def toggle_like(post_id: str, email: str = Depends(get_current_user)):
    ref = db.collection("community_posts").document(post_id)
    doc = ref.get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Post not found")

    liked_by: list = doc.to_dict().get("liked_by", [])
    if email in liked_by:
        liked_by.remove(email)
        liked = False
    else:
        liked_by.append(email)
        liked = True

    ref.update({"liked_by": liked_by, "like_count": len(liked_by)})
    return {"liked": liked, "like_count": len(liked_by)}


# ── Get comments for a post ──
@app.get("/community/posts/{post_id}/comments")
def get_comments(post_id: str, email: str = Depends(get_current_user)):
    docs = (
        db.collection("community_comments")
        .where("post_id", "==", post_id)
        .order_by("created_at", direction=firestore.Query.ASCENDING)
        .get()
    )
    return {"comments": [_serialize_comment(d, email) for d in docs]}


# ── Create comment ──
@app.post("/community/posts/{post_id}/comments")
def create_comment(
    post_id: str,
    data: CreateCommentRequest,
    email: str = Depends(get_current_user),
):
    post_ref = db.collection("community_posts").document(post_id)
    post_doc = post_ref.get()
    if not post_doc.exists:
        raise HTTPException(status_code=404, detail="Post not found")

    user = get_user_doc(email).to_dict()
    display_name = _resolve_display_name(user, data.is_anonymous)

    db.collection("community_comments").add({
        "post_id": post_id,
        "body": data.body,
        "is_anonymous": data.is_anonymous,
        "author_email": email,
        "author_name": display_name,
        "created_at": datetime.datetime.utcnow(),
    })

    # Increment comment_count on the post
    post_ref.update({"comment_count": firestore.Increment(1)})
    return {"message": "Comment added"}


# ── Delete comment (owner only) ──
@app.delete("/community/comments/{comment_id}")
def delete_comment(comment_id: str, email: str = Depends(get_current_user)):
    doc = db.collection("community_comments").document(comment_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Comment not found")
    if doc.to_dict().get("author_email") != email:
        raise HTTPException(status_code=403, detail="Not your comment")

    post_id = doc.to_dict().get("post_id")
    doc.reference.delete()

    # Decrement comment_count
    if post_id:
        post_ref = db.collection("community_posts").document(post_id)
        post_ref.update({"comment_count": firestore.Increment(-1)})

    return {"message": "Comment deleted"}


# ── Report ──
@app.post("/community/reports")
def report_content(data: ReportRequest, email: str = Depends(get_current_user)):
    # Prevent duplicate reports from same user on same target
    existing = (
        db.collection("community_reports")
        .where("reporter_email", "==", email)
        .where("target_id", "==", data.target_id)
        .get()
    )
    if existing:
        raise HTTPException(status_code=400, detail="Already reported")

    db.collection("community_reports").add({
        "reporter_email": email,
        "target_id": data.target_id,
        "target_type": data.target_type,
        "reason": data.reason or "",
        "created_at": datetime.datetime.utcnow(),
    })
    return {"message": "Reported"}


# ── My posts ──
@app.get("/community/my-posts")
def get_my_posts(email: str = Depends(get_current_user)):
    docs = (
        db.collection("community_posts")
        .where("author_email", "==", email)
        .order_by("created_at", direction=firestore.Query.DESCENDING)
        .get()
    )
    return {"posts": [_serialize_post(d, email) for d in docs]}