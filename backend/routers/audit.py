from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from typing import Optional
import os
from database.connection import supabase

router = APIRouter(prefix="/audit", tags=["Audit Logs"])

oauth2_scheme = OAuth2PasswordBearer(
    tokenUrl="/auth/login"
)

SECRET_KEY = os.getenv(
    "JWT_SECRET",
    "Aadesh2026PQCSecureApp$Key#32XvBh"
)

ALGORITHM = "HS256"

def get_current_user(
    token: str = Depends(oauth2_scheme)
):
    try:
        payload = jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM]
        )
        user_id = payload.get("sub")
        role = payload.get("role")
        email = payload.get("email")
        if user_id is None:
            raise HTTPException(
                status_code=401,
                detail="Invalid token"
            )
        return {
            "user_id": user_id,
            "role": role,
            "email": email
        }
    except JWTError:
        raise HTTPException(
            status_code=401,
            detail="Invalid token"
        )

@router.get("/logs")
async def get_audit_logs(current_user: dict = Depends(get_current_user)):
    """Retrieve all audit logs. (Admin only)"""
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Unauthorized")
        
    result = supabase.table("audit_logs").select("*").order("timestamp", desc=True).execute()
    return result.data
