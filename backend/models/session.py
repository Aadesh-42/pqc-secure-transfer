from pydantic import BaseModel
from datetime import datetime
from uuid import UUID

class SessionBase(BaseModel):
    user_id: UUID
    token_hash: str
    ip_address: str | None = None
    device_info: str | None = None
    expires_at: datetime

class SessionResponse(SessionBase):
    id: UUID

    class Config:
        from_attributes = True
