from fastapi import APIRouter, HTTPException, Depends, Request
from fastapi.security import OAuth2PasswordBearer
from jose import jwt, JWTError
from typing import Optional, List
import os
import base64

from database.connection import supabase
from services.pqc_service import (
    encrypt_file,
    decrypt_file,
    sign_file,
    verify_signature,
    generate_kyber_keypair
)

router = APIRouter(prefix="/files", tags=["Secure Files"])

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

def safe_b64decode(data: str) -> bytes:
    if data is None:
        raise ValueError(
            "Data cannot be None"
        )
    data = data.strip()
    padding = 4 - len(data) % 4
    if padding != 4:
        data += '=' * padding
    return base64.b64decode(data)

# --- Models ---
class FileEncryptRequest(BaseModel):
    file_bytes_b64: str
    public_key: str

class FileSignRequest(BaseModel):
    encrypted_payload_b64: str
    private_key: str

class FileSendRequest(BaseModel):
    sender_id: str
    receiver_id: str
    encrypted_payload: str
    kyber_ciphertext: str
    dilithium_signature: str

class FileDecryptRequest(BaseModel):
    receiver_private_key_b64: str # Kyber-768 private key for decryption
    admin_public_key_b64: str # Dilithium3 public key for signature verification

# --- Helper function for Audit Logging ---
def log_audit(user_id: str, action: str, metadata: dict, request: Request):
    """Log an operation in the audit_logs table."""
    ip_address = request.client.host if request.client else None
    supabase.table("audit_logs").insert({
        "user_id": user_id,
        "action": action,
        "metadata": metadata,
        "ip_address": ip_address
    }).execute()

# --- Endpoints ---

@router.post("/encrypt")
async def encrypt_file_endpoint(req: FileEncryptRequest, current_user: dict = Depends(get_current_user)):
    """Encrypt payload separately for step-by-step flow."""
    try:
        file_bytes = base64.b64decode(req.file_bytes_b64)
        print(f"DEBUG: Endpoint encrypting {len(file_bytes)} bytes")
        payload, ciphertext = encrypt_file(file_bytes, req.public_key)
        return {"encrypted_payload": payload, "kyber_ciphertext": ciphertext}
    except Exception as e:
        print(f"DEBUG: Encryption endpoint ERROR: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/sign")
async def sign_file_endpoint(req: FileSignRequest, current_user: dict = Depends(get_current_user)):
    """Sign payload separately for step-by-step flow."""
    try:
        sig = sign_file(req.encrypted_payload_b64, req.private_key)
        return {"signature": sig}
    except Exception as e:
        print(f"DEBUG: Signing endpoint ERROR: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/send")
async def send_file(req: FileSendRequest, request: Request, current_user: dict = Depends(get_current_user)):
    """
    Final step: store metadata and ciphertexts in DB.
    """
    record = {
        "sender_id": req.sender_id,
        "receiver_id": req.receiver_id,
        "encrypted_payload": req.encrypted_payload,
        "kyber_ciphertext": req.kyber_ciphertext,
        "dilithium_signature": req.dilithium_signature,
        "status": "pending"
    }
    insert_res = supabase.table("secure_files").insert(record).execute()
    
    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to save secure file record to database")
    
    file_record = insert_res.data[0]
    log_audit(req.sender_id, "send_file", {"file_id": file_record["id"]}, request)
    return {"message": "File record saved successfully", "file": file_record}

@router.post("/{file_id}/confirm")
async def confirm_file_receipt(file_id: str, request: Request, current_user: dict = Depends(get_current_user)):
    """Employee confirms receipt of a file."""
    # Verify the current user is indeed the receiver
    res = supabase.table("secure_files").select("receiver_id").eq("id", file_id).execute()
    if not res.data or res.data[0]["receiver_id"] != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="You are not authorized to confirm this file")

    update_res = supabase.table("secure_files").update({"status": "confirmed"}).eq("id", file_id).execute()
    if not update_res.data:
        raise HTTPException(status_code=404, detail="File not found or update failed")
    
    log_audit(current_user["user_id"], "confirm_file_receipt", {"file_id": file_id}, request)
    return {"message": "Receipt confirmed", "file": update_res.data[0]}

@router.post("/{file_id}/decrypt")
async def get_file_for_decryption(file_id: str, req: FileDecryptRequest, request: Request, current_user: dict = Depends(get_current_user)):
    """Employee decrypts the file."""
    print(f"DEBUG: Decryption request for file {file_id}")
    res = supabase.table("secure_files").select("*").eq("id", file_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="File not found")
        
    file_record = res.data[0]
    if file_record["receiver_id"] != current_user["user_id"]:
        raise HTTPException(status_code=403, detail="Not authorized to decrypt this file")

    print(f"DEBUG: Received private key length: {len(req.receiver_private_key_b64)}")
    print(f"DEBUG: Encrypted payload length: {len(file_record['encrypted_payload'])}")
    print(f"DEBUG: Kyber ciphertext length: {len(file_record['kyber_ciphertext'])}")

    # Verify signature first
    is_valid = verify_signature(
        file_record["encrypted_payload"], 
        file_record["dilithium_signature"], 
        req.admin_public_key_b64
    )
    if not is_valid:
        print("DEBUG: Signature verification FAILED")
        raise HTTPException(status_code=403, detail="Signature verification failed")
    
    print("DEBUG: Signature verification PASSED")
    
    try:
        decrypted_bytes = decrypt_file(
            file_record["encrypted_payload"],
            file_record["kyber_ciphertext"],
            req.receiver_private_key_b64
        )
        print(f"DEBUG: Decryption SUCCESS. Decrypted {len(decrypted_bytes)} bytes")
    except Exception as e:
        print(f"DEBUG: PQC Decryption ERROR: {e}")
        raise HTTPException(status_code=500, detail=f"PQC Decryption failed: {str(e)}")

    log_audit(current_user["user_id"], "decrypt_file", {"file_id": file_id}, request)
    
    # Ensure result is clean base64
    b64_result = base64.b64encode(decrypted_bytes).decode('utf-8')
    return {
        "message": "File decrypted successfully", 
        "file_bytes_b64": b64_result
    }

@router.get("/received")
async def get_received_files(current_user: dict = Depends(get_current_user)):
    """Get all files received by the logged-in user."""
    result = supabase.table("secure_files").select("*").eq("receiver_id", current_user["user_id"]).execute()
    return result.data
