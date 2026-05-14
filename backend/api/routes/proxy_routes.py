"""
proxy_routes.py — Proxy các external API (Dictionary, Translation)
Ẩn API keys, tránh CORS issues từ browser
"""
from flask import Blueprint, request, jsonify
import requests
from config import GROQ_API_KEY, GROQ_URL, GROQ_MODEL

proxy_bp = Blueprint("proxy", __name__)

DICT_BASE_URL  = "https://api.dictionaryapi.dev/api/v2/entries/en"
TRANS_BASE_URL = "https://api.mymemory.translated.net/get"


@proxy_bp.route("/dictionary/<word>")
def dictionary(word: str):
    """Proxy Oxford Dictionary API"""
    try:
        res = requests.get(f"{DICT_BASE_URL}/{word}", timeout=10)
        return jsonify(res.json()), res.status_code
    except requests.Timeout:
        return jsonify({"error": "Dictionary API timeout"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@proxy_bp.route("/translate")
def translate():
    """Proxy MyMemory Translation API"""
    q        = request.args.get("q", "").strip()
    langpair = request.args.get("langpair", "en|vi")

    if not q:
        return jsonify({"error": "Missing query parameter 'q'"}), 400

    try:
        res = requests.get(
            TRANS_BASE_URL,
            params={"q": q, "langpair": langpair},
            timeout=10,
        )
        return jsonify(res.json()), res.status_code
    except requests.Timeout:
        return jsonify({"error": "Translation API timeout"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500
