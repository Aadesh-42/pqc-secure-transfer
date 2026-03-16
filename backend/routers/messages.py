from fastapi import APIRouter, HTTPException
from typing import List
from models.message import MessageCreate, MessageResponse
from database.connection import supabase

router = APIRouter(prefix="/messages", tags=["Messages"])

@router.get("/{user_id}", response_model=List[MessageResponse])
async def get_messages(user_id: str):
    """Get messages involving a specific user."""
    # This queries messages where the user is either sender or receiver
    result = supabase.table("messages").select("*").or_(f"sender_id.eq.{user_id},receiver_id.eq.{user_id}").execute()
    return result.data

@router.post("/send", response_model=MessageResponse)
async def send_message(msg: MessageCreate):
    """Send a new message."""
    record = msg.model_dump()
    if "sender_id" not in record:
        record["sender_id"] = "00000000-0000-0000-0000-000000000000" # Placeholder for JWT sub
        
    result = supabase.table("messages").insert(record).execute()
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to send message")
    return result.data[0]
