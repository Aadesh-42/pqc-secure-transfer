from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel
import base64
from typing import Optional
from database.connection import supabase
from services.pqc_service import encrypt_file, sign_file, verify_signature, decrypt_file

router = APIRouter(prefix="/files", tags=["Secure Files"])

# --- Models ---
class FileSendRequest(BaseModel):
    sender_id: str
    receiver_id: str
    file_bytes_b64: str
    admin_private_key_b64: str # Dilithium3 private key for signing

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

@router.post("/send")
async def send_file(req: FileSendRequest, request: Request):
    """
    Admin sends a file to an Employee.
    - encrypt_file() using receiver's Kyber public key.
    - sign_file() using Admin's Dilithium private key.
    - Stores metadata and ciphertexts in DB, no private keys.
    """
    # 1. Fetch receiver's public key from database
    receiver_res = supabase.table("users").select("kyber_public_key").eq("id", req.receiver_id).execute()
    if not receiver_res.data or not receiver_res.data[0].get("kyber_public_key"):
        raise HTTPException(status_code=404, detail="Receiver public key not found in data store")
    
    receiver_public_key_b64 = receiver_res.data[0]["kyber_public_key"]

    # 2. Decode the incoming base64 file string
    try:
        file_bytes = base64.b64decode(req.file_bytes_b64)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid base64 encoding for file_bytes_b64")

    # 3. Encrypt file using Kyber-768 KEM -> Shared Secret -> AES-GCM
    try:
        encrypted_payload_b64, kyber_ciphertext_b64 = encrypt_file(file_bytes, receiver_public_key_b64)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Encryption failed: {str(e)}")

    # 4. Sign the encrypted payload using Dilithium3 signature scheme
    try:
        dilithium_signature_b64 = sign_file(encrypted_payload_b64, req.admin_private_key_b64)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Signing failed: {str(e)}")

    # 5. Connect and store in secure_files table
    record = {
        "sender_id": req.sender_id,
        "receiver_id": req.receiver_id,
        "encrypted_payload": encrypted_payload_b64, # AES result
        "kyber_ciphertext": kyber_ciphertext_b64,   # Kyber encapsulation
        "dilithium_signature": dilithium_signature_b64, # Dilithium signature
        "status": "pending"
    }
    insert_res = supabase.table("secure_files").insert(record).execute()
    
    if not insert_res.data:
        raise HTTPException(status_code=500, detail="Failed to save secure file record to database")
    
    file_record = insert_res.data[0]

    # 6. Log the action in audit_logs
    log_audit(req.sender_id, "send_file", {"file_id": file_record["id"]}, request)

    return {"message": "File PQC encrypted, signed, and sent successfully", "file": file_record}

@router.post("/{file_id}/confirm")
async def confirm_file_receipt(file_id: str, request: Request, receiver_id: str):
    """
    Employee confirms receipt of a file.
    - updates status to 'received' or 'confirmed'
    """
    update_res = supabase.table("secure_files").update({"status": "confirmed"}).eq("id", file_id).execute()
    if not update_res.data:
        raise HTTPException(status_code=404, detail="File not found or update failed")
    
    log_audit(receiver_id, "confirm_file_receipt", {"file_id": file_id}, request)
    return {"message": "Receipt confirmed", "file": update_res.data[0]}

@router.post("/{file_id}/decrypt")
async def get_file_for_decryption(file_id: str, req: FileDecryptRequest, request: Request):
    """
    Employee decrypts the file.
    Note: We map this to POST instead of GET so private keys are sent via request body for better security, avoiding query param logging.
    - verify_signature() using Admin's Dilithium public key.
    - decrypt_file() using Employee's Kyber private key.
    """
    # Fetch file record
    res = supabase.table("secure_files").select("*").eq("id", file_id).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail="File not found")
        
    file_record = res.data[0]
    receiver_id = file_record["receiver_id"]

    # 1. Verify Dilithium signature BEFORE anything else
    is_valid = verify_signature(
        file_record["encrypted_payload"], 
        file_record["dilithium_signature"], 
        req.admin_public_key_b64
    )
    if not is_valid:
        raise HTTPException(status_code=403, detail="Signature verification failed: File payload may be tampered")
    
    # 2. Decrypt file using AES-GCM with shared secret from Kyber-768
    try:
        decrypted_bytes = decrypt_file(
            file_record["encrypted_payload"],
            file_record["kyber_ciphertext"],
            req.receiver_private_key_b64
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"PQC Decryption failed: {str(e)}")

    # 3. Log the successful decryption
    log_audit(receiver_id, "decrypt_file", {"file_id": file_id}, request)

    # 4. Return decrypted original bytes back to client (base64 encoded for JSON)
    return {
        "message": "File signature verified and decrypted successfully", 
        "file_bytes_b64": base64.b64encode(decrypted_bytes).decode('utf-8')
    }

@router.get("/received")
async def get_received_files(receiver_id: str):
    """Get all files received by a specific user."""
    result = supabase.table("secure_files").select("*").eq("receiver_id", receiver_id).execute()
    return result.data
