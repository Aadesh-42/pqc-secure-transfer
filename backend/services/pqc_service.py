import os
import base64
import oqs
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# 2. KEY GENERATION
def generate_kyber_keypair() -> tuple[str, str]:
    """
    Generate Kyber-768 public/private key pair.
    Returns: (public_key_b64, private_key_b64)
    Public key gets stored in users table.
    Private key returned to user only (never stored).
    """
    with oqs.KeyEncapsulation('Kyber768') as kem:
        public_key = kem.generate_keypair()
        private_key = kem.export_secret_key()
        return base64.b64encode(public_key).decode('utf-8'), base64.b64encode(private_key).decode('utf-8')

def generate_dilithium_keypair() -> tuple[str, str]:
    """
    Generate Dilithium3 public/private key pair.
    Returns: (public_key_b64, private_key_b64)
    Admin uses this for signing files.
    """
    with oqs.Signature('Dilithium3') as sig:
        public_key = sig.generate_keypair()
        private_key = sig.export_secret_key()
        return base64.b64encode(public_key).decode('utf-8'), base64.b64encode(private_key).decode('utf-8')

# 3. FILE ENCRYPTION (Admin sends file)
def encrypt_file(file_bytes: bytes, receiver_public_key_b64: str) -> tuple[str, str]:
    """
    Generate shared secret using Kyber-768 KEM.
    Encrypt file with AES-256-GCM using shared secret.
    Returns: (encrypted_payload_b64, kyber_ciphertext_b64)
    """
    receiver_public_key = base64.b64decode(receiver_public_key_b64)
    
    with oqs.KeyEncapsulation('Kyber768') as sender:
        # Encapsulate to get ciphertext and shared secret
        # shared_secret is exactly 32 bytes for Kyber768, perfect for AES-256
        kyber_ciphertext, shared_secret = sender.encap_secret(receiver_public_key)
        
        # Encrypt file with AES-256-GCM using the shared secret
        aesgcm = AESGCM(shared_secret)
        nonce = os.urandom(12) # 96-bit nonce for GCM
        encrypted_data = aesgcm.encrypt(nonce, file_bytes, None)
        
        # Prepend nonce to the encrypted data
        encrypted_payload = nonce + encrypted_data
        
        return base64.b64encode(encrypted_payload).decode('utf-8'), base64.b64encode(kyber_ciphertext).decode('utf-8')

# 4. FILE SIGNING (Admin signs)
def sign_file(encrypted_payload_b64: str, admin_private_key_b64: str) -> str:
    """
    Sign encrypted payload using Dilithium3.
    Returns: dilithium_signature_b64
    """
    admin_private_key = base64.b64decode(admin_private_key_b64)
    encrypted_payload = base64.b64decode(encrypted_payload_b64)
    
    with oqs.Signature('Dilithium3') as signer:
        signer.secret_key = admin_private_key
        signature = signer.sign(encrypted_payload)
        return base64.b64encode(signature).decode('utf-8')

# 5. FILE VERIFICATION (Employee verifies)
def verify_signature(encrypted_payload_b64: str, signature_b64: str, admin_public_key_b64: str) -> bool:
    """
    Verify Dilithium3 signature.
    Returns True if valid, False if tampered.
    """
    try:
        admin_public_key = base64.b64decode(admin_public_key_b64)
        encrypted_payload = base64.b64decode(encrypted_payload_b64)
        signature = base64.b64decode(signature_b64)
        
        with oqs.Signature('Dilithium3') as verifier:
            return verifier.verify(encrypted_payload, signature, admin_public_key)
    except Exception as e:
        print(f"Signature verification error: {e}")
        return False

# 6. FILE DECRYPTION (Employee decrypts)
def decrypt_file(encrypted_payload_b64: str, kyber_ciphertext_b64: str, receiver_private_key_b64: str) -> bytes:
    """
    Decapsulate shared secret using Kyber-768.
    Decrypt file using AES-256-GCM.
    Returns: original_file_bytes
    """
    receiver_private_key = base64.b64decode(receiver_private_key_b64)
    kyber_ciphertext = base64.b64decode(kyber_ciphertext_b64)
    encrypted_payload = base64.b64decode(encrypted_payload_b64)
    
    with oqs.KeyEncapsulation('Kyber768') as client:
        client.secret_key = receiver_private_key
        # Decapsulate to retrieve the EXACT SAME 32-byte shared secret
        shared_secret = client.decap_secret(kyber_ciphertext)
        
        # Extract nonce (first 12 bytes) and ciphertext
        nonce = encrypted_payload[:12]
        encrypted_data = encrypted_payload[12:]
        
        # Decrypt using AES-256-GCM
        aesgcm = AESGCM(shared_secret)
        decrypted_data = aesgcm.decrypt(nonce, encrypted_data, None)
        return decrypted_data
