from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from typing import Optional, List
import os

from models.message import MessageCreate, MessageResponse
from database.connection import supabase

router = APIRouter(prefix="/messages", tags=["Messages"])

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

@router.get("/{user_id}", response_model=List[MessageResponse])
async def get_messages(user_id: str, current_user: dict = Depends(get_current_user)):
    """Get messages involving a specific user."""
    # This queries messages where the user is either sender or receiver
    result = supabase.table("messages").select("*").or_(f"sender_id.eq.{user_id},receiver_id.eq.{user_id}").execute()
    return result.data

@router.post("/send", response_model=MessageResponse)
async def send_message(msg: MessageCreate, current_user: dict = Depends(get_current_user)):
    """Send a new message."""
    record = msg.model_dump()
    # Use current user ID as sender_id
    record["sender_id"] = current_user["user_id"]
        
    result = supabase.table("messages").insert(record).execute()
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to send message")
    return result.data[0]
