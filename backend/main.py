from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Import routers
from routers import auth, tasks, files, messages, audit

app = FastAPI(
    title="PQC Secure File Transfer API",
    description="FastAPI backend for PQC Secure File Transfer App",
    version="1.0.0"
)

# CORS enabled for Flutter
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include all routers
app.include_router(auth.router)
app.include_router(tasks.router)
app.include_router(files.router)
app.include_router(messages.router)
app.include_router(audit.router)

# Health check endpoint
@app.get("/health", tags=["System"])
async def health_check():
    """Check if the API is running."""
    return {"status": "ok", "message": "PQC Secure API is up and running"}

# Run with: uvicorn main:app --reload
