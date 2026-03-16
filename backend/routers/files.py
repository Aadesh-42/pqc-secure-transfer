from fastapi import APIRouter, HTTPException, Depends
from models.file import FileSendCreate, FileResponse
from database.connection import supabase

router = APIRouter(prefix="/files", tags=["Secure Files"])

@router.post("/send", response_model=FileResponse)
async def send_file(file_data: FileSendCreate):
    """Send an encrypted file metadata record."""
    # Assuming sender_id is extracted from a JWT auth dependency in a real scenario
    # For now, it might be passed or we set a dummy. Let's make sender_id required for Pydantic later, or extract it here.
    # The requirement didn't specify JWT extraction middleware precisely, but we'll accept dummy sender for basic endpoint.
    record = file_data.model_dump()
    # We will use a mock sender_id for this scaffold if not provided.
    if "sender_id" not in record:
        record["sender_id"] = "00000000-0000-0000-0000-000000000000" # Placeholder, in prod use JWT 'sub'
        
    result = supabase.table("secure_files").insert(record).execute()
    
    if not result.data:
        raise HTTPException(status_code=500, detail="Failed to record file transfer")
    return result.data[0]

@router.post("/{file_id}/confirm")
async def confirm_file_receipt(file_id: str):
    """Confirm receipt of a file."""
    result = supabase.table("secure_files").update({"status": "received"}).eq("id", file_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="File not found")
    return {"message": "Receipt confirmed", "file": result.data[0]}

@router.get("/{file_id}/decrypt")
async def get_file_for_decryption(file_id: str):
    """Get file metadata for decryption."""
    result = supabase.table("secure_files").select("*").eq("id", file_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="File not found")
    return result.data[0]
