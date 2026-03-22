from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime
import os

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

class MessageCreate(BaseModel):
    receiver_id: str
    content: str
    is_encrypted: bool = False

@router.post("/send")
async def send_message(
    msg: MessageCreate,
    current_user: dict = Depends(get_current_user)
):
    print(f"Sending message from {current_user['user_id']} to {msg.receiver_id}")
    try:
        data = {
            "sender_id": current_user["user_id"],
            "receiver_id": msg.receiver_id,
            "content": msg.content,
            "is_encrypted": msg.is_encrypted
        }
        result = supabase.table("messages").insert(data).execute()
        print(f"Message sent: {result.data}")
        if not result.data:
            raise Exception("No data returned from supabase insert")
        return result.data[0]
    except Exception as e:
        print(f"Error sending message: {e}")
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )

@router.get("/debug/all")
async def get_all_messages():
    """Debug endpoint: returns ALL messages in the database without filtering."""
    result = supabase.table("messages").select("*").order("created_at").execute()
    print(f"ALL MESSAGES: {result.data}")
    return result.data

@router.get("/{other_user_id}")
async def get_messages(
    other_user_id: str,
    current_user: dict = Depends(get_current_user)
):
    my_id = current_user["user_id"]
    print(f"MY ID: {my_id}")
    print(f"OTHER ID: {other_user_id}")
    
    try:
        result = supabase.table("messages").select("*").execute()
        
        all_msgs = result.data
        print(f"Total messages in DB: {len(all_msgs)}")
        
        filtered = [
            m for m in all_msgs
            if (m["sender_id"] == my_id and m["receiver_id"] == other_user_id)
            or (m["sender_id"] == other_user_id and m["receiver_id"] == my_id)
        ]
        
        print(f"Filtered (conversation-specific): {len(filtered)}")
        # Sort by created_at ascending
        filtered.sort(key=lambda x: x["created_at"])
        return filtered
    except Exception as e:
        print(f"Error fetching messages: {e}")
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )
