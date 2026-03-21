from fastapi import APIRouter, HTTPException, Depends
from typing import List
from models.task import TaskCreate, TaskUpdate, TaskResponse
from database.connection import supabase

router = APIRouter(prefix="/tasks", tags=["Tasks"])

@router.get("", response_model=List[TaskResponse])
async def get_tasks():
    """Get all tasks."""
    result = supabase.table("tasks").select("*").execute()
    return result.data

from fastapi.security import OAuth2PasswordBearer
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

@router.post("/create")
async def create_task(
    task: TaskCreate,
    token: str = Depends(oauth2_scheme)
):
    print(f"DEBUG: Creating task from request model: {task}")
    try:
        data = {
            "title": task.title,
            "description": task.description,
            "assigned_to": task.assigned_to,
            "priority": task.priority,
            "status": "pending",
            "due_date": task.due_date
        }
        print(f"DEBUG: Inserting data into Supabase: {data}")
        result = supabase.table("tasks").insert(data).execute()
        
        if not result.data:
             print("DEBUG: Supabase returned NO DATA")
             raise HTTPException(status_code=500, detail="Failed to create task in DB")
             
        print(f"DEBUG: Task created SUCCESS. Result: {result.data[0]}")
        return result.data[0]
    except Exception as e:
        print(f"DEBUG: ERROR creating task: {e}")
        raise HTTPException(
            status_code=500,
            detail=str(e)
        )

@router.patch("/{task_id}/status", response_model=TaskResponse)
async def update_task_status(task_id: str, task_update: TaskUpdate):
    """Update task status."""
    result = supabase.table("tasks").update(task_update.model_dump(exclude_unset=True)).eq("id", task_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Task not found or failed to update")
    return result.data[0]

@router.get("/assigned", response_model=List[TaskResponse])
async def get_assigned_tasks(user_id: str):
    """Get tasks assigned to a specific user."""
    result = supabase.table("tasks").select("*").eq("assigned_to", user_id).execute()
    return result.data
