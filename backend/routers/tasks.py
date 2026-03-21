from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from typing import Optional
import os
from database.connection import supabase
from models.task import TaskCreate

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
    """Create a new task (Admin only)."""
    if current_user["role"] != "admin":
        raise HTTPException(status_code=403, detail="Only admins can create tasks")
        
    print(f"Creating task: {task}")
    data = {
        "title": task.title,
        "description": task.description,
        "assigned_to": task.assigned_to,
        "priority": task.priority,
        "status": "pending",
        "due_date": task.due_date
    }
    result = supabase.table("tasks").insert(data).execute()
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to create task")
    return result.data[0]

@router.get("")
async def get_tasks(current_user: dict = Depends(get_current_user)):
    """Get tasks based on role."""
    if current_user["role"] == "admin":
        result = supabase.table("tasks").select("*").execute()
    else:
        result = supabase.table("tasks").select("*").eq("assigned_to", current_user["user_id"]).execute()
    return result.data

@router.patch("/{task_id}/status")
async def update_task_status(task_id: int, status_update: dict, current_user: dict = Depends(get_current_user)):
    """Update task status."""
    new_status = status_update.get("status")
    if not new_status:
        raise HTTPException(status_code=400, detail="Status is required")

    result = supabase.table("tasks").update({"status": new_status}).eq("id", task_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Task not found")
    return result.data[0]
