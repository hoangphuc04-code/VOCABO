"""
config_routes.py — Cung cấp Firebase config và app config cho frontend
Frontend cần gọi endpoint này để lấy config (không hardcode ở client)
"""
from flask import Blueprint, jsonify
from config import (
    FIREBASE_CONFIG, ADMIN_EMAILS,
    CLOUDINARY_CLOUD_NAME, CLOUDINARY_UPLOAD_PRESET,
    GROQ_MODEL,
)

config_bp = Blueprint("config", __name__)


@config_bp.route("/config")
def get_config():
    """
    Trả về toàn bộ config cần thiết cho frontend.
    Frontend gọi 1 lần khi khởi động.
    """
    return jsonify({
        "firebase":    FIREBASE_CONFIG,
        "adminEmails": ADMIN_EMAILS,
        "cloudinary": {
            "cloudName":    CLOUDINARY_CLOUD_NAME,
            "uploadPreset": CLOUDINARY_UPLOAD_PRESET,
        },
        "ai": {
            "model": GROQ_MODEL,
        },
    })
