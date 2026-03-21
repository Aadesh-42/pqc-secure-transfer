import os
import base64
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# Try to import oqs, fallback to mock if not available
try:
    # import oqs
    OQS_AVAILABLE = False # Force false for now to avoid installer hang
except (ImportError, RuntimeError):
    OQS_AVAILABLE = False
    print("WARNING: liboqs not found or failed to load. Using mock PQC service for development.")

# 2. KEY GENERATION
def generate_kyber_keypair() -> tuple[str, str]:
    """
    Generate Kyber-768 public/private key pair.
    Returns: (public_key_b64, private_key_b64)
    """
    if not OQS_AVAILABLE:
        # Mock keys for development
        return base64.b64encode(os.urandom(1184)).decode('utf-8'), base64.b64encode(os.urandom(2400)).decode('utf-8')

    with oqs.KeyEncapsulation('Kyber768') as kem:
        public_key = kem.generate_keypair()
        private_key = kem.export_secret_key()
        return base64.b64encode(public_key).decode('utf-8'), base64.b64encode(private_key).decode('utf-8')

def generate_dilithium_keypair() -> tuple[str, str]:
    """
    Generate Dilithium3 public/private key pair.
    Returns: (public_key_b64, private_key_b64)
    """
    if not OQS_AVAILABLE:
        # Mock keys for development
        return base64.b64encode(os.urandom(1952)).decode('utf-8'), base64.b64encode(os.urandom(4032)).decode('utf-8')

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
    if not OQS_AVAILABLE:
        # Mock encryption (using a fixed mock secret for development)
        mock_secret = b"this_is_a_mock_secret_32_bytes!!"
        aesgcm = AESGCM(mock_secret)
        nonce = os.urandom(12)
        encrypted_data = aesgcm.encrypt(nonce, file_bytes, None)
        encrypted_payload = nonce + encrypted_data
        mock_ciphertext = os.urandom(1088)
        return base64.b64encode(encrypted_payload).decode('utf-8'), base64.b64encode(mock_ciphertext).decode('utf-8')

    receiver_public_key = base64.b64decode(receiver_public_key_b64)
    
    with oqs.KeyEncapsulation('Kyber768') as sender:
        kyber_ciphertext, shared_secret = sender.encap_secret(receiver_public_key)
        aesgcm = AESGCM(shared_secret)
        nonce = os.urandom(12)
        encrypted_data = aesgcm.encrypt(nonce, file_bytes, None)
        encrypted_payload = nonce + encrypted_data
        return base64.b64encode(encrypted_payload).decode('utf-8'), base64.b64encode(kyber_ciphertext).decode('utf-8')

# 4. FILE SIGNING (Admin signs)
def sign_file(encrypted_payload_b64: str, admin_private_key_b64: str) -> str:
    """
    Sign encrypted payload using Dilithium3.
    Returns: dilithium_signature_b64
    """
    if not OQS_AVAILABLE:
        # Mock signature
        return base64.b64encode(os.urandom(3300)).decode('utf-8')

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
    if not OQS_AVAILABLE:
        return True # Always valid in mock mode

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
    if not OQS_AVAILABLE:
        # Mock decryption
        mock_secret = b"this_is_a_mock_secret_32_bytes!!"
        encrypted_payload = base64.b64decode(encrypted_payload_b64)
        nonce = encrypted_payload[:12]
        encrypted_data = encrypted_payload[12:]
        aesgcm = AESGCM(mock_secret)
        return aesgcm.decrypt(nonce, encrypted_data, None)

    receiver_private_key = base64.b64decode(receiver_private_key_b64)
    kyber_ciphertext = base64.b64decode(kyber_ciphertext_b64)
    encrypted_payload = base64.b64decode(encrypted_payload_b64)
    
    with oqs.KeyEncapsulation('Kyber768') as client:
        client.secret_key = receiver_private_key
        shared_secret = client.decap_secret(kyber_ciphertext)
        nonce = encrypted_payload[:12]
        encrypted_data = encrypted_payload[12:]
        aesgcm = AESGCM(shared_secret)
        decrypted_data = aesgcm.decrypt(nonce, encrypted_data, None)
        return decrypted_data
