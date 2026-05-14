"""
ai_routes.py — AI endpoints nâng cao:
  - Meow Chat (text + image)
  - Study Plan Generator (theo mốc thời gian → calendar events)
  - Motivation Engine (gửi tin nhắn động viên dựa trên dữ liệu user)
  - Conflict Detector (phát hiện sự kiện trùng lịch)
  - Image Analysis (đọc ảnh từ user)
"""
from flask import Blueprint, request, jsonify
import requests
import base64
import json
import re
from datetime import datetime, timedelta
from config import GROQ_API_KEY, GROQ_URL, GROQ_MODEL

ai_bp = Blueprint("ai", __name__)

# ── Groq Vision model (hỗ trợ image) ──────────────────────────────────────────
GROQ_VISION_MODEL = "meta-llama/llama-4-scout-17b-16e-instruct"


def _call_groq(messages: list, model: str = None, max_tokens: int = 1024, temperature: float = 0.7) -> dict:
    """Helper gọi Groq API"""
    res = requests.post(
        GROQ_URL,
        headers={
            "Content-Type":  "application/json",
            "Authorization": f"Bearer {GROQ_API_KEY}",
        },
        json={
            "model":       model or GROQ_MODEL,
            "messages":    messages,
            "max_tokens":  max_tokens,
            "temperature": temperature,
        },
        timeout=45,
    )
    res.raise_for_status()
    return res.json()


# ── 1. Meow Chat (text + image) ────────────────────────────────────────────────
@ai_bp.route("/chat", methods=["POST"])
def meow_chat():
    """
    Meow AI Chat — hỗ trợ text và image
    Body: {
      messages: [...],
      image_base64?: "data:image/...;base64,...",   # optional
      user_context?: { level, streak, wordsLearned, ... }
    }
    """
    data = request.get_json()
    if not data or "messages" not in data:
        return jsonify({"error": "Missing 'messages'"}), 400

    messages      = data["messages"]
    image_b64     = data.get("image_base64")
    user_context  = data.get("user_context", {})

    # Nếu có ảnh → dùng vision model, inject image vào message cuối
    if image_b64:
        # Lấy message cuối của user
        last_user_idx = None
        for i in range(len(messages) - 1, -1, -1):
            if messages[i]["role"] == "user":
                last_user_idx = i
                break

        if last_user_idx is not None:
            original_text = messages[last_user_idx].get("content", "")
            # Chuyển content thành multipart (text + image)
            messages[last_user_idx]["content"] = [
                {"type": "text",      "text": original_text or "Phân tích hình ảnh này cho mình nhé 😺"},
                {"type": "image_url", "image_url": {"url": image_b64}},
            ]
        model_to_use = GROQ_VISION_MODEL
    else:
        model_to_use = GROQ_MODEL

    try:
        result = _call_groq(messages, model=model_to_use, max_tokens=1500)
        return jsonify(result), 200
    except requests.Timeout:
        return jsonify({"error": "AI API timeout"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── 2. Study Plan Generator ────────────────────────────────────────────────────
@ai_bp.route("/study-plan", methods=["POST"])
def generate_study_plan():
    """
    Tạo kế hoạch học tiếng Anh theo mốc thời gian → trả về calendar events
    Body: {
      level: "A1",
      targetLevel: "B1",
      deadline: "2025-12-31",       # mốc thời gian mục tiêu
      dailyGoal: 10,
      availableHours: 1.5,
      focusAreas: ["vocabulary","grammar","listening"],
      existingEvents: [...]          # sự kiện đã có trong calendar
    }
    Response: {
      plan: { summary, weeklySchedule, milestones },
      calendarEvents: [{ title, date, time, description, type }]
    }
    """
    data = request.get_json()
    level           = data.get("level", "A1")
    target_level    = data.get("targetLevel", "B1")
    deadline        = data.get("deadline", "")
    daily_goal      = data.get("dailyGoal", 10)
    available_hrs   = data.get("availableHours", 1)
    focus_areas     = data.get("focusAreas", ["vocabulary", "grammar"])
    existing_events = data.get("existingEvents", [])

    today = datetime.now().strftime("%Y-%m-%d")

    # Tính số ngày còn lại
    days_left = ""
    if deadline:
        try:
            dl = datetime.strptime(deadline, "%Y-%m-%d")
            days_left = f"{(dl - datetime.now()).days} ngày"
        except Exception:
            days_left = "không xác định"

    existing_str = ""
    if existing_events:
        existing_str = f"\nLịch hiện có:\n" + "\n".join(
            f"- {e.get('date','')} {e.get('time','')}: {e.get('title','')}"
            for e in existing_events[:10]
        )

    prompt = f"""Bạn là chuyên gia lập kế hoạch học tiếng Anh. Tạo kế hoạch chi tiết:

THÔNG TIN NGƯỜI HỌC:
- Cấp độ hiện tại: {level}
- Mục tiêu: {target_level}
- Deadline: {deadline} (còn {days_left})
- Ngày bắt đầu: {today}
- Thời gian học: {available_hrs} giờ/ngày
- Mục tiêu từ vựng: {daily_goal} từ/ngày
- Tập trung: {', '.join(focus_areas)}
{existing_str}

Trả về JSON CHÍNH XÁC theo format sau (không thêm text ngoài JSON):
{{
  "summary": "Tóm tắt kế hoạch ngắn gọn",
  "milestones": [
    {{"date": "YYYY-MM-DD", "title": "Milestone title", "description": "mô tả"}}
  ],
  "weeklySchedule": [
    {{"day": "Thứ 2", "tasks": ["task1", "task2"], "duration": "90 phút", "focus": "vocabulary"}}
  ],
  "calendarEvents": [
    {{"title": "tên sự kiện", "date": "YYYY-MM-DD", "time": "HH:MM", "description": "mô tả", "type": "study|milestone|review|test"}}
  ],
  "tips": ["tip1", "tip2"]
}}

Tạo ít nhất 8-12 calendarEvents trải đều từ hôm nay đến deadline, bao gồm:
- Các buổi học hàng tuần
- Milestone kiểm tra tiến độ
- Buổi ôn tập tổng hợp
- Bài test thử
QUAN TRỌNG: Tránh trùng với lịch hiện có."""

    try:
        result = _call_groq(
            [{"role": "user", "content": prompt}],
            max_tokens=3000,
            temperature=0.3,
        )
        content = result["choices"][0]["message"]["content"]

        # Parse JSON từ response
        plan_data = None
        try:
            # Tìm JSON block
            json_match = re.search(r'\{[\s\S]*\}', content)
            if json_match:
                plan_data = json.loads(json_match.group())
        except Exception:
            plan_data = None

        return jsonify({
            "plan":           plan_data,
            "rawContent":     content,
            "calendarEvents": plan_data.get("calendarEvents", []) if plan_data else [],
        }), 200

    except requests.Timeout:
        return jsonify({"error": "AI API timeout"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── 3. Motivation Engine ───────────────────────────────────────────────────────
@ai_bp.route("/motivate", methods=["POST"])
def generate_motivation():
    """
    Tạo tin nhắn động viên cá nhân hóa dựa trên dữ liệu người dùng
    Body: {
      userData: {
        displayName, level, streak, wordsLearned, dailyGoal,
        lastTestScore, totalTests, grammarDone,
        lastActiveDate, missedDays
      },
      trigger: "daily_reminder" | "streak_broken" | "milestone" | "low_activity" | "good_progress"
    }
    Response: { message, type, emoji, actionSuggestion }
    """
    data      = request.get_json()
    user_data = data.get("userData", {})
    trigger   = data.get("trigger", "daily_reminder")

    name         = user_data.get("displayName", "bạn")
    level        = user_data.get("level", "A1")
    streak       = user_data.get("streak", 0)
    words        = user_data.get("wordsLearned", 0)
    daily_goal   = user_data.get("dailyGoal", 10)
    test_score   = user_data.get("lastTestScore", 0)
    missed_days  = user_data.get("missedDays", 0)
    grammar_done = len(user_data.get("grammarDone", []))

    trigger_context = {
        "daily_reminder": f"Nhắc nhở học hàng ngày. Streak hiện tại: {streak} ngày.",
        "streak_broken":  f"Người dùng vừa bị mất streak sau {streak} ngày. Cần động viên.",
        "milestone":      f"Người dùng vừa đạt {words} từ đã học. Chúc mừng!",
        "low_activity":   f"Người dùng không hoạt động {missed_days} ngày. Cần thúc giục nhẹ nhàng.",
        "good_progress":  f"Điểm test gần nhất: {test_score}%. Tiến bộ tốt!",
    }.get(trigger, "Nhắc nhở học hàng ngày.")

    prompt = f"""Bạn là Meow 😺 — trợ lý AI dễ thương, thân thiện, hay dùng emoji mèo.

THÔNG TIN NGƯỜI DÙNG:
- Tên: {name}
- Cấp độ: {level}
- Streak: {streak} ngày liên tiếp
- Từ đã học: {words} từ
- Mục tiêu: {daily_goal} từ/ngày
- Điểm test gần nhất: {test_score}%
- Bài ngữ pháp đã học: {grammar_done}/26
- Tình huống: {trigger_context}

Viết 1 tin nhắn động viên/thúc giục ngắn (2-4 câu), cá nhân hóa theo tên và dữ liệu.
Dùng emoji mèo, vui vẻ, không quá nghiêm túc.

Trả về JSON:
{{
  "message": "nội dung tin nhắn",
  "emoji": "emoji chính",
  "actionSuggestion": "gợi ý hành động cụ thể (ví dụ: Học 5 từ mới ngay nhé!)",
  "type": "{trigger}"
}}"""

    try:
        result = _call_groq(
            [{"role": "user", "content": prompt}],
            max_tokens=400,
            temperature=0.9,
        )
        content = result["choices"][0]["message"]["content"]

        msg_data = None
        try:
            json_match = re.search(r'\{[\s\S]*\}', content)
            if json_match:
                msg_data = json.loads(json_match.group())
        except Exception:
            msg_data = {"message": content, "emoji": "😺", "actionSuggestion": "", "type": trigger}

        return jsonify(msg_data), 200

    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ── 4. Conflict Detector ───────────────────────────────────────────────────────
@ai_bp.route("/detect-conflicts", methods=["POST"])
def detect_conflicts():
    """
    Phát hiện sự kiện trùng lịch
    Body: {
      newEvent: { title, date, time, duration? },
      existingEvents: [{ id, title, date, time, duration? }]
    }
    Response: {
      hasConflict: bool,
      conflicts: [{ existingEvent, overlapMinutes }],
      suggestions: { option1, option2, option3 }
    }
    """
    data            = request.get_json()
    new_event       = data.get("newEvent", {})
    existing_events = data.get("existingEvents", [])

    if not new_event or not existing_events:
        return jsonify({"hasConflict": False, "conflicts": []}), 200

    def parse_dt(date_str, time_str):
        try:
            return datetime.strptime(f"{date_str} {time_str or '00:00'}", "%Y-%m-%d %H:%M")
        except Exception:
            return None

    new_start    = parse_dt(new_event.get("date", ""), new_event.get("time", ""))
    new_duration = new_event.get("duration", 60)  # phút, mặc định 60
    new_end      = new_start + timedelta(minutes=new_duration) if new_start else None

    conflicts = []
    for ev in existing_events:
        ev_start    = parse_dt(ev.get("date", ""), ev.get("time", ""))
        ev_duration = ev.get("duration", 60)
        ev_end      = ev_start + timedelta(minutes=ev_duration) if ev_start else None

        if not (new_start and ev_start and new_end and ev_end):
            continue

        # Kiểm tra overlap
        overlap_start = max(new_start, ev_start)
        overlap_end   = min(new_end, ev_end)
        if overlap_start < overlap_end:
            overlap_mins = int((overlap_end - overlap_start).total_seconds() / 60)
            conflicts.append({
                "existingEvent":  ev,
                "overlapMinutes": overlap_mins,
            })

    if not conflicts:
        return jsonify({"hasConflict": False, "conflicts": []}), 200

    # Tạo suggestions cho conflict đầu tiên
    conflict_ev = conflicts[0]["existingEvent"]
    ev_dt       = parse_dt(conflict_ev.get("date", ""), conflict_ev.get("time", ""))

    # Option 2: lùi sự kiện mới 1 tiếng sau sự kiện cũ
    suggested_new_time = None
    if ev_dt:
        suggested_new_time = (ev_dt + timedelta(minutes=conflict_ev.get("duration", 60) + 15)).strftime("%H:%M")

    # Option 3: lùi sự kiện cũ 1 tiếng trước sự kiện mới
    suggested_old_time = None
    if new_start:
        suggested_old_time = (new_start + timedelta(minutes=new_duration + 15)).strftime("%H:%M")

    return jsonify({
        "hasConflict": True,
        "conflicts":   conflicts,
        "newEvent":    new_event,
        "suggestions": {
            "option1": {
                "label":       f"Ưu tiên '{new_event.get('title')}', lùi '{conflict_ev.get('title')}' sang {suggested_old_time}",
                "action":      "reschedule_existing",
                "newTime":     suggested_old_time,
                "targetEvent": conflict_ev.get("id"),
            },
            "option2": {
                "label":       f"Ưu tiên '{conflict_ev.get('title')}', lùi '{new_event.get('title')}' sang {suggested_new_time}",
                "action":      "reschedule_new",
                "newTime":     suggested_new_time,
            },
            "option3": {
                "label":       f"Xóa '{conflict_ev.get('title')}'",
                "action":      "delete_existing",
                "targetEvent": conflict_ev.get("id"),
            },
        },
    }), 200


# ── 5. Analyze Image ───────────────────────────────────────────────────────────
@ai_bp.route("/analyze-image", methods=["POST"])
def analyze_image():
    """
    Phân tích ảnh từ user — trích xuất thông tin học tập, lịch, v.v.
    Body: {
      image_base64: "data:image/...;base64,...",
      context?: "calendar" | "vocabulary" | "general"
    }
    Response: {
      description: str,
      extractedEvents?: [...],
      extractedWords?: [...],
      suggestion: str
    }
    """
    data       = request.get_json()
    image_b64  = data.get("image_base64", "")
    context    = data.get("context", "general")

    if not image_b64:
        return jsonify({"error": "Missing image_base64"}), 400

    context_prompts = {
        "calendar": "Nếu ảnh chứa lịch, thời khóa biểu, hoặc sự kiện, hãy trích xuất thành danh sách sự kiện JSON.",
        "vocabulary": "Nếu ảnh chứa từ vựng, văn bản tiếng Anh, hãy trích xuất các từ quan trọng.",
        "general": "Phân tích ảnh và đề xuất cách liên kết với việc học tiếng Anh.",
    }

    prompt = f"""Bạn là Meow 😺 — trợ lý AI học tiếng Anh.
Phân tích hình ảnh này và trả lời bằng tiếng Việt.
{context_prompts.get(context, context_prompts['general'])}

Trả về JSON:
{{
  "description": "mô tả ngắn về ảnh",
  "extractedEvents": [{{"title":"...","date":"YYYY-MM-DD","time":"HH:MM","description":"..."}}],
  "extractedWords": [{{"word":"...","meaning":"..."}}],
  "suggestion": "gợi ý hành động cho người dùng",
  "hasCalendarData": true/false,
  "hasVocabularyData": true/false
}}"""

    try:
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text",      "text": prompt},
                    {"type": "image_url", "image_url": {"url": image_b64}},
                ],
            }
        ]
        result  = _call_groq(messages, model=GROQ_VISION_MODEL, max_tokens=1500)
        content = result["choices"][0]["message"]["content"]

        parsed = None
        try:
            json_match = re.search(r'\{[\s\S]*\}', content)
            if json_match:
                parsed = json.loads(json_match.group())
        except Exception:
            parsed = {"description": content, "suggestion": "", "hasCalendarData": False, "hasVocabularyData": False}

        return jsonify(parsed or {"description": content}), 200

    except requests.Timeout:
        return jsonify({"error": "Vision API timeout"}), 504
    except Exception as e:
        return jsonify({"error": str(e)}), 500
