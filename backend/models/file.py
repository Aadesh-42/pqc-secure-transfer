from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID

class FileSendBase(BaseModel):
    receiver_id: UUID
    encrypted_payload: str
    kyber_ciphertext: str
    dilithium_signature: str

class FileSendCreate(FileSendBase):
    pass

class FileResponse(FileSendBase):
    id: UUID
    sender_id: UUID
    status: str
    created_at: datetime

    class Config:
        from_attributes = True
