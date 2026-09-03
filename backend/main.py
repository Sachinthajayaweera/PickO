import os
import shutil
import uuid
import math
import hmac
import hashlib
import json
import base64
import time
from typing import List, Optional
from fastapi import FastAPI, HTTPException, Depends, Form, File, UploadFile, Security
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from database import get_db_connection, release_db_connection, init_db, POSTGIS_AVAILABLE

app = FastAPI(
    title="PickO Logistics API",
    description="Python FastAPI backend serving crowdshipping inter-city parcel delivery system.",
    version="1.0.0"
)

# CORS configuration to allow connections from Flutter clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Ensure uploads directory exists
os.makedirs("uploads", exist_ok=True)
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# Security helpers
SECRET_KEY = os.getenv("JWT_SECRET_KEY", "picko_super_secret_key_123456")
security = HTTPBearer()

def hash_password(password: str) -> str:
    salt = os.urandom(16).hex()
    key = hashlib.pbkdf2_hmac(
        'sha256', 
        password.encode('utf-8'), 
        salt.encode('utf-8'), 
        100000
    )
    return f"{salt}:{key.hex()}"

def verify_password(password: str, hashed: str) -> bool:
    try:
        salt, key_hex = hashed.split(":")
        expected_key = hashlib.pbkdf2_hmac(
            'sha256', 
            password.encode('utf-8'), 
            salt.encode('utf-8'), 
            100000
        )
        return expected_key.hex() == key_hex
    except Exception:
        return False

def generate_token(user_id: str) -> str:
    payload = {
        "user_id": user_id,
        "exp": time.time() + 86400 * 30  # 30 days
    }
    payload_b64 = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip("=")
    signature = hmac.new(
        SECRET_KEY.encode(),
        payload_b64.encode(),
        hashlib.sha256
    ).hexdigest()
    return f"{payload_b64}.{signature}"

def verify_token(token: str) -> Optional[str]:
    try:
        payload_b64, signature = token.split(".")
        expected_signature = hmac.new(
            SECRET_KEY.encode(),
            payload_b64.encode(),
            hashlib.sha256
        ).hexdigest()
        if not hmac.compare_digest(expected_signature, signature):
            return None
        
        padding = 4 - (len(payload_b64) % 4)
        if padding < 4:
            payload_b64 += "=" * padding
        payload = json.loads(base64.urlsafe_b64decode(payload_b64.encode()).decode())
        
        if time.time() > payload["exp"]:
            return None
        return payload["user_id"]
    except Exception:
        return None

def get_current_user_id(credentials: HTTPAuthorizationCredentials = Security(security)) -> str:
    token = credentials.credentials
    user_id = verify_token(token)
    if not user_id:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user_id

# Pydantic Schemas
class RegisterUserRequest(BaseModel):
    name: str
    kyc_verified: Optional[bool] = False
    trust_score: Optional[float] = 0.0
    rating: Optional[float] = 0.0

class AuthRegisterRequest(BaseModel):
    username: str
    email: str
    phone_number: str
    password: str

class AuthLoginRequest(BaseModel):
    username_or_email: str
    password: str

class ForgotPasswordRequest(BaseModel):
    email: str
    phone_number: str
    new_password: str

class UpdateProfileRequest(BaseModel):
    username: str
    email: str
    phone_number: str

class UpdateKycRequest(BaseModel):
    kyc_verified: bool

class UpgradeCommuterRequest(BaseModel):
    route_city: str
    current_lat: float
    current_lng: float

class DepositRequest(BaseModel):
    amount: float

class AcceptParcelRequest(BaseModel):
    travelerId: str
    parcelId: str

class RequestDeliveryRequest(BaseModel):
    travelerId: str

class UpdateLocationRequest(BaseModel):
    latitude: float
    longitude: float

class RateDeliveryRequest(BaseModel):
    rating_stars: int
    feedback_text: Optional[str] = None

class CreateParcelRequest(BaseModel):
    sender_id: str
    category_type: str
    liability_value: Optional[float] = 0.0
    receiver_name: str
    receiver_phone: str
    pickup_city: str
    dropoff_city: str
    description: str
    pickup_lat: float
    pickup_lng: float
    dropoff_lat: float
    dropoff_lng: float
    tip_amount: float

# Helper function to dynamically sync trust score and rating based on user-specified formulas:
# 1. Average Star Rating = Total Stars / Total Deliveries (starts at 0.0 for new users)
# 2. Trust Score Percentage = (Total Stars / (Total Deliveries * 5)) * 100 (starts at 0.0 for new users)
def sync_user_trust_score(cursor, user_id: str):
    cursor.execute(
        """SELECT COUNT(*), COALESCE(SUM(rating_stars), 0)
           FROM parcels
           WHERE traveler_id = %s AND status = 'Delivered' AND rating_stars IS NOT NULL""",
        (user_id,)
    )
    row = cursor.fetchone()
    total_deliveries = row[0] if row else 0
    total_stars = float(row[1]) if row else 0.0
    
    if total_deliveries == 0:
        avg_rating = 0.0
        trust_percentage = 0.0
    else:
        # Formula 1: Average Star Rating = Total Stars / Total Deliveries
        avg_rating = round(total_stars / total_deliveries, 1)
        # Formula 2: Trust Score Percentage = (Total Stars / (Total Deliveries * 5)) * 100
        trust_percentage = round((total_stars / (total_deliveries * 5.0)) * 100.0, 1)
    
    cursor.execute(
        "UPDATE users SET rating = %s, trust_score = %s WHERE id = %s",
        (avg_rating, trust_percentage, user_id)
    )
    return avg_rating, trust_percentage

def seed_db(cursor):
    cursor.execute("SELECT COUNT(*) FROM users;")
    count = cursor.fetchone()[0]
    if count == 0:
        h_pass = hash_password("password123")
        # Senders
        cursor.execute(
            """INSERT INTO users (id, name, username, email, phone_number, password_hash, trust_score, rating, kyc_verified_status, is_commuter)
               VALUES ('00000000-0000-0000-0000-000000000001', 'Alice (Sender)', 'alice', 'alice@picko.com', '+16175550100', %s, 0.00, 0.00, TRUE, FALSE)""",
            (h_pass,)
        )
        cursor.execute(
            """INSERT INTO wallets (user_id, available_balance, locked_escrow_balance)
               VALUES ('00000000-0000-0000-0000-000000000001', 25000.00, 0.00)"""
        )
        
        # Travelers
        cursor.execute(
            """INSERT INTO users (id, name, username, email, phone_number, password_hash, trust_score, rating, kyc_verified_status, is_commuter, route_city, current_lat, current_lng)
               VALUES ('00000000-0000-0000-0000-000000000002', 'Bob (Commuter)', 'bob', 'bob@picko.com', '+16175550199', %s, 84.00, 4.20, TRUE, TRUE, 'Kandy', 6.9271, 79.8612)""",
            (h_pass,)
        )
        cursor.execute(
            """INSERT INTO wallets (user_id, available_balance, locked_escrow_balance)
               VALUES ('00000000-0000-0000-0000-000000000002', 12000.00, 0.00)"""
        )
        
        cursor.execute(
            """INSERT INTO users (id, name, username, email, phone_number, password_hash, trust_score, rating, kyc_verified_status, is_commuter, route_city, current_lat, current_lng)
               VALUES ('00000000-0000-0000-0000-000000000003', 'Charlie (Commuter)', 'charlie', 'charlie@picko.com', '+16175550188', %s, 96.00, 4.80, TRUE, TRUE, 'Galle', 6.9271, 79.8612)""",
            (h_pass,)
        )
        cursor.execute(
            """INSERT INTO wallets (user_id, available_balance, locked_escrow_balance)
               VALUES ('00000000-0000-0000-0000-000000000003', 15000.00, 0.00)"""
        )
        
        cursor.execute(
            """INSERT INTO users (id, name, username, email, phone_number, password_hash, trust_score, rating, kyc_verified_status, is_commuter, route_city, current_lat, current_lng)
               VALUES ('00000000-0000-0000-0000-000000000004', 'Dave (Commuter)', 'dave', 'dave@picko.com', '+16175550177', %s, 72.00, 3.60, TRUE, TRUE, 'Kandy', 6.9271, 79.8612)""",
            (h_pass,)
        )
        cursor.execute(
            """INSERT INTO wallets (user_id, available_balance, locked_escrow_balance)
               VALUES ('00000000-0000-0000-0000-000000000004', 5000.00, 0.00)"""
        )
        
        # Seed two default parcels:
        cursor.execute(
            """UPDATE wallets SET available_balance = available_balance - 1500.00, locked_escrow_balance = 1500.00
               WHERE user_id = '00000000-0000-0000-0000-000000000002'"""
        )
        
        if POSTGIS_AVAILABLE:
            cursor.execute(
                """INSERT INTO parcels (id, sender_id, traveler_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code, pickup_geom, dropoff_geom)
                   VALUES ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'A', 1500.00, 'In Transit', 'Colombo', 'Kandy', 'Vintage Leather Jacket', 350.00, 6.9271, 79.8612, 7.2906, 80.6337, 'qr_handshake_parcel_001', ST_GeographyFromText('SRID=4326;POINT(79.8612 6.9271)'), ST_GeographyFromText('SRID=4326;POINT(80.6337 7.2906)'))"""
            )
            cursor.execute(
                """INSERT INTO parcel_scans (parcel_id, action, scanned_by, scan_lat, scan_lng, scan_location)
                   VALUES ('00000000-0000-0000-0000-000000000010', 'pickup', '00000000-0000-0000-0000-000000000002', 6.9271, 79.8612, ST_GeographyFromText('SRID=4326;POINT(79.8612 6.9271)'))"""
            )
            cursor.execute(
                """INSERT INTO parcels (id, sender_id, traveler_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code, pickup_geom, dropoff_geom)
                   VALUES ('00000000-0000-0000-0000-000000000020', '00000000-0000-0000-0000-000000000001', NULL, 'C', 0.00, 'Pending', 'Colombo', 'Kandy', 'Signed Legal Contracts', 600.00, 6.9271, 79.8612, 7.2906, 80.6337, 'qr_handshake_parcel_002', ST_GeographyFromText('SRID=4326;POINT(79.8612 6.9271)'), ST_GeographyFromText('SRID=4326;POINT(80.6337 7.2906)'))"""
            )
        else:
            cursor.execute(
                """INSERT INTO parcels (id, sender_id, traveler_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code)
                   VALUES ('00000000-0000-0000-0000-000000000010', '00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'A', 1500.00, 'In Transit', 'Colombo', 'Kandy', 'Vintage Leather Jacket', 350.00, 6.9271, 79.8612, 7.2906, 80.6337, 'qr_handshake_parcel_001')"""
            )
            cursor.execute(
                """INSERT INTO parcel_scans (parcel_id, action, scanned_by, scan_lat, scan_lng)
                   VALUES ('00000000-0000-0000-0000-000000000010', 'pickup', '00000000-0000-0000-0000-000000000002', 6.9271, 79.8612)"""
            )
            cursor.execute(
                """INSERT INTO parcels (id, sender_id, traveler_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng, verification_qr_code)
                   VALUES ('00000000-0000-0000-0000-000000000020', '00000000-0000-0000-0000-000000000001', NULL, 'C', 0.00, 'Pending', 'Colombo', 'Kandy', 'Signed Legal Contracts', 600.00, 6.9271, 79.8612, 7.2906, 80.6337, 'qr_handshake_parcel_002')"""
            )
        print("Database seeded with default values successfully.")

@app.on_event("startup")
def startup_event():
    init_db("schema.sql")
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            seed_db(cursor)
            conn.commit()
    except Exception as e:
        conn.rollback()
        print(f"Error seeding database: {e}")
    finally:
        release_db_connection(conn)


# --- AUTHENTICATION ENDPOINTS ---

@app.post("/api/auth/register")
def auth_register(req: AuthRegisterRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Check if email exists
            cursor.execute("SELECT id FROM users WHERE email = %s", (req.email,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Email is already registered.")
            
            # Check if username exists
            cursor.execute("SELECT id FROM users WHERE username = %s", (req.username,))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Username is already taken.")
                
            cursor.execute("BEGIN;")
            # Hash password
            pw_hash = hash_password(req.password)
            # Create user (set name = username to preserve backward compatibility, 0.0 defaults for new users)
            cursor.execute(
                """INSERT INTO users (name, username, email, phone_number, password_hash, kyc_verified_status, trust_score, rating)
                   VALUES (%s, %s, %s, %s, %s, FALSE, 0.00, 0.00)
                   RETURNING id, name, username, email, phone_number, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, created_at, avatar_url""",
                (req.username, req.username, req.email, req.phone_number, pw_hash)
            )
            user_row = cursor.fetchone()
            user_id = user_row[0]
            
            # Create wallet with initial mock balance
            cursor.execute(
                """INSERT INTO wallets (user_id, available_balance, locked_escrow_balance)
                   VALUES (%s, 5000.00, 0.00)
                   RETURNING available_balance, locked_escrow_balance""",
                (user_id,)
            )
            wallet_row = cursor.fetchone()
            
            cursor.execute("COMMIT;")
            
            # Generate token
            token = generate_token(str(user_id))
            
            return {
                "message": "User registered successfully.",
                "token": token,
                "user": {
                    "id": str(user_row[0]),
                    "name": user_row[1],
                    "username": user_row[2],
                    "email": user_row[3],
                    "phone_number": user_row[4],
                    "is_commuter": user_row[5],
                    "route_city": user_row[6],
                    "current_lat": float(user_row[7]) if user_row[7] else 0.0,
                    "current_lng": float(user_row[8]) if user_row[8] else 0.0,
                    "kyc_verified_status": user_row[9],
                    "trust_score": float(user_row[10]),
                    "rating": float(user_row[11]),
                    "created_at": user_row[12].isoformat(),
                    "avatarUrl": user_row[13]
                },
                "wallet": {
                    "user_id": str(user_id),
                    "available_balance": float(wallet_row[0]),
                    "locked_escrow_balance": float(wallet_row[1])
                }
            }
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.post("/api/auth/login")
def auth_login(req: AuthLoginRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Login identifier can be email or username
            cursor.execute(
                """SELECT id, name, username, email, phone_number, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, password_hash, avatar_url 
                   FROM users WHERE email = %s OR username = %s""",
                (req.username_or_email, req.username_or_email)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=401, detail="Invalid username/email or password.")
                
            user_id, name, username, email, phone_number, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, pw_hash, avatar_url = row
            
            # Check password
            if not pw_hash or not verify_password(req.password, pw_hash):
                raise HTTPException(status_code=401, detail="Invalid username/email or password.")
            
            # Fetch wallet
            cursor.execute(
                "SELECT available_balance, locked_escrow_balance FROM wallets WHERE user_id = %s", (user_id,)
            )
            w_row = cursor.fetchone()
            if not w_row:
                # Auto-create if missing (failsafe)
                cursor.execute(
                    "INSERT INTO wallets (user_id, available_balance, locked_escrow_balance) VALUES (%s, 5000.00, 0.00) RETURNING available_balance, locked_escrow_balance",
                    (user_id,)
                )
                w_row = cursor.fetchone()
                conn.commit()
                
            token = generate_token(str(user_id))
            return {
                "message": "Login successful.",
                "token": token,
                "user": {
                    "id": str(user_id),
                    "name": name,
                    "username": username,
                    "email": email,
                    "phone_number": phone_number,
                    "is_commuter": is_commuter,
                    "route_city": route_city,
                    "current_lat": float(current_lat) if current_lat else 0.0,
                    "current_lng": float(current_lng) if current_lng else 0.0,
                    "kyc_verified_status": kyc_verified_status,
                    "trust_score": float(trust_score),
                    "rating": float(rating),
                    "avatarUrl": avatar_url
                },
                "wallet": {
                    "user_id": str(user_id),
                    "available_balance": float(w_row[0]),
                    "locked_escrow_balance": float(w_row[1])
                }
            }
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.post("/api/auth/forgot-password")
def auth_forgot_password(req: ForgotPasswordRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Check if user matches email and phone number
            cursor.execute(
                "SELECT id FROM users WHERE email = %s AND phone_number = %s",
                (req.email, req.phone_number)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=400, detail="Invalid email or phone number combination.")
                
            user_id = row[0]
            new_hash = hash_password(req.new_password)
            
            cursor.execute(
                "UPDATE users SET password_hash = %s WHERE id = %s",
                (new_hash, user_id)
            )
            conn.commit()
            return {"message": "Password reset successfully."}
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.get("/api/auth/me")
def auth_me(user_id: str = Depends(get_current_user_id)):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """SELECT id, name, username, email, phone_number, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, avatar_url 
                   FROM users WHERE id = %s""", (user_id,)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="User not found.")
            return {
                "id": str(row[0]),
                "name": row[1],
                "username": row[2],
                "email": row[3],
                "phone_number": row[4],
                "is_commuter": row[5],
                "route_city": row[6],
                "current_lat": float(row[7]) if row[7] else 0.0,
                "current_lng": float(row[8]) if row[8] else 0.0,
                "kyc_verified_status": row[9],
                "trust_score": float(row[10]),
                "rating": float(row[11]),
                "avatarUrl": row[12]
            }
    finally:
        release_db_connection(conn)

@app.put("/api/auth/profile")
def auth_update_profile(req: UpdateProfileRequest, user_id: str = Depends(get_current_user_id)):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Check unique constraints if values are changing
            cursor.execute("SELECT id FROM users WHERE email = %s AND id <> %s", (req.email, user_id))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Email is already in use by another user.")
                
            cursor.execute("SELECT id FROM users WHERE username = %s AND id <> %s", (req.username, user_id))
            if cursor.fetchone():
                raise HTTPException(status_code=400, detail="Username is already in use by another user.")
                
            cursor.execute(
                """UPDATE users 
                   SET name = %s, username = %s, email = %s, phone_number = %s 
                   WHERE id = %s 
                   RETURNING id, name, username, email, phone_number, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, avatar_url""",
                (req.username, req.username, req.email, req.phone_number, user_id)
            )
            row = cursor.fetchone()
            conn.commit()
            return {
                "message": "Profile updated successfully.",
                "user": {
                    "id": str(row[0]),
                    "name": row[1],
                    "username": row[2],
                    "email": row[3],
                    "phone_number": row[4],
                    "is_commuter": row[5],
                    "route_city": row[6],
                    "current_lat": float(row[7]) if row[7] else 0.0,
                    "current_lng": float(row[8]) if row[8] else 0.0,
                    "kyc_verified_status": row[9],
                    "trust_score": float(row[10]),
                    "rating": float(row[11]),
                    "avatarUrl": row[12]
                }
            }
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.delete("/api/auth/profile")
def auth_delete_profile(user_id: str = Depends(get_current_user_id)):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("BEGIN;")
            # Delete scans scanned by the user
            cursor.execute("DELETE FROM parcel_scans WHERE scanned_by = %s", (user_id,))
            # Delete scans of parcels sent by the user
            cursor.execute("DELETE FROM parcel_scans WHERE parcel_id IN (SELECT id FROM parcels WHERE sender_id = %s)", (user_id,))
            # Set traveler_id to null for parcels accepted by the user
            cursor.execute("UPDATE parcels SET traveler_id = NULL, status = 'Pending' WHERE traveler_id = %s AND status = 'Accepted'", (user_id,))
            # Set traveler_id to null for other statuses
            cursor.execute("UPDATE parcels SET traveler_id = NULL WHERE traveler_id = %s", (user_id,))
            # Delete wallets
            cursor.execute("DELETE FROM wallets WHERE user_id = %s", (user_id,))
            # Delete parcels sent by the user
            cursor.execute("DELETE FROM parcels WHERE sender_id = %s", (user_id,))
            # Finally delete the user
            cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
            cursor.execute("COMMIT;")
            return {"message": "Profile deleted successfully."}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.post("/api/auth/profile/avatar")
def auth_upload_avatar(file: UploadFile = File(...), user_id: str = Depends(get_current_user_id)):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Save file to uploads/
            file_ext = file.filename.split(".")[-1] if "." in file.filename else "jpg"
            filename = f"avatar_{user_id}_{uuid.uuid4().hex[:8]}.{file_ext}"
            file_path = os.path.join("uploads", filename)
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)
            
            avatar_url = f"/uploads/{filename}"
            
            # Update database
            cursor.execute(
                "UPDATE users SET avatar_url = %s WHERE id = %s",
                (avatar_url, user_id)
            )
            conn.commit()
            return {"avatar_url": avatar_url}
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)


# --- USER ENDPOINTS ---

@app.post("/api/users/register")
def register_user(req: RegisterUserRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("BEGIN;")
            cursor.execute(
                """INSERT INTO users (name, kyc_verified_status, trust_score, rating)
                   VALUES (%s, %s, %s, %s)
                   RETURNING id, name, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, created_at, avatar_url""",
                (req.name, req.kyc_verified, req.trust_score, req.rating)
            )
            user_row = cursor.fetchone()
            user_id = user_row[0]
            
            # Create wallet with initial mock balance
            cursor.execute(
                """INSERT INTO wallets (user_id, available_balance, locked_escrow_balance)
                   VALUES (%s, 5000.00, 0.00)
                   RETURNING available_balance, locked_escrow_balance""",
                (user_id,)
            )
            wallet_row = cursor.fetchone()
            
            cursor.execute("COMMIT;")
            
            return {
                "message": "User registered successfully.",
                "user": {
                    "id": str(user_row[0]),
                    "name": user_row[1],
                    "is_commuter": user_row[2],
                    "route_city": user_row[3],
                    "current_lat": float(user_row[4]),
                    "current_lng": float(user_row[5]),
                    "kyc_verified_status": user_row[6],
                    "trust_score": float(user_row[7]),
                    "rating": float(user_row[8]),
                    "created_at": user_row[9].isoformat(),
                    "avatarUrl": user_row[10]
                },
                "wallet": {
                    "user_id": str(user_id),
                    "available_balance": float(wallet_row[0]),
                    "locked_escrow_balance": float(wallet_row[1])
                }
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.get("/api/users/{id}")
def get_user(id: str):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Sync trust score on profile retrieval
            sync_user_trust_score(cursor, id)
            conn.commit()
            
            cursor.execute(
                """SELECT id, name, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, created_at, avatar_url, start_city, nic_front_url, nic_back_url, terms_accepted, username, email, phone_number 
                   FROM users WHERE id = %s""", (id,)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="User not found")
            return {
                "id": str(row[0]),
                "name": row[1],
                "is_commuter": row[2],
                "route_city": row[3],
                "current_lat": float(row[4]) if row[4] else 0.0,
                "current_lng": float(row[5]) if row[5] else 0.0,
                "kyc_verified_status": row[6],
                "trust_score": float(row[7]),
                "rating": float(row[8]),
                "created_at": row[9].isoformat(),
                "avatarUrl": row[10],
                "start_city": row[11],
                "nic_front_url": row[12],
                "nic_back_url": row[13],
                "terms_accepted": row[14],
                "username": row[15],
                "email": row[16],
                "phone_number": row[17]
            }
    finally:
        release_db_connection(conn)

@app.post("/api/users/{id}/kyc")
def update_kyc(id: str, req: UpdateKycRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # KYC verified gives a boost to trust score
            trust_score = 95.00 if req.kyc_verified else 50.00
            cursor.execute(
                """UPDATE users 
                   SET kyc_verified_status = %s, trust_score = %s 
                   WHERE id = %s 
                   RETURNING id, name, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, avatar_url""",
                (req.kyc_verified, trust_score, id)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="User not found")
            conn.commit()
            return {
                "message": "KYC status updated.",
                "user": {
                    "id": str(row[0]),
                    "name": row[1],
                    "is_commuter": row[2],
                    "route_city": row[3],
                    "current_lat": float(row[4]) if row[4] else 0.0,
                    "current_lng": float(row[5]) if row[5] else 0.0,
                    "kyc_verified_status": row[6],
                    "trust_score": float(row[7]),
                    "rating": float(row[8]),
                    "avatarUrl": row[9]
                }
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.post("/api/users/{id}/commuter")
def upgrade_commuter(
    id: str,
    route_city: str = Form(...),
    start_city: str = Form(...),
    terms_accepted: bool = Form(...),
    current_lat: float = Form(42.3601),
    current_lng: float = Form(-71.0589),
    nic_front: Optional[UploadFile] = File(None),
    nic_back: Optional[UploadFile] = File(None)
):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Check if user exists
            cursor.execute("SELECT id FROM users WHERE id = %s", (id,))
            if not cursor.fetchone():
                raise HTTPException(status_code=404, detail="User not found")
                
            # Handle NIC Front file upload
            nic_front_url = None
            if nic_front:
                file_ext = nic_front.filename.split(".")[-1] if "." in nic_front.filename else "jpg"
                filename = f"nic_front_{id}_{uuid.uuid4().hex[:8]}.{file_ext}"
                file_path = os.path.join("uploads", filename)
                with open(file_path, "wb") as buffer:
                    shutil.copyfileobj(nic_front.file, buffer)
                nic_front_url = f"/uploads/{filename}"

            # Handle NIC Back file upload
            nic_back_url = None
            if nic_back:
                file_ext = nic_back.filename.split(".")[-1] if "." in nic_back.filename else "jpg"
                filename = f"nic_back_{id}_{uuid.uuid4().hex[:8]}.{file_ext}"
                file_path = os.path.join("uploads", filename)
                with open(file_path, "wb") as buffer:
                    shutil.copyfileobj(nic_back.file, buffer)
                nic_back_url = f"/uploads/{filename}"
                
            cursor.execute(
                """UPDATE users 
                   SET is_commuter = TRUE, route_city = %s, start_city = %s, current_lat = %s, current_lng = %s,
                       nic_front_url = COALESCE(%s, nic_front_url),
                       nic_back_url = COALESCE(%s, nic_back_url),
                       terms_accepted = %s
                   WHERE id = %s""",
                (route_city, start_city, current_lat, current_lng, nic_front_url, nic_back_url, terms_accepted, id)
            )
            
            # Sync trust score to calculate initial score incorporating new KYC status
            sync_user_trust_score(cursor, id)
            
            # Re-fetch with updated trust score
            cursor.execute(
                """SELECT id, name, is_commuter, route_city, start_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, avatar_url, nic_front_url, nic_back_url, terms_accepted
                   FROM users WHERE id = %s""", (id,)
            )
            row = cursor.fetchone()
            conn.commit()
            
            return {
                "message": "User upgraded to commuter traveler.",
                "user": {
                    "id": str(row[0]),
                    "name": row[1],
                    "is_commuter": row[2],
                    "route_city": row[3],
                    "start_city": row[4],
                    "current_lat": float(row[5]) if row[5] else 0.0,
                    "current_lng": float(row[6]) if row[6] else 0.0,
                    "kyc_verified_status": row[7],
                    "trust_score": float(row[8]),
                    "rating": float(row[9]),
                    "avatarUrl": row[10],
                    "nicFrontUrl": row[11],
                    "nicBackUrl": row[12],
                    "termsAccepted": row[13]
                }
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.get("/api/users")
def get_all_users():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """SELECT id, name, is_commuter, route_city, current_lat, current_lng, kyc_verified_status, trust_score, rating, avatar_url, username, email, phone_number, start_city 
                   FROM users ORDER BY created_at DESC"""
            )
            rows = cursor.fetchall()
            return [
                {
                    "id": str(row[0]),
                    "name": row[1],
                    "is_commuter": row[2],
                    "route_city": row[3],
                    "current_lat": float(row[4]) if row[4] else 0.0,
                    "current_lng": float(row[5]) if row[5] else 0.0,
                    "kyc_verified_status": row[6],
                    "trust_score": float(row[7]),
                    "rating": float(row[8]),
                    "avatarUrl": row[9],
                    "username": row[10],
                    "email": row[11],
                    "phone_number": row[12],
                    "start_city": row[13]
                }
                for row in rows
            ]
    finally:
        release_db_connection(conn)

@app.post("/api/users/{id}/location")
def update_user_location(id: str, req: UpdateLocationRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """UPDATE users 
                   SET current_lat = %s, current_lng = %s 
                   WHERE id = %s 
                   RETURNING id, name, current_lat, current_lng""",
                (req.latitude, req.longitude, id)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="User not found")
            conn.commit()
            return {
                "message": "Location updated successfully.",
                "user_id": str(row[0]),
                "name": row[1],
                "current_lat": float(row[2]),
                "current_lng": float(row[3])
            }
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

# --- WALLET ENDPOINTS ---

@app.get("/api/wallets/{userId}")
def get_wallet(userId: str):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                "SELECT user_id, available_balance, locked_escrow_balance FROM wallets WHERE user_id = %s", (userId,)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Wallet not found")
            return {
                "user_id": str(row[0]),
                "available_balance": float(row[1]),
                "locked_escrow_balance": float(row[2])
            }
    finally:
        release_db_connection(conn)

@app.post("/api/wallets/{userId}/deposit")
def deposit_funds(userId: str, req: DepositRequest):
    if req.amount <= 0:
        raise HTTPException(status_code=400, detail="Deposit amount must be positive.")
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """INSERT INTO wallets (user_id, available_balance, locked_escrow_balance)
                   VALUES (%s, %s, 0.00)
                   ON CONFLICT (user_id) 
                   DO UPDATE SET available_balance = wallets.available_balance + EXCLUDED.available_balance
                   RETURNING user_id, available_balance, locked_escrow_balance""",
                (userId, req.amount)
            )
            row = cursor.fetchone()
            conn.commit()
            return {
                "message": "Deposit successful.",
                "wallet": {
                    "user_id": str(row[0]),
                    "available_balance": float(row[1]),
                    "locked_escrow_balance": float(row[2])
                }
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.post("/api/wallets/accept")
def accept_parcel(req: AcceptParcelRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("BEGIN;")
            
            # Fetch parcel
            cursor.execute(
                "SELECT id, liability_value, status, category_type FROM parcels WHERE id = %s FOR UPDATE",
                (req.parcelId,)
            )
            parcel = cursor.fetchone()
            if not parcel:
                raise HTTPException(status_code=404, detail="Parcel not found")
            
            p_id, p_liability, p_status, p_category = parcel
            if p_status != 'Pending':
                raise HTTPException(status_code=400, detail=f"Parcel cannot be accepted. Status is {p_status}")
            
            # Fetch traveler details
            cursor.execute("SELECT trust_score FROM users WHERE id = %s", (req.travelerId,))
            traveler = cursor.fetchone()
            if not traveler:
                raise HTTPException(status_code=404, detail="Traveler not found")
            t_trust = float(traveler[0])
            
            # Check gates
            if p_category == 'B' and t_trust < 80.0:
                raise HTTPException(status_code=403, detail="Category B requires trust score >= 80")
            if p_category == 'C' and t_trust < 95.0:
                raise HTTPException(status_code=403, detail="Category C requires trust score >= 95")
            
            # Lock collateral
            cursor.execute(
                "SELECT available_balance, locked_escrow_balance FROM wallets WHERE user_id = %s FOR UPDATE",
                (req.travelerId,)
            )
            wallet = cursor.fetchone()
            if not wallet:
                raise HTTPException(status_code=404, detail="Traveler wallet not found")
            
            w_avail = float(wallet[0])
            liability = float(p_liability)
            
            if w_avail < liability:
                raise HTTPException(status_code=400, detail="Insufficient funds to lock escrow")
            
            # Deduct and lock
            cursor.execute(
                """UPDATE wallets 
                   SET available_balance = available_balance - %s,
                       locked_escrow_balance = locked_escrow_balance + %s
                   WHERE user_id = %s""",
                (liability, liability, req.travelerId)
            )
            
            # Update parcel status to Accepted
            cursor.execute(
                "UPDATE parcels SET status = 'Accepted', traveler_id = %s, requested_traveler_id = NULL WHERE id = %s RETURNING *",
                (req.travelerId, req.parcelId)
            )
            updated_parcel = cursor.fetchone()
            
            cursor.execute("COMMIT;")
            return {
                "message": "Parcel accepted. Escrow locked.",
                "parcel": {
                    "id": str(updated_parcel[0]),
                    "status": updated_parcel[5],
                    "traveler_id": str(updated_parcel[2])
                }
            }
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.post("/api/wallets/stolen")
def report_stolen(req: dict):
    parcel_id = req.get("parcelId")
    if not parcel_id:
        raise HTTPException(status_code=400, detail="parcelId is required.")
        
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("BEGIN;")
            
            # Fetch parcel
            cursor.execute(
                "SELECT id, sender_id, traveler_id, liability_value, status FROM parcels WHERE id = %s FOR UPDATE",
                (parcel_id,)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Parcel not found")
            
            p_id, p_sender, p_traveler, p_liability, p_status = row
            if p_status not in ['In Transit', 'Accepted']:
                raise HTTPException(status_code=400, detail=f"Cannot report stolen from status: {p_status}")
            
            liability = float(p_liability)
            
            # Deduct from traveler escrow
            cursor.execute(
                "UPDATE wallets SET locked_escrow_balance = locked_escrow_balance - %s WHERE user_id = %s",
                (liability, p_traveler)
            )
            # Transfer to sender available
            cursor.execute(
                "UPDATE wallets SET available_balance = available_balance + %s WHERE user_id = %s",
                (liability, p_sender)
            )
            # Update status
            cursor.execute(
                "UPDATE parcels SET status = 'Stolen' WHERE id = %s RETURNING *",
                (parcel_id,)
            )
            updated_parcel = cursor.fetchone()
            
            # Sync traveler reliability score immediately
            sync_user_trust_score(cursor, p_traveler)
            
            cursor.execute("COMMIT;")
            return {
                "message": "Parcel marked stolen. Escrow penalized and transferred to sender.",
                "parcel": {
                    "id": str(updated_parcel[0]),
                    "status": updated_parcel[4]
                }
            }
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

# --- PARCEL ENDPOINTS ---

@app.post("/api/parcels/create")
def create_parcel(req: CreateParcelRequest):
    if req.liability_value > 10000.00:
        raise HTTPException(status_code=400, detail="Maximum package liability value cannot exceed Rs. 10,000")
        
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # Generate unique verification QR code
            qr_code = f"qr_handshake_{uuid.uuid4().hex[:16]}"
            
            if POSTGIS_AVAILABLE:
                cursor.execute(
                    """INSERT INTO parcels (
                        sender_id, category_type, liability_value, status,
                        pickup_city, dropoff_city, description, tip_amount,
                        pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
                        pickup_geom, dropoff_geom, verification_qr_code,
                        receiver_name, receiver_phone
                       ) VALUES (
                        %s, %s, %s, 'Pending',
                        %s, %s, %s, %s,
                        %s, %s, %s, %s,
                        ST_GeographyFromText(%s), ST_GeographyFromText(%s), %s,
                        %s, %s
                       ) RETURNING id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, verification_qr_code, created_at, receiver_name, receiver_phone""",
                    (
                        req.sender_id, req.category_type, req.liability_value,
                        req.pickup_city, req.dropoff_city, req.description, req.tip_amount,
                        req.pickup_lat, req.pickup_lng, req.dropoff_lat, req.dropoff_lng,
                        f"SRID=4326;POINT({req.pickup_lng} {req.pickup_lat})",
                        f"SRID=4326;POINT({req.dropoff_lng} {req.dropoff_lat})",
                        qr_code, req.receiver_name, req.receiver_phone
                    )
                )
            else:
                cursor.execute(
                    """INSERT INTO parcels (
                        sender_id, category_type, liability_value, status,
                        pickup_city, dropoff_city, description, tip_amount,
                        pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
                        verification_qr_code, receiver_name, receiver_phone
                       ) VALUES (
                        %s, %s, %s, 'Pending',
                        %s, %s, %s, %s,
                        %s, %s, %s, %s,
                        %s, %s, %s
                       ) RETURNING id, sender_id, category_type, liability_value, status, pickup_city, dropoff_city, description, tip_amount, verification_qr_code, created_at, receiver_name, receiver_phone""",
                    (
                        req.sender_id, req.category_type, req.liability_value,
                        req.pickup_city, req.dropoff_city, req.description, req.tip_amount,
                        req.pickup_lat, req.pickup_lng, req.dropoff_lat, req.dropoff_lng,
                        qr_code, req.receiver_name, req.receiver_phone
                    )
                )
                
            row = cursor.fetchone()
            conn.commit()
            
            return {
                "id": str(row[0]),
                "senderId": str(row[1]),
                "category": row[2],
                "liabilityValue": float(row[3]),
                "status": row[4],
                "pickupCity": row[5],
                "dropoffCity": row[6],
                "description": row[7],
                "tipAmount": float(row[8]),
                "qrCodeData": row[9],
                "createdAt": row[10].isoformat(),
                "receiverName": row[11],
                "receiverPhone": row[12]
            }
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.get("/api/parcels/{id}")
def get_parcel(id: str):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """SELECT id, sender_id, traveler_id, category_type, liability_value, status,
                          pickup_city, dropoff_city, description, tip_amount,
                          pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
                          verification_qr_code, sealed_package_photo_url, created_at,
                          rating_stars, feedback_text, receiver_name, receiver_phone
                   FROM parcels WHERE id = %s""", (id,)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Parcel not found")
            return {
                "id": str(row[0]),
                "senderId": str(row[1]),
                "travelerId": str(row[2]) if row[2] else None,
                "category": row[3],
                "liabilityValue": float(row[4]),
                "status": row[5],
                "pickupCity": row[6],
                "dropoffCity": row[7],
                "description": row[8],
                "tipAmount": float(row[9]),
                "pickupLat": float(row[10]),
                "pickupLng": float(row[11]),
                "dropoffLat": float(row[12]),
                "dropoffLng": float(row[13]),
                "qrCodeData": row[14],
                "photoUrl": row[15],
                "createdAt": row[16].isoformat(),
                "ratingStars": row[17],
                "feedbackText": row[18],
                "receiverName": row[19],
                "receiverPhone": row[20]
            }
    finally:
        release_db_connection(conn)
 
@app.get("/api/parcels")
def get_all_parcels():
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """SELECT id, sender_id, traveler_id, category_type, liability_value, status,
                          pickup_city, dropoff_city, description, tip_amount,
                          pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
                          verification_qr_code, sealed_package_photo_url, created_at,
                          rating_stars, feedback_text, receiver_name, receiver_phone,
                          requested_traveler_id
                   FROM parcels ORDER BY created_at DESC"""
            )
            rows = cursor.fetchall()
            return [
                {
                    "id": str(row[0]),
                    "senderId": str(row[1]),
                    "travelerId": str(row[2]) if row[2] else None,
                    "category": row[3],
                    "liabilityValue": float(row[4]),
                    "status": row[5],
                    "pickupCity": row[6],
                    "dropoffCity": row[7],
                    "description": row[8],
                    "tipAmount": float(row[9]),
                    "pickupLat": float(row[10]),
                    "pickupLng": float(row[11]),
                    "dropoffLat": float(row[12]),
                    "dropoffLng": float(row[13]),
                    "qrCodeData": row[14],
                    "photoUrl": row[15],
                    "createdAt": row[16].isoformat(),
                    "ratingStars": row[17],
                    "feedbackText": row[18],
                    "receiverName": row[19],
                    "receiverPhone": row[20],
                    "requestedTravelerId": str(row[21]) if row[21] else None
                }
                for row in rows
            ]
    finally:
        release_db_connection(conn)

# --- CHECKPOINT HANDOVER QR SCAN & AUDIT HISTORY ---

@app.post("/api/parcels/{id}/scan")
def scan_checkpoint(
    id: str,
    action: str = Form(...),
    qr_code: str = Form(...),
    lat: float = Form(...),
    lng: float = Form(...),
    photo: Optional[UploadFile] = File(None)
):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("BEGIN;")
            
            # Fetch parcel
            cursor.execute(
                "SELECT id, sender_id, traveler_id, liability_value, status, verification_qr_code, tip_amount FROM parcels WHERE id = %s FOR UPDATE",
                (id,)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Parcel not found")
            
            p_id, p_sender, p_traveler, p_liability, p_status, p_qr, p_tip = row
            
            # Verify QR code
            if p_qr != qr_code:
                raise HTTPException(status_code=401, detail="Invalid QR code. Verification failed.")
                
            # Perform action
            if action == 'pickup':
                if p_status not in ['Pending', 'Accepted']:
                    raise HTTPException(status_code=400, detail=f"Cannot scan pickup for package in state: {p_status}")
                    
                if not photo:
                    raise HTTPException(status_code=400, detail="Photo of the sealed package is required for pickup verification.")
                
                # Save photo
                file_ext = photo.filename.split(".")[-1] if "." in photo.filename else "jpg"
                filename = f"sealed_{id}_{uuid.uuid4().hex[:8]}.{file_ext}"
                file_path = os.path.join("uploads", filename)
                with open(file_path, "wb") as buffer:
                    shutil.copyfileobj(photo.file, buffer)
                
                photo_url = f"/uploads/{filename}"
                
                # Update status
                cursor.execute(
                    "UPDATE parcels SET status = 'In Transit', sealed_package_photo_url = %s WHERE id = %s RETURNING *",
                    (photo_url, id)
                )
                updated_parcel = cursor.fetchone()
                
                # Log scan to auditable tracking history
                if POSTGIS_AVAILABLE:
                    cursor.execute(
                        """INSERT INTO parcel_scans (parcel_id, action, scanned_by, scan_lat, scan_lng, scan_location)
                           VALUES (%s, 'pickup', %s, %s, %s, ST_GeographyFromText(%s))""",
                        (id, p_traveler or p_sender, lat, lng, f"SRID=4326;POINT({lng} {lat})")
                    )
                else:
                    cursor.execute(
                        """INSERT INTO parcel_scans (parcel_id, action, scanned_by, scan_lat, scan_lng)
                           VALUES (%s, 'pickup', %s, %s, %s)""",
                        (id, p_traveler or p_sender, lat, lng)
                    )
                
                cursor.execute("COMMIT;")
                return {
                    "message": "Pickup scan successful. Package is now In Transit.",
                    "parcel": {
                        "id": str(updated_parcel[0]),
                        "status": updated_parcel[4],
                        "photoUrl": photo_url
                    }
                }
                
            elif action == 'dropoff':
                if p_status != 'In Transit':
                    raise HTTPException(status_code=400, detail=f"Cannot scan delivery for package in state: {p_status}")
                
                # Settlement transfer
                liability = float(p_liability)
                tip = float(p_tip)
                
                # Deduct tip from Sender available balance
                cursor.execute(
                    "SELECT available_balance FROM wallets WHERE user_id = %s FOR UPDATE", (p_sender,)
                )
                sender_wallet = cursor.fetchone()
                if not sender_wallet or float(sender_wallet[0]) < tip:
                    raise HTTPException(status_code=400, detail="Sender has insufficient funds to pay tip")
                
                cursor.execute(
                    "UPDATE wallets SET available_balance = available_balance - %s WHERE user_id = %s",
                    (tip, p_sender)
                )
                
                # Unlock liability and credit tip to traveler available balance
                cursor.execute(
                    """UPDATE wallets 
                       SET locked_escrow_balance = locked_escrow_balance - %s,
                           available_balance = available_balance + %s + %s
                       WHERE user_id = %s""",
                    (liability, liability, tip, p_traveler)
                )
                
                # Update status to Delivered
                cursor.execute(
                    "UPDATE parcels SET status = 'Delivered' WHERE id = %s RETURNING *",
                    (id,)
                )
                updated_parcel = cursor.fetchone()
                
                # Log scan to auditable tracking history
                if POSTGIS_AVAILABLE:
                    cursor.execute(
                        """INSERT INTO parcel_scans (parcel_id, action, scanned_by, scan_lat, scan_lng, scan_location)
                           VALUES (%s, 'dropoff', %s, %s, %s, ST_GeographyFromText(%s))""",
                        (id, p_traveler, lat, lng, f"SRID=4326;POINT({lng} {lat})")
                    )
                else:
                    cursor.execute(
                        """INSERT INTO parcel_scans (parcel_id, action, scanned_by, scan_lat, scan_lng)
                           VALUES (%s, 'dropoff', %s, %s, %s)""",
                        (id, p_traveler, lat, lng)
                    )
                
                # Update traveler reliability metrics immediately
                sync_user_trust_score(cursor, p_traveler)
                
                cursor.execute("COMMIT;")
                return {
                    "message": "Delivery completed. Escrow released and tip transferred.",
                    "parcel": {
                        "id": str(updated_parcel[0]),
                        "status": updated_parcel[4]
                    }
                }
            else:
                raise HTTPException(status_code=400, detail=f"Invalid action: {action}")
                
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
@app.post("/api/parcels/{id}/rate")
def rate_delivery(id: str, req: RateDeliveryRequest):
    if req.rating_stars < 1 or req.rating_stars > 5:
        raise HTTPException(status_code=400, detail="Rating must be between 1 and 5 stars.")
    
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("BEGIN;")
            
            # Fetch parcel
            cursor.execute(
                "SELECT id, traveler_id, status FROM parcels WHERE id = %s FOR UPDATE",
                (id,)
            )
            row = cursor.fetchone()
            if not row:
                raise HTTPException(status_code=404, detail="Parcel not found")
            
            p_id, traveler_id, status = row
            
            if status != 'Delivered':
                raise HTTPException(status_code=400, detail="Only delivered parcels can be rated.")
            
            if not traveler_id:
                raise HTTPException(status_code=400, detail="No traveler is assigned to this parcel.")
            
            # Update parcel with rating and feedback
            cursor.execute(
                "UPDATE parcels SET rating_stars = %s, feedback_text = %s WHERE id = %s",
                (req.rating_stars, req.feedback_text, id)
            )
            
            # Sync traveler average rating and trust score
            avg_rating, trust_score = sync_user_trust_score(cursor, traveler_id)
            
            cursor.execute("COMMIT;")
            return {
                "message": "Delivery rated successfully.",
                "traveler_id": traveler_id,
                "new_rating": avg_rating,
                "new_trust_score": trust_score
            }
            
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

# Helper math function for fallback Haversine distance
def python_haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6371.0 # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = math.sin(dlat / 2)**2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

@app.get("/api/parcels/{id}/tracking")
def get_parcel_tracking(id: str):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # 1. Fetch parcel details
            cursor.execute(
                """SELECT id, sender_id, traveler_id, category_type, liability_value, status,
                          pickup_city, dropoff_city, pickup_lat, pickup_lng, dropoff_lat, dropoff_lng,
                          description, tip_amount, verification_qr_code, sealed_package_photo_url, created_at,
                          receiver_name, receiver_phone
                   FROM parcels WHERE id = %s""",
                (id,)
            )
            p_row = cursor.fetchone()
            if not p_row:
                raise HTTPException(status_code=404, detail="Parcel not found")
            
            # 2. Fetch traveler details if assigned
            traveler_data = None
            traveler_lat = None
            traveler_lng = None
            traveler_id = p_row[2]
            if traveler_id:
                cursor.execute(
                    """SELECT id, name, username, phone_number, email, current_lat, current_lng, trust_score, rating, avatar_url, route_city
                       FROM users WHERE id = %s""",
                    (traveler_id,)
                )
                t_row = cursor.fetchone()
                if t_row:
                    traveler_lat = float(t_row[5]) if t_row[5] is not None else None
                    traveler_lng = float(t_row[6]) if t_row[6] is not None else None
                    traveler_data = {
                        "id": str(t_row[0]),
                        "name": t_row[1],
                        "username": t_row[2],
                        "phoneNumber": t_row[3],
                        "email": t_row[4],
                        "currentLat": traveler_lat,
                        "currentLng": traveler_lng,
                        "trustScore": float(t_row[7]) if t_row[7] is not None else 0.0,
                        "rating": float(t_row[8]) if t_row[8] is not None else 0.0,
                        "avatarUrl": t_row[9],
                        "routeCity": t_row[10]
                    }

            # 3. Fetch scans history
            cursor.execute(
                """SELECT id, action, scanned_by, scan_lat, scan_lng, scanned_at
                   FROM parcel_scans WHERE parcel_id = %s ORDER BY scanned_at ASC""",
                (id,)
            )
            scan_rows = cursor.fetchall()
            scans_list = [
                {
                    "id": str(row[0]),
                    "action": row[1],
                    "scanned_by": str(row[2]),
                    "latitude": float(row[3]),
                    "longitude": float(row[4]),
                    "timestamp": row[5].isoformat()
                }
                for row in scan_rows
            ]

            # 4. Compute navigation metrics
            pickup_lat = float(p_row[8])
            pickup_lng = float(p_row[9])
            dropoff_lat = float(p_row[10])
            dropoff_lng = float(p_row[11])
            total_km = round(python_haversine(pickup_lat, pickup_lng, dropoff_lat, dropoff_lng), 1)

            ref_lat = traveler_lat if traveler_lat is not None else pickup_lat
            ref_lng = traveler_lng if traveler_lng is not None else pickup_lng
            remaining_km = round(python_haversine(ref_lat, ref_lng, dropoff_lat, dropoff_lng), 1)
            
            if p_row[5] == 'Delivered':
                eta_minutes = 0
                remaining_km = 0.0
            elif remaining_km > 0.2:
                eta_minutes = max(1, int(round((remaining_km / 45.0) * 60.0)))
            else:
                eta_minutes = 1

            return {
                "parcel": {
                    "id": str(p_row[0]),
                    "senderId": str(p_row[1]),
                    "travelerId": str(p_row[2]) if p_row[2] else None,
                    "category": p_row[3],
                    "liabilityValue": float(p_row[4]),
                    "status": p_row[5],
                    "pickupCity": p_row[6],
                    "dropoffCity": p_row[7],
                    "pickupLat": pickup_lat,
                    "pickupLng": pickup_lng,
                    "dropoffLat": dropoff_lat,
                    "dropoffLng": dropoff_lng,
                    "description": p_row[12],
                    "tipAmount": float(p_row[13]),
                    "qrCodeData": p_row[14],
                    "photoUrl": p_row[15],
                    "createdAt": p_row[16].isoformat() if p_row[16] else None,
                    "receiverName": p_row[17],
                    "receiverPhone": p_row[18]
                },
                "traveler": traveler_data,
                "scans": scans_list,
                "navigation": {
                    "totalDistanceKm": total_km,
                    "remainingDistanceKm": remaining_km,
                    "etaMinutes": eta_minutes,
                    "commuterLat": traveler_lat,
                    "commuterLng": traveler_lng,
                    "isLive": (p_row[5] == 'In Transit') and (traveler_lat is not None)
                }
            }
    finally:
        release_db_connection(conn)

@app.get("/api/parcels/{id}/matches")
def match_travelers(id: str):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            # 1. Fetch parcel details
            cursor.execute(
                """SELECT id, sender_id, category_type, liability_value, dropoff_city, pickup_lat, pickup_lng, requested_traveler_id
                   FROM parcels WHERE id = %s""", (id,)
            )
            parcel = cursor.fetchone()
            if not parcel:
                raise HTTPException(status_code=404, detail="Parcel not found")
                
            p_id, p_sender, p_category, p_liability, p_dropoff_city, p_lat, p_lng, p_requested_traveler = parcel
            p_lat = float(p_lat)
            p_lng = float(p_lng)
            p_liability_val = float(p_liability)
            
            # Trust Gating requirements based on Category
            min_trust_score = 0.0
            if p_category == 'B':
                min_trust_score = 80.0
            elif p_category == 'C':
                min_trust_score = 95.0
            
            # Fetch active commuters who have sufficient wallet balance to cover the parcel liability value
            cursor.execute(
                """SELECT u.id, u.name, u.is_commuter, u.route_city, u.current_lat, u.current_lng, u.kyc_verified_status, u.trust_score, u.rating, COALESCE(w.available_balance, 0.0), u.avatar_url
                   FROM users u
                   LEFT JOIN wallets w ON u.id = w.user_id
                   WHERE u.is_commuter = TRUE AND u.id != %s AND COALESCE(w.available_balance, 0.0) >= %s""",
                (p_sender, p_liability_val)
            )
            users_rows = cursor.fetchall()
            
            match_results = []
            for u in users_rows:
                u_id, u_name, u_is_commuter, u_route_city, u_lat, u_lng, u_kyc, u_trust, u_rating, u_balance, u_avatar = u
                u_trust = float(u_trust)
                u_rating = float(u_rating)
                u_lat = float(u_lat) if u_lat else 0.0
                u_lng = float(u_lng) if u_lng else 0.0
                u_avail = float(u_balance)
                
                # Step 1: Spatial Filter (ST_DWithin 5km radius check)
                if POSTGIS_AVAILABLE:
                    cursor.execute(
                        """SELECT ST_Distance(
                            ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography,
                            ST_SetSRID(ST_MakePoint(%s, %s), 4326)::geography
                        )""", (u_lng, u_lat, p_lng, p_lat)
                    )
                    dist_meters = cursor.fetchone()[0]
                    dist_km = dist_meters / 1000.0
                else:
                    # Fallback haversine
                    dist_km = python_haversine(p_lat, p_lng, u_lat, u_lng)
                
                passes_spatial = dist_km <= 5.0
                
                # Step 2: Route Filter
                passes_route = False
                if u_route_city and p_dropoff_city:
                    passes_route = u_route_city.strip().lower() == p_dropoff_city.strip().lower()
                
                # Step 3: Trust Score Sort & Gating
                passes_trust_gate = u_trust >= min_trust_score
                
                # KYC validation check for categories A, B, C
                passes_kyc_gate = True
                if p_category in ['A', 'B', 'C'] and not u_kyc:
                    passes_kyc_gate = False
                
                # Calculate dynamic combined score
                cursor.execute("SELECT COUNT(*) FROM parcels WHERE traveler_id = %s", (u_id,))
                total = cursor.fetchone()[0]
                cursor.execute("SELECT COUNT(*) FROM parcels WHERE traveler_id = %s AND status = 'Delivered'", (u_id,))
                success = cursor.fetchone()[0]
                success_rate = (success / total * 100.0) if total > 0 else 100.0
                
                base_weight = u_trust * 0.4
                success_weight = success_rate * 0.3
                rating_weight = (u_rating / 5.0) * 20.0
                kyc_bonus = 10.0 if u_kyc else 0.0
                dynamic_score = base_weight + success_weight + rating_weight + kyc_bonus
                
                is_eligible = passes_spatial and passes_route and passes_trust_gate and passes_kyc_gate
                
                match_results.append({
                    "traveler": {
                        "id": str(u_id),
                        "name": u_name,
                        "is_commuter": u_is_commuter,
                        "route_city": u_route_city,
                        "current_lat": u_lat,
                        "current_lng": u_lng,
                        "kyc_verified_status": u_kyc,
                        "trust_score": u_trust,
                        "rating": u_rating,
                        "avatarUrl": u_avatar,
                        "availableBalance": u_avail
                    },
                    "distance": round(dist_km, 2),
                    "passesSpatial": passes_spatial,
                    "passesRoute": passes_route,
                    "passesTrustGate": passes_trust_gate and passes_kyc_gate,
                    "dynamicScore": round(dynamic_score, 2),
                    "isEligible": is_eligible,
                    "isRequested": (str(p_requested_traveler) == str(u_id)) if p_requested_traveler else False
                })
            
            # Sort: eligible first, then dynamicScore descending
            match_results.sort(key=lambda x: (1 if x["isEligible"] else 0, x["dynamicScore"]), reverse=True)
            return match_results
            
    finally:
        release_db_connection(conn)

@app.post("/api/parcels/{id}/request")
def request_traveler(id: str, req: RequestDeliveryRequest):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("SELECT id, status, sender_id FROM parcels WHERE id = %s", (id,))
            parcel = cursor.fetchone()
            if not parcel:
                raise HTTPException(status_code=404, detail="Parcel not found")
            if parcel[1] != 'Pending':
                raise HTTPException(status_code=400, detail=f"Cannot request traveler. Parcel status is {parcel[1]}")
            
            cursor.execute("SELECT id, name FROM users WHERE id = %s AND is_commuter = TRUE", (req.travelerId,))
            traveler = cursor.fetchone()
            if not traveler:
                raise HTTPException(status_code=404, detail="Commuter traveler not found")
            
            cursor.execute(
                "UPDATE parcels SET requested_traveler_id = %s WHERE id = %s",
                (req.travelerId, id)
            )
            conn.commit()
            return {
                "message": f"Delivery request sent to {traveler[1]}.",
                "parcelId": id,
                "requestedTravelerId": req.travelerId
            }
    except HTTPException as he:
        conn.rollback()
        raise he
    except Exception as e:
        conn.rollback()
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        release_db_connection(conn)

@app.delete("/api/parcels/{id}/request")
def cancel_request_traveler(id: str):
    conn = get_db_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute("UPDATE parcels SET requested_traveler_id = NULL WHERE id = %s", (id,))
            conn.commit()
            return {"message": "Delivery request cancelled.", "parcelId": id}
    finally:
        release_db_connection(conn)

# Stateless Matching endpoint for compatibility with original matching-service
class StatelessTraveler(BaseModel):
    id: str
    name: str
    current_lat: float
    current_lng: float
    transit_route_cities: List[str]
    kyc_verified_status: bool
    trust_score: float
    success_rate: float
    rating: float

class StatelessParcel(BaseModel):
    pickup_lat: float
    pickup_lng: float
    destination_city: str
    category_type: str
    liability_value: float

class StatelessMatchPayload(BaseModel):
    parcel: StatelessParcel
    travelers: List[StatelessTraveler]

@app.post("/match")
def match_stateless_traveler(payload: StatelessMatchPayload):
    from matcher import find_best_traveler, Traveler, ParcelRequest
    try:
        # Convert schemas to match matcher.py structures
        parcel_req = ParcelRequest(
            pickup_lat=payload.parcel.pickup_lat,
            pickup_lng=payload.parcel.pickup_lng,
            destination_city=payload.parcel.destination_city,
            category_type=payload.parcel.category_type,
            liability_value=payload.parcel.liability_value
        )
        travelers_req = [
            Traveler(
                id=t.id,
                name=t.name,
                current_lat=t.current_lat,
                current_lng=t.current_lng,
                transit_route_cities=t.transit_route_cities,
                kyc_verified_status=t.kyc_verified_status,
                trust_score=t.trust_score,
                success_rate=t.success_rate,
                rating=t.rating
            )
            for t in payload.travelers
        ]
        
        best_match = find_best_traveler(parcel_req, travelers_req)
        if not best_match:
            raise HTTPException(
                status_code=404, 
                detail="No suitable commuters found matching location, route, and trust-score criteria."
            )
        return {
            "match": best_match,
            "message": "Matching successful."
        }
    except HTTPException as he:
        raise he
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stateless matching failure: {str(e)}")

# Health Check
@app.get("/health")
def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
