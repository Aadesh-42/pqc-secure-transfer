from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime
from uuid import UUID

# Shared properties
class UserBase(BaseModel):
    email: EmailStr
    role: str = "employee"

# Properties to receive via API on creation
class UserCreate(UserBase):
    password: str

# Properties to receive via API on login
class UserLogin(BaseModel):
    email: EmailStr
    password: str

# MFA Verification
class MfaVerify(BaseModel):
    user_id: UUID
    code: str

# Properties to return to client
class UserResponse(UserBase):
    id: UUID
    kyber_public_key: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True
