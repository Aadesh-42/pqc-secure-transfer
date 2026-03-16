from fastapi import APIRouter, HTTPException
from database.connection import supabase

router = APIRouter(prefix="/audit", tags=["Audit Logs"])

@router.get("/logs")
async def get_audit_logs():
    """Retrieve all audit logs. (Admin only in prod)"""
    result = supabase.table("audit_logs").select("*").order("timestamp", desc=True).execute()
    return result.data
