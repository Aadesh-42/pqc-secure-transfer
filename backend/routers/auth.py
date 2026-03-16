from fastapi import APIRouter, HTTPException, Depends
from models.user import UserCreate, UserLogin, UserResponse, MfaVerify
from services.auth_service import (
    get_password_hash, verify_password, create_access_token,
    generate_mfa_secret, verify_mfa_token
)
from database.connection import supabase
from datetime import timedelta

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
    
    # Try generating kyber keypair if liboqs is available
    try:
        from services.pqc_service import generate_kyber_keypair
        pub_key, _ = generate_kyber_keypair() # We only store public key
        new_user["kyber_public_key"] = pub_key
    except ImportError:
        pass # Will remain null if not available
        
    result = supabase.table("users").insert(new_user).execute()
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
        raise HTTPException(status_code=401, detail="Incorrect password")
        
    return {"message": "Credentials verified. Please complete MFA.", "user_id": db_user["id"]}

@router.post("/mfa/verify")
async def verify_mfa(mfa: MfaVerify):
    """Verify MFA code and return JWT token."""
    result = supabase.table("users").select("mfa_secret", "email", "role").eq("id", str(mfa.user_id)).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="User not found")
        
    db_user = result.data[0]
    
    if not verify_mfa_token(db_user["mfa_secret"], mfa.code):
        raise HTTPException(status_code=401, detail="Invalid MFA code")
        
    # Generate JWT
    access_token_expires = timedelta(minutes=60*24)
    access_token = create_access_token(
        data={"sub": db_user["email"], "id": str(mfa.user_id), "role": db_user["role"]},
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer", "user_id": mfa.user_id}

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
