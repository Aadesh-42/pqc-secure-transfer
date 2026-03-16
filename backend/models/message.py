from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID

class MessageBase(BaseModel):
    receiver_id: UUID
    content: str
    is_encrypted: bool = False

class MessageCreate(MessageBase):
    pass

class MessageResponse(MessageBase):
    id: UUID
    sender_id: UUID
    created_at: datetime

    class Config:
        from_attributes = True
