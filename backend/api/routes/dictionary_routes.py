"""
dictionary_routes.py — Word lookup với caching và enrichment
"""
from flask import Blueprint, jsonify, request
import requests

dictionary_bp = Blueprint("dictionary", __name__)

DICT_URL  = "https://api.dictionaryapi.dev/api/v2/entries/en"
TRANS_URL = "https://api.mymemory.translated.net/get"


def _fetch_definition(word: str) -> dict:
    """Lấy định nghĩa từ Oxford Dictionary API"""
    try:
        res  = requests.get(f"{DICT_URL}/{word}", timeout=8)
        data = res.json()
        if not isinstance(data, list) or not data:
            return {}
        entry = data[0]
        phonetic = entry.get("phonetic", "")
        if not phonetic:
            phonetic = next(
                (p["text"] for p in entry.get("phonetics", []) if p.get("text")),
                ""
            )
        meanings = []
        for m in entry.get("meanings", [])[:3]:
            defs = []
            for d in m.get("definitions", [])[:2]:
                defs.append({
                    "definition": d.get("definition", ""),
                    "example":    d.get("example", ""),
                    "synonyms":   d.get("synonyms", [])[:4],
                    "antonyms":   d.get("antonyms", [])[:4],
                })
            meanings.append({
                "partOfSpeech": m.get("partOfSpeech", ""),
                "definitions":  defs,
                "synonyms":     m.get("synonyms", [])[:4],
                "antonyms":     m.get("antonyms", [])[:4],
            })
        return {
            "word":     entry.get("word", word),
            "phonetic": phonetic,
            "meanings": meanings,
        }
    except Exception:
        return {}


def _translate(text: str, langpair: str = "en|vi") -> str:
    """Dịch text qua MyMemory"""
    try:
        res = requests.get(
            TRANS_URL,
            params={"q": text, "langpair": langpair},
            timeout=8,
        )
        t = res.json().get("responseData", {}).get("translatedText", "")
        return "" if t.upper().startswith("MYMEMORY") else t
    except Exception:
        return ""


@dictionary_bp.route("/word/<word>")
def lookup_word(word: str):
    """
    Tra từ đầy đủ: định nghĩa + dịch nghĩa + dịch ví dụ
    Response: { word, phonetic, translation, meanings, audioUrl }
    """
    word = word.lower().strip()
    definition = _fetch_definition(word)

    if not definition:
        return jsonify({"error": f"Word '{word}' not found"}), 404

    # Dịch nghĩa chính
    translation = _translate(word)

    # Dịch ví dụ đầu tiên
    first_example = ""
    first_example_vi = ""
    for m in definition.get("meanings", []):
        for d in m.get("definitions", []):
            if d.get("example"):
                first_example    = d["example"]
                first_example_vi = _translate(first_example)
                break
        if first_example:
            break

    return jsonify({
        "word":          definition.get("word", word),
        "phonetic":      definition.get("phonetic", ""),
        "translation":   translation,
        "meanings":      definition.get("meanings", []),
        "example":       first_example,
        "exampleVi":     first_example_vi,
    })


@dictionary_bp.route("/word-batch", methods=["POST"])
def lookup_batch():
    """
    Tra nhiều từ cùng lúc (dùng cho seeding flashcard topics)
    Body: { words: ["word1", "word2", ...] }
    """
    data  = request.get_json()
    words = data.get("words", [])

    if not words or len(words) > 30:
        return jsonify({"error": "Provide 1-30 words"}), 400

    results = []
    for word in words:
        word = word.lower().strip()
        defn = _fetch_definition(word)
        if defn:
            translation = _translate(word)
            first_example = ""
            first_example_vi = ""
            for m in defn.get("meanings", []):
                for d in m.get("definitions", []):
                    if d.get("example"):
                        first_example    = d["example"]
                        first_example_vi = _translate(first_example)
                        break
                if first_example:
                    break
            results.append({
                "word":        defn.get("word", word),
                "phonetic":    defn.get("phonetic", ""),
                "meaning":     translation,
                "example":     first_example,
                "exampleVi":   first_example_vi,
                "imageUrl":    "",
            })
        else:
            results.append({
                "word":      word,
                "phonetic":  "",
                "meaning":   word,
                "example":   "",
                "exampleVi": "",
                "imageUrl":  "",
            })

    return jsonify({"results": results})
