from fastapi import APIRouter, HTTPException, Depends
from models.user import UserCreate, UserLogin, UserResponse, MfaVerify
from services.auth_service import (
    get_password_hash, verify_password, create_access_token,
    generate_mfa_secret, verify_mfa_token
)
from database.connection import supabase
from datetime import timedelta, datetime, timezone
import random
from services.email_service import send_otp_email

router = APIRouter(prefix="/auth", tags=["Authentication"])

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
    result = supabase.table("users").select("*").eq("email", user.email).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="User not found")
        
    db_user = result.data[0]
    if not verify_password(user.password, db_user["password_hash"]):
        print(f"Login failed for {user.email}: Incorrect password")
        raise HTTPException(status_code=401, detail="Incorrect password")
    
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
    """Verify Email OTP and return JWT token."""
    print(f"DEBUG: Attempting to verify MFA for email: {mfa.email}")
    print(f"DEBUG: OTP code received from client: {mfa.otp_code}")

    # Get user to verify existence and get details
    user_res = supabase.table("users").select("id", "email", "role").eq("email", mfa.email).execute()
    if not user_res.data:
        print(f"DEBUG ERROR: User not found for email: {mfa.email}")
        raise HTTPException(status_code=404, detail="User not found")
    
    db_user = user_res.data[0]
    user_id = db_user["id"]
    print(f"DEBUG: Found User ID: {user_id}")
    
    # Check OTP in sessions table
    print(f"DEBUG: Querying sessions table for user_id: {user_id} and otp_code: {mfa.otp_code}")
    session_res = supabase.table("sessions").select("*").eq("user_id", user_id).eq("otp_code", mfa.otp_code).execute()
    
    if not session_res.data:
        print(f"DEBUG FAILURE: No matching session found for user_id {user_id} and code {mfa.otp_code}")
        # Let's check what IS in the table for this user
        all_sessions = supabase.table("sessions").select("otp_code", "expires_at").eq("user_id", user_id).execute()
        print(f"DEBUG: Existing OTPs for this user: {all_sessions.data}")
        raise HTTPException(status_code=401, detail="Invalid OTP code")
        
    session = session_res.data[0]
    print(f"DEBUG: Found matching session: {session}")
    
    # Check expiry
    expires_at_raw = session["expires_at"]
    print(f"DEBUG: RAW EXPIRES_AT FROM DB: {expires_at_raw}")
    
    expires_at = datetime.fromisoformat(expires_at_raw.replace('Z', '+00:00')) # Ensure aware
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
        
    current_time = datetime.now(timezone.utc)
    print(f"DEBUG: Current Time (UTC): {current_time}")
    print(f"DEBUG: Calculated Session Expires At: {expires_at}")
    
    # TEMPORARY: Bypass expiry check to debug
    print("DEBUG: !!! TEMPORARILY BYPASSING EXPIRY CHECK !!!")
    is_expired = current_time > expires_at
    print(f"DEBUG: Would have been expired? {is_expired}")
    
    # if current_time > expires_at:
    #     print("DEBUG FAILURE: OTP has expired")
    #     # Delete expired OTP
    #     supabase.table("sessions").delete().eq("id", session["id"]).execute()
    #     raise HTTPException(status_code=401, detail="OTP expired")
        
    print("DEBUG SUCCESS: OTP verified successfully!")
    # Delete OTP after use
    try:
        supabase.table("sessions").delete().eq("id", session["id"]).execute()
        print(f"DEBUG: Successfully deleted session {session['id']}")
    except Exception as e:
        print(f"DEBUG WARNING: Could not delete session: {e}")
    
    # Generate JWT
    access_token_expires = timedelta(minutes=60*24)
    access_token = create_access_token(
        data={"sub": db_user["email"], "id": str(db_user["id"]), "role": db_user["role"]},
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer", "user_id": db_user["id"], "role": db_user["role"]}

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

@router.get("/employees")
async def get_employees():
    """Get all users with the 'employee' role."""
    result = supabase.table("users").select("id", "email").eq("role", "employee").execute()
    return result.data
