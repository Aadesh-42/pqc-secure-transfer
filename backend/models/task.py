from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from uuid import UUID

class TaskBase(BaseModel):
    title: str
    description: Optional[str] = None
    assigned_to: Optional[str] = None
    priority: str = "medium"
    due_date: Optional[str] = None

class TaskCreate(TaskBase):
    pass

class TaskUpdate(BaseModel):
    status: Optional[str] = None
    priority: Optional[str] = None
    due_date: Optional[datetime] = None

class TaskResponse(TaskBase):
    id: UUID
    status: str
    created_at: datetime
    
    class Config:
        from_attributes = True
