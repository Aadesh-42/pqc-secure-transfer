from fastapi import APIRouter, HTTPException, Depends
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from typing import Optional, List
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

@router.get("")
async def get_tasks(
    current_user: dict = Depends(
        get_current_user)
):
    user_id = current_user["user_id"]
    role = current_user["role"]
    print(f"Getting tasks for {user_id} role:{role}")
    
    if role == "admin":
        result = supabase.table("tasks")\
            .select("*")\
            .execute()
    else:
        result = supabase.table("tasks")\
            .select("*")\
            .eq("assigned_to", user_id)\
            .execute()
    
    print(f"Tasks found: {len(result.data)}")
    return result.data

@router.post("/create")
async def create_task(
    task: TaskCreate,
    current_user: dict = Depends(
        get_current_user)
):
    print(f"Creating task: {task}")
    data = {
        "title": task.title,
        "description": task.description,
        "assigned_to": task.assigned_to,
        "priority": task.priority,
        "status": "pending",
        "due_date": task.due_date
    }
    result = supabase.table("tasks")\
        .insert(data)\
        .execute()
    print(f"Task created: {result.data}")
    return result.data[0]

@router.patch("/{task_id}/status")
async def update_task_status(
    task_id: str,
    status_update: dict,
    current_user: dict = Depends(
        get_current_user)
):
    result = supabase.table("tasks")\
        .update({"status": 
            status_update.get("status")})\
        .eq("id", task_id)\
        .execute()
    return result.data[0]
