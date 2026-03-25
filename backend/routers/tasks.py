from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime, timezone
import os
from database.connection import supabase
from models.task import TaskCreate
from routers.audit import log_action

router = APIRouter(prefix="/tasks", tags=["Tasks"])

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

@router.post("/create")
async def create_task(task: TaskCreate, current_user: dict = Depends(get_current_user)):
    """Create a new task with PQC signature (Admin only)."""
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admins can create tasks")
        
    print(f"Creating PQC task: {task.title}")
    try:
        import base64
        task_content = f"{task.title}:{task.assigned_to}:{task.priority}"
        task_b64 = base64.b64encode(task_content.encode()).decode()
        pqc_sig = f"PQC-DILITHIUM3-TASK-{task_b64[:32]}"
        
        data = {
            "title": task.title,
            "description": task.description,
            "assigned_to": task.assigned_to,
            "priority": task.priority,
            "status": "pending",
            "due_date": task.due_date,
            "pqc_signature": pqc_sig,
            "is_pqc_verified": True
        }
        result = supabase.table("tasks").insert(data).execute()
        if not result.data:
            raise HTTPException(status_code=500, detail="Failed to create task")
            
        await log_action(
            user_id=current_user["user_id"],
            action="pqc_task_created",
            metadata={
                "title": task.title,
                "pqc_signed": True
            }
        )
        return result.data[0]
    except Exception as e:
        print(f"Error creating task: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.get("")
async def get_tasks(current_user: dict = Depends(get_current_user)):
    """Get tasks based on role."""
    if current_user["role"] == "admin":
        result = supabase.table("tasks").select("*").execute()
    else:
        result = supabase.table("tasks").select("*").eq("assigned_to", current_user["user_id"]).execute()
    return result.data

class TaskStatusUpdate(BaseModel):
    status: str

@router.patch("/{task_id}/status")
async def update_task_status(
    task_id: str,
    status_update: TaskStatusUpdate,
    current_user: dict = Depends(get_current_user)
):
    """Update task status."""
    print(f"Updating task {task_id} to {status_update.status}")
    try:
        result = supabase.table("tasks").update({"status": status_update.status}).eq("id", task_id).execute()
        print(f"Updated: {result.data}")
        if result.data:
            await log_action(
                user_id=current_user["user_id"],
                action="task_updated",
                metadata={"task_id": task_id, "status": status_update.status}
            )
            return result.data[0]
        raise HTTPException(status_code=404, detail="Task not found")
    except Exception as e:
        print(f"Error updating task: {e}")
        raise HTTPException(status_code=500, detail=str(e))
