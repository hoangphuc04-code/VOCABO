"""
VOCABO Backend — Configuration
"""
import os
from dotenv import load_dotenv

load_dotenv()

# ── Firebase ───────────────────────────────────────────────────────────────────
FIREBASE_CONFIG = {
    "apiKey":            "AIzaSyAs8SThYkByqnEnNhPzWv9rpDbRK6CKkTo",
    "authDomain":        "vocabofinalapp.firebaseapp.com",
    "projectId":         "vocabofinalapp",
    "storageBucket":     "vocabofinalapp.firebasestorage.app",
    "messagingSenderId": "1060637668034",
    "appId":             "1:1060637668034:web:e02e11427a579b9ede015b",
    "measurementId":     "G-12XE10LPLT",
}

# ── AI / External APIs ─────────────────────────────────────────────────────────
GROQ_API_KEY  = os.getenv("GROQ_API_KEY", "")
GROQ_MODEL    = os.getenv("GROQ_MODEL",    "llama-3.3-70b-versatile")
GROQ_URL      = "https://api.groq.com/openai/v1/chat/completions"

# OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "")

# ── Cloudinary ─────────────────────────────────────────────────────────────────
CLOUDINARY_CLOUD_NAME    = os.getenv("CLOUDINARY_CLOUD_NAME",    "drkfnmqzm")
CLOUDINARY_UPLOAD_PRESET = os.getenv("CLOUDINARY_UPLOAD_PRESET", "vocabo_avatars")

# ── App ────────────────────────────────────────────────────────────────────────
SECRET_KEY   = os.getenv("SECRET_KEY", "vocabo-secret-key-2024")
DEBUG        = os.getenv("DEBUG", "true").lower() == "true"
PORT         = int(os.getenv("PORT", 8000))

# Admin emails (có thể mở rộng qua env)
ADMIN_EMAILS = os.getenv("ADMIN_EMAILS", "admin@vocabo.com,vocaboadmin@gmail.com").split(",")

# CORS origins cho frontend dev
CORS_ORIGINS = [
    "http://localhost:5173",   # Vite dev server
    "http://localhost:3000",
    "http://127.0.0.1:5173",
]
