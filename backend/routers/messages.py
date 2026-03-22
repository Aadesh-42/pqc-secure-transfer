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

@router.get("/{user_id}")
async def get_messages(
    user_id: str,
    current_user: dict = Depends(get_current_user)
):
    my_id = current_user["user_id"]
    try:
        result = supabase.table("messages")\
            .select("*")\
            .or_(f"sender_id.eq.{my_id},receiver_id.eq.{my_id}")\
            .order("created_at")\
            .execute()
        return result.data
    except Exception as e:
        print(f"Error fetching messages: {e}")
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )
