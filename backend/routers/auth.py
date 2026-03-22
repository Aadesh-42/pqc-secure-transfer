from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone, timedelta
import os
import random

from models.user import UserCreate, UserLogin, UserResponse, MfaVerify
from services.auth_service import (
    get_password_hash, verify_password, create_access_token,
    generate_mfa_secret, verify_mfa_token
)
from database.connection import supabase
from services.email_service import send_otp_email
from routers.audit import log_action

router = APIRouter(prefix="/auth", tags=["Authentication"])
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/login")

SECRET_KEY = os.getenv("JWT_SECRET", "Aadesh2026PQCSecureApp$Key#32XvBh")
ALGORITHM = "HS256"

def get_current_user(token: str = Depends(oauth2_scheme)):
    """Helper to get current user from JWT."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=401, detail="Invalid token payload")
        return {
            "id": user_id,
            "role": payload.get("role"),
            "email": payload.get("email")
        }
    except JWTError:
        raise HTTPException(status_code=401, detail="Could not validate credentials")

@router.post("/register", response_model=UserResponse)
async def register_user(user: UserCreate):
    """Register a new user."""
    # Check if user exists
    existing = supabase.table("users").select("id").eq("email", user.email).execute()
    if existing.data:
        raise HTTPException(status_code=400, detail="Email already registered")

    # Hash password and generate MFA
    hashed_pwd = get_password_hash(user.password)
    mfa_secret = generate_mfa_secret()

    # Insert user
    new_user = {
        "email": user.email,
        "password_hash": hashed_pwd,
        "role": user.role,
        "mfa_secret": mfa_secret
    }
    
    # Try generating PQC keypairs if liboqs is available
    try:
        from services.pqc_service import generate_kyber_keypair, generate_dilithium_keypair
        kyber_pub, _ = generate_kyber_keypair()
        dilithium_pub, _ = generate_dilithium_keypair()
        new_user["kyber_public_key"] = kyber_pub
        new_user["dilithium_public_key"] = dilithium_pub
    except ImportError:
        pass # Will remain null if not available
        
    result = supabase.table("users").insert(new_user).execute()
    
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create user")
        
    return result.data[0]

@router.post("/login")
async def login_user(user: UserLogin):
    """Login and verify credentials. (Step 1 of MFA)"""
    email_clean = user.email.lower().strip()
    print(f"DEBUG: Attempting login for email: {email_clean}")
    
    result = supabase.table("users").select("*").ilike("email", email_clean).execute()
    
    if not result.data:
        print(f"DEBUG: User not found for email: {email_clean}")
        raise HTTPException(status_code=404, detail="User not found")
        
    db_user = result.data[0]
    print(f"DEBUG: Found user in DB: {db_user['email']} (ID: {db_user['id']})")
    
    if not verify_password(user.password, db_user["password_hash"]):
        print(f"DEBUG: Password verification failed for {email_clean}")
        raise HTTPException(status_code=401, detail="Incorrect password")
    
    print(f"DEBUG: Password verified! Proceeding to generate OTP for {email_clean}")
    
    # Generate 6-digit OTP
    otp_code = str(random.randint(100000, 999999))
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=5)).isoformat()
    
    # Store OTP in sessions table
    session_data = {
        "user_id": db_user["id"],
        "otp_code": otp_code,
        "expires_at": expires_at
    }
    supabase.table("sessions").insert(session_data).execute()
    
    # Send Email
    email_sent = send_otp_email(user.email, otp_code)
    if not email_sent:
        raise HTTPException(status_code=500, detail="Failed to send OTP email")
        
    return {"message": "OTP sent to your email", "user_id": db_user["id"]}

@router.post("/mfa/verify")
async def verify_mfa(mfa: MfaVerify):
    print(f"Verifying OTP for: {mfa.email}")
    print(f"OTP received: {mfa.otp_code}")
    
    user_res = supabase.table("users")\
        .select("*")\
        .eq("email", mfa.email.lower())\
        .execute()
    
    if not user_res.data:
        raise HTTPException(
            status_code=404,
            detail="User not found"
        )
    
    user = user_res.data[0]
    
    session = supabase.table("sessions")\
        .select("*")\
        .eq("user_id", user["id"])\
        .order("expires_at", desc=True)\
        .limit(1)\
        .execute()
    
    if not session.data:
        raise HTTPException(
            status_code=404,
            detail="OTP not found"
        )
    
    session = session.data[0]
    print(f"Stored OTP: {session['otp_code']}")
    print(f"Received OTP: {mfa.otp_code}")
    
    if str(session["otp_code"]) != str(mfa.otp_code):
        raise HTTPException(
            status_code=400,
            detail="Invalid OTP"
        )
    
    token = create_access_token(
        data={
            "sub": str(user["id"]),
            "role": user["role"],
            "email": user["email"]
        }
    )
    
    supabase.table("sessions").delete().eq("user_id", user["id"]).execute()
    
    # Log successful login
    await log_action(
        user_id=str(user["id"]),
        action="user_login",
        metadata={"email": user["email"]},
    )
    
    return {
        "access_token": token,
        "token_type": "bearer",
        "role": user["role"],
        "user_id": str(user["id"])
    }

@router.post("/update_kyber_keys")
async def update_kyber_keys(email: str):
    """Temporary endpoint to generate and save kyber keys for existing users"""
    try:
        from services.pqc_service import generate_kyber_keypair
        pub_key, priv_key = generate_kyber_keypair()
        
        # Update user in DB
        result = supabase.table("users").update({"kyber_public_key": pub_key}).eq("email", email).execute()
        
        if not result.data:
            raise HTTPException(status_code=404, detail="User not found")
            
        return {"message": "Keys generated successfully", "email": email, "private_key": priv_key}
    except ImportError:
        raise HTTPException(status_code=500, detail="PQC Not Available on this system")

@router.get("/regenerate_keys")
async def regenerate_keys(current_user: dict = Depends(get_current_user)):
    """Generate fresh PQC keys for the logged-in user."""
    try:
        from services.pqc_service import generate_kyber_keypair, generate_dilithium_keypair
        
        # New Kyber Pair
        kyber_pub, kyber_priv = generate_kyber_keypair()
        # New Dilithium Pair
        dilith_pub, dilith_priv = generate_dilithium_keypair()
        
        # Update user in DB
        supabase.table("users").update({
            "kyber_public_key": kyber_pub,
            "dilithium_public_key": dilith_pub
        }).eq("id", current_user["id"]).execute()
        
        return {
            "message": "Quantum keys regenerated",
            "kyber_private_key": kyber_priv,
            "dilithium_private_key": dilith_priv,
            "kyber_public_key": kyber_pub,
            "dilithium_public_key": dilith_pub
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Key regeneration failed: {str(e)}")

@router.get("/{user_id}/public_key")
async def get_user_public_key(user_id: str):
    """Get a user's Kyber public key."""
    result = supabase.table("users").select("kyber_public_key").eq("id", user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="User or public key not found")
    return {"public_key": result.data[0]["kyber_public_key"]}

@router.get("/employees")
async def get_employees(current_user: dict = Depends(get_current_user)):
    """Get all users with the 'employee' role."""
    result = supabase.table("users").select("id, email, role").eq("role", "employee").execute()
    print(f"Employees found: {result.data}")
    return result.data

@router.get("/admins")
async def get_admins(current_user: dict = Depends(get_current_user)):
    """Get all users with the 'admin' role."""
    result = supabase.table("users").select("id, email, role").eq("role", "admin").execute()
    print(f"Admins found: {result.data}")
    return result.data

# ─── Registration with OTP verification ───────────────────────────────────────

class RegisterRequest(BaseModel):
    first_name: str
    last_name: str
    email: str
    password: str
    role: str = "employee"

@router.post("/register-request")
async def register_request(data: RegisterRequest, request: Request):
    """Step 1: validate email uniqueness, send OTP, store pending registration."""
    print(f"Register request: {data.email}")

    existing = supabase.table("users").select("id").eq("email", data.email.lower()).execute()
    if existing.data:
        raise HTTPException(status_code=400, detail="Email already registered")

    otp = str(random.randint(100000, 999999))
    from services.email_service import send_otp_email
    email_sent = send_otp_email(data.email, otp)
    if not email_sent:
        raise HTTPException(status_code=500, detail="Failed to send OTP email")

    # Store pending registration in sessions table using ip_address as email key
    # and device_info to hold registration payload
    expires_at = (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()
    device_info = f"{data.first_name} {data.last_name}|{data.password}|{data.role}"

    supabase.table("sessions").insert({
        "user_id": "00000000-0000-0000-0000-000000000000",
        "otp_code": otp,
        "ip_address": data.email.lower(),
        "expires_at": expires_at,
        "device_info": device_info,
    }).execute()

    await log_action(
        user_id="00000000-0000-0000-0000-000000000000",
        action="register_request",
        metadata={"email": data.email}
    )

    return {"message": "OTP sent to your email", "email": data.email}


class VerifyRegistration(BaseModel):
    email: str
    otp_code: str

@router.post("/verify-registration")
async def verify_registration(data: VerifyRegistration):
    """Step 2: verify OTP and create the user account."""
    print(f"Verifying registration for {data.email}")

    session = supabase.table("sessions")\
        .select("*")\
        .eq("ip_address", data.email.lower())\
        .order("expires_at", desc=True)\
        .limit(1)\
        .execute()

    if not session.data:
        raise HTTPException(status_code=404, detail="OTP not found. Please request again.")

    s = session.data[0]

    if str(s["otp_code"]) != str(data.otp_code):
        raise HTTPException(status_code=400, detail="Invalid OTP")

    # Parse stored registration payload
    device_info = s.get("device_info", "||employee")
    parts = device_info.split("|")
    full_name = parts[0] if len(parts) > 0 else ""
    password   = parts[1] if len(parts) > 1 else ""
    role       = parts[2].strip() if len(parts) > 2 else "employee"

    from services.auth_service import get_password_hash
    password_hash = get_password_hash(password)

    result = supabase.table("users").insert({
        "email": data.email.lower(),
        "password_hash": password_hash,
        "role": role,
    }).execute()

    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create account")

    # Clean up the pending session
    supabase.table("sessions").delete().eq("ip_address", data.email.lower()).execute()

    new_user = result.data[0]

    await log_action(
        user_id=new_user["id"],
        action="account_created",
        metadata={"email": data.email}
    )

    return {"message": "Account created successfully!", "user_id": new_user["id"]}
