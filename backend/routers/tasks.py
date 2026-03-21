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

@router.post("/create", response_model=TaskResponse)
async def create_task(task: TaskCreate):
    """Create a new task."""
    try:
        task_data = task.model_dump(exclude_unset=True)
        print(f"DEBUG: STARTING task creation with data: {task_data}")
        
        # Ensure UUID conversion if possible
        if task_data.get("assigned_to"):
            from uuid import UUID
            try:
                task_data["assigned_to"] = str(UUID(task_data["assigned_to"]))
            except ValueError:
                print(f"DEBUG: assigned_to is not a valid UUID string: {task_data['assigned_to']}")

        result = supabase.table("tasks").insert(task_data).execute()
        
        if not result.data:
            print(f"DEBUG: Supabase returned NO DATA for insert result")
            raise HTTPException(status_code=500, detail="Failed to create task in DB")
            
        print(f"DEBUG: Task created successfully! ID: {result.data[0]['id']}")
        return result.data[0]
    except Exception as e:
        print(f"DEBUG: ERROR in create_task: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

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
