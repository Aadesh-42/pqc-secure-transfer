# PQC Secure File Transfer App

A comprehensive, state-of-future secure file transfer system built to withstand threats from quantum computers. The platform allows an Admin to create tasks and securely send encrypted files to Employees, ensuring that neither classical nor quantum adversaries can decipher the payloads in transit or at rest.

## Project Architecture & Tech Stack

This project is separated into a mobile frontend and a high-performance backend.

- **Frontend:** Flutter & Dart
- **Backend API:** FastAPI (Python 3.11)
- **Database:** PostgreSQL hosted on Supabase
- **Authentication:** JWT + Time-based One-Time Password (TOTP) MFA
- **Cryptography Layer:** Open Quantum Safe (`liboqs`) Native C-library
- **Deployment:** Render.com (Docker Environment)

## Live Backend URL
The backend is currently deployed and live at:
`https://pqc-secure-transfer.onrender.com`

---

## Technical PQC Security Explanation

Traditional cryptography relies on the difficulty of factoring large primes (RSA) or computing discrete logarithms (Elliptic Curve Cryptography). However, Peter Shor's algorithm proved that a sufficiently powerful quantum computer can break these systems instantly. 

This application replaces traditional asymmetric cryptography with **Post-Quantum Cryptography** (PQC) standardized by NIST:

1. **Kyber-768 (KEM):** Used for exchanging symmetric keys. When the Admin sends a file, a shared AES-256-GCM secret is encapsulated using the Employee's target Kyber public key. It is theoretically resistant to quantum decryption attacks.
2. **Dilithium3 (Digital Signatures):** Used to verify authenticity. The encrypted file payload is mathematically signed using the Admin's Dilithium private key. The Employee's device verifies this signature using the Admin's Dilithium public key to ensure the file was not tampered with.

---

## How to Run the Flutter App

**Prerequisites:**
- Flutter 3.x installed
- Android Studio or VS Code
- Android emulator or a physical device

**Steps:**
```bash
cd flutter_app
flutter pub get
flutter run
```

**Test Credentials:**
*Note: Due to mandatory MFA, when logging in via the app, you will need to generate the 6-digit TOTP code using the specific `mfa_secret` found in the Supabase `users` table.*

* **Admin:** `admin@pqcapp.com` / `Admin@123456`
* **Employee:** `employee@pqcapp.com` / `Employee@123456`

---

## Database Schema Summary (Supabase)

- **`users`**: Stores user authentication details, role (`admin` or `employee`), hashed passwords, MFA secrets, and their public `kyber_public_key`.
- **`tasks`**: Tracks assignments given to employees by the admin with completion status.
- **`secure_files`**: Stores the actual metadata of transferred files, the AES encrypted payload, the Kyber KEM ciphertext, and the Dilithium signature.
- **`messages`**: Real-time or polled chat messages between admin and employees.
- **`audit_logs`**: Tracks sensitive actions taken on the platform for compliance.

---

## API Endpoints List

**Authentication**
- `POST /auth/register`: Create a new user account
- `POST /auth/login`: Login step 1 (Password verification)
- `POST /auth/mfa/verify`: Login step 2 (TOTP verification returning JWT)

**Tasks**
- `GET /tasks`: Retrieve all tasks based on user role
- `POST /tasks/create`: Admin endpoint to assign a task
- `PATCH /tasks/{task_id}/status`: Update completion status

**Files (PQC Core)**
- `POST /files/send`: Admin endpoint to encrypt, sign, and upload a file payload
- `POST /files/verify-and-decrypt`: Employee endpoint to fetch file, verify Dilithium signature, and decapsulate the Kyber secret to read the file.
- `GET /files/history`: View all previously sent files 

**Extras**
- `GET /messages/{user_id}`: Fetch chat history
- `POST /messages/send`: Send a chat message
- `GET /audit/logs`: Admin endpoint to view system-wide action logs
- `GET /health`: Monitor API health.

---

## Repository Structure

```
pqc-secure-transfer/
├── backend/                  # FastAPI Application
│   ├── main.py               # Application Entrypoint
│   ├── Dockerfile            # Custom liboqs C compiler Docker container
│   ├── render.yaml           # CD configuration for Render.com
│   ├── requirements.txt      # Python dependencies
│   ├── routers/              # API Endpoint routes (Auth, Files, Tasks...)
│   ├── models/               # Pydantic data schemas
│   ├── services/             # Core logic (Auth, PQC wrapper)
│   └── database/             # Supabase Python SDK connection
├── flutter_app/              # Flutter Mobile Application
│   ├── pubspec.yaml          # Dart dependencies
│   └── lib/
│       ├── main.dart         # UI Flow entrypoint
│       ├── models/           # Dart native classes
│       ├── services/         # API HTTP handlers using Dio
│       ├── screens/          # Main UI view screens
│       └── widgets/          # Reusable customized components
└── database/
    └── migrations/           # SQL scripts representing the DB Schema
```
