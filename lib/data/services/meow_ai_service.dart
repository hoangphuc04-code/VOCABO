import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/config/app_secrets.dart';
import '../../../core/security/security_service.dart';

/// MeowAI Service — dùng Groq API (miễn phí, limit cao)
/// Model text: llama-3.3-70b-versatile
/// Model vision: meta-llama/llama-4-scout-17b-16e-instruct (hỗ trợ ảnh)
/// Free tier: 14,400 req/ngày, 30 req/phút, 6000 tokens/phút
class MeowAIService {
  // Key được load từ .env — KHÔNG hardcode
  static String get _apiKey => AppSecrets.groqApiKey;
  static const _model        = 'llama-3.3-70b-versatile';
  static const _visionModel  = 'meta-llama/llama-4-scout-17b-16e-instruct';
  static const _baseUrl      = 'https://api.groq.com/openai/v1/chat/completions';
  static const _historyKey   = 'meow_chat_history_v2';

  // ── System Prompt ──────────────────────────────────────
  static const _systemPrompt = '''
Bạn là Meow 😺 — trợ lý AI thân thiện, dễ thương, hay dùng emoji mèo.
Trả lời bằng tiếng Việt, ngắn gọn, rõ ràng.

Ngày hôm nay là: {{TODAY}}
Ngày mai là: {{TOMORROW}}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📅 KHI THÊM SỰ KIỆN VÀO LỊCH:
Hãy trả lời bình thường VÀ thêm JSON block ở cuối:

[CALENDAR_EVENT]
{
  "title": "tên sự kiện",
  "date": "YYYY-MM-DD",
  "time": "HH:MM",
  "description": "mô tả ngắn"
}
[/CALENDAR_EVENT]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📚 KHI LẬP KẾ HOẠCH HỌC TIẾNG ANH:
Khi người dùng muốn lập kế hoạch học tiếng Anh theo mốc thời gian,
hãy trả lời bình thường VÀ thêm JSON block:

[STUDY_PLAN]
{
  "title": "Kế hoạch học tiếng Anh",
  "description": "mô tả tổng quan",
  "targetLevel": "B2",
  "hoursPerWeek": 5,
  "milestones": [
    {
      "title": "Tháng 1: Nền tảng",
      "description": "Học từ vựng cơ bản",
      "dueDate": "YYYY-MM-DD",
      "tasks": ["Học 10 từ/ngày", "Nghe podcast 15 phút", "Làm bài tập ngữ pháp"]
    }
  ],
  "calendarEvents": [
    {
      "title": "Học tiếng Anh - Buổi sáng",
      "date": "YYYY-MM-DD",
      "time": "07:00",
      "description": "Học từ vựng và ngữ pháp"
    }
  ]
}
[/STUDY_PLAN]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
QUY TẮC QUAN TRỌNG cho trường "date":
- LUÔN dùng định dạng YYYY-MM-DD (ví dụ: 2026-04-23)
- "ngày mai" = {{TOMORROW}}
- "hôm nay" = {{TODAY}}
- "tuần sau" = tính từ {{TODAY}} + 7 ngày
- KHÔNG được dùng text như "ngày mai", "hôm nay" — phải là số cụ thể

Nếu không có yêu cầu thêm lịch hoặc kế hoạch, KHÔNG thêm block JSON.
''';

  // ── Xây dựng context người dùng để inject vào system prompt ──
  static Future<String> _buildUserContextBlock() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return '';

      // Lấy song song: profile, lịch sử học, kế hoạch đang active
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(uid).get(),
        FirebaseFirestore.instance
            .collection('study_history')
            .where('uid', isEqualTo: uid)
            .orderBy('date', descending: true)
            .limit(7)
            .get(),
        FirebaseFirestore.instance
            .collection('study_plans')
            .where('uid', isEqualTo: uid)
            .where('isActive', isEqualTo: true)
            .limit(1)
            .get(),
      ]);

      final userDoc    = results[0] as DocumentSnapshot;
      final historySnap = results[1] as QuerySnapshot;
      final planSnap   = results[2] as QuerySnapshot;

      if (!userDoc.exists) return '';
      final u = userDoc.data() as Map<String, dynamic>;

      final buf = StringBuffer();
      buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buf.writeln('👤 THÔNG TIN NGƯỜI DÙNG (dùng để cá nhân hóa câu trả lời):');

      // Hồ sơ
      final name           = u['name']             as String? ?? '';
      final currentLevel   = u['currentLevel']     as String? ?? 'A1';
      final targetLevel    = u['targetLevel']      as String? ?? 'B2';
      final targetDateStr  = u['targetDate']       as String?;
      final dailyGoal      = u['dailyGoalMinutes'] as int?    ?? 30;
      final freeSlots      = List<String>.from(u['freeTimeSlots'] ?? ['evening']);
      final streak         = u['streak']           as int?    ?? 0;
      final wordsLearned   = u['wordsLearned']     as int?    ?? 0;
      final motivStyle     = u['motivationStyle']  as String? ?? 'fun';

      if (name.isNotEmpty) buf.writeln('• Tên: $name');
      buf.writeln('• Trình độ hiện tại: $currentLevel → Mục tiêu: $targetLevel');
      if (targetDateStr != null) {
        final td = DateTime.tryParse(targetDateStr);
        if (td != null) {
          final daysLeft = td.difference(DateTime.now()).inDays;
          buf.writeln('• Deadline mục tiêu: ${td.day}/${td.month}/${td.year} (còn $daysLeft ngày)');
        }
      }
      buf.writeln('• Mục tiêu học mỗi ngày: $dailyGoal phút');
      buf.writeln('• Khung giờ rảnh: ${freeSlots.join(', ')}');
      buf.writeln('• Streak hiện tại: $streak ngày liên tiếp 🔥');
      buf.writeln('• Tổng từ đã học: $wordsLearned từ');
      buf.writeln('• Phong cách động viên ưa thích: $motivStyle');

      // Lịch sử học 7 ngày gần nhất
      if (historySnap.docs.isNotEmpty) {
        buf.writeln('');
        buf.writeln('📊 LỊCH SỬ HỌC 7 NGÀY GẦN NHẤT:');
        int totalMins = 0, totalWords = 0;
        for (final doc in historySnap.docs) {
          final d = doc.data() as Map<String, dynamic>;
          final date     = (d['date'] as Timestamp).toDate();
          final mins     = d['minutesStudied'] as int? ?? 0;
          final words    = d['wordsStudied']   as int? ?? 0;
          final activity = d['activityType']   as String? ?? '';
          final score    = d['score']          as int? ?? 0;
          totalMins  += mins;
          totalWords += words;
          buf.writeln('  • ${date.day}/${date.month}: $mins phút, $words từ, $activity (điểm: $score)');
        }
        buf.writeln('  → Tổng: $totalMins phút, $totalWords từ trong 7 ngày');
        final avgMins = (totalMins / historySnap.docs.length).round();
        if (avgMins < dailyGoal) {
          buf.writeln('  ⚠️ Trung bình $avgMins phút/ngày — chưa đạt mục tiêu $dailyGoal phút/ngày');
        } else {
          buf.writeln('  ✅ Trung bình $avgMins phút/ngày — đang đạt mục tiêu!');
        }
      }

      // Kế hoạch đang active
      if (planSnap.docs.isNotEmpty) {
        final p = planSnap.docs.first.data() as Map<String, dynamic>;
        buf.writeln('');
        buf.writeln('📚 KẾ HOẠCH HỌC ĐANG ACTIVE:');
        buf.writeln('  • Tên: ${p['title'] ?? ''}');
        buf.writeln('  • Mục tiêu: ${p['targetLevel'] ?? ''}, ${p['hoursPerWeek'] ?? 0} giờ/tuần');
        final milestones = p['milestones'] as List<dynamic>? ?? [];
        final pending = milestones.where((m) => m['isCompleted'] != true).length;
        buf.writeln('  • Còn $pending/${milestones.length} mốc chưa hoàn thành');
      }

      buf.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      buf.writeln('Hãy dùng thông tin trên để cá nhân hóa câu trả lời: gọi tên người dùng,');
      buf.writeln('đề xuất phù hợp trình độ, nhắc đến streak/tiến độ khi liên quan.');

      return buf.toString();
    } catch (_) {
      return '';
    }
  }

  // ── Gửi tin nhắn văn bản ──────────────────────────────
  static Future<MeowResponse> askMeow(String userMessage) async {
    // Rate limit: 20 requests/phút
    if (!SecurityService.checkRateLimit(
        key: 'ai_chat', maxRequests: 20, windowSeconds: 60)) {
      final wait = SecurityService.rateLimitCooldown(
          key: 'ai_chat', windowSeconds: 60);
      return MeowResponse(
        text: 'Meow~ 😿 Bạn nhắn quá nhanh! Chờ $wait giây rồi thử lại nhé.',
      );
    }
    // Sanitize input
    final sanitized = SecurityService.sanitizeText(userMessage, maxLength: 2000);
    return _sendMessage(sanitized, imageBase64: null);
  }

  // ── Gửi tin nhắn kèm hình ảnh ─────────────────────────
  static Future<MeowResponse> askMeowWithImage(
    String userMessage,
    File imageFile,
  ) async {
    // Rate limit: 5 requests/phút cho vision (tốn token hơn)
    if (!SecurityService.checkRateLimit(
        key: 'ai_vision', maxRequests: 5, windowSeconds: 60)) {
      return MeowResponse(
        text: 'Meow~ 😿 Gửi ảnh quá nhiều! Chờ 1 phút rồi thử lại nhé.',
      );
    }
    try {
      final bytes = await imageFile.readAsBytes();
      final base64Image = base64Encode(bytes);
      final ext = imageFile.path.split('.').last.toLowerCase();
      final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';
      return _sendMessage(
        userMessage.isEmpty ? 'Hãy mô tả nội dung hình ảnh này và nếu có lịch/sự kiện, hãy thêm vào calendar cho tôi.' : userMessage,
        imageBase64: base64Image,
        mimeType: mimeType,
      );
    } catch (e) {
      return MeowResponse(
        text: 'Meow~ 😿 Không đọc được ảnh: $e',
      );
    }
  }

  // ── Core: gửi message (có hoặc không có ảnh) ──────────
  static Future<MeowResponse> _sendMessage(
    String userMessage, {
    String? imageBase64,
    String mimeType = 'image/jpeg',
  }) async {
    try {
      final history = await loadHistory();
      final now      = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));
      final fmt      = (DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      // Lấy context người dùng để cá nhân hóa
      final userContextBlock = await _buildUserContextBlock();

      final dynamicPrompt = (_systemPrompt + (userContextBlock.isNotEmpty ? '\n$userContextBlock' : ''))
          .replaceAll('{{TODAY}}',    fmt(now))
          .replaceAll('{{TOMORROW}}', fmt(tomorrow));

      // Xây dựng content cho user message
      final dynamic userContent = imageBase64 != null
          ? [
              {
                'type': 'text',
                'text': userMessage,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mimeType;base64,$imageBase64',
                },
              },
            ]
          : userMessage;

      final messages = [
        {'role': 'system', 'content': dynamicPrompt},
        ...history.map((m) => {
              'role': m['role'] == 'ai' ? 'assistant' : 'user',
              'content': m['content'],
            }),
        {'role': 'user', 'content': userContent},
      ];

      final model = imageBase64 != null ? _visionModel : _model;

      final res = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model':       model,
              'messages':    messages,
              'max_tokens':  2048,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (res.statusCode == 200) {
        final data  = jsonDecode(res.body);
        final reply = data['choices'][0]['message']['content'] as String;

        // Parse calendar event
        final event = _parseCalendarEvent(reply);
        // Parse study plan
        final studyPlan = _parseStudyPlan(reply);
        // Clean reply — xóa tất cả block lệnh trước khi lưu và hiển thị
        final cleanReply = _removeAllBlocks(reply);

        // Lưu lịch sử với bản đã clean (không lưu block JSON vào history)
        await _saveMessage('user', userMessage);
        await _saveMessage('ai', cleanReply);

        return MeowResponse(
          text: cleanReply,
          calendarEvent: event,
          studyPlan: studyPlan,
        );
      } else if (res.statusCode == 401) {
        return MeowResponse(
          text: 'Meow~ 😿 API key chưa được cấu hình. Vào console.groq.com lấy key miễn phí nhé!',
        );
      } else if (res.statusCode == 429) {
        return MeowResponse(
          text: 'Meow~ 😿 Đang bận quá, thử lại sau 1 phút nhé! (Rate limit tạm thời)',
        );
      } else {
        final err = jsonDecode(utf8.decode(res.bodyBytes));
        return MeowResponse(
          text: 'Meow~ 😿 Lỗi ${res.statusCode}: ${err['error']?['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      return MeowResponse(
        text: 'Meow không kết nối được 😿 Kiểm tra internet nhé! ($e)',
      );
    }
  }

  // ── Parse calendar event ───────────────────────────────
  static CalendarEventData? _parseCalendarEvent(String text) {
    try {
      final start = text.indexOf('[CALENDAR_EVENT]');
      final end   = text.indexOf('[/CALENDAR_EVENT]');
      if (start == -1 || end == -1) return null;

      final jsonStr = text.substring(start + 16, end).trim();
      final map     = jsonDecode(jsonStr) as Map<String, dynamic>;

      return _mapToCalendarEvent(map);
    } catch (_) {
      return null;
    }
  }

  // ── Parse study plan ───────────────────────────────────
  static StudyPlanData? _parseStudyPlan(String text) {
    try {
      final start = text.indexOf('[STUDY_PLAN]');
      final end   = text.indexOf('[/STUDY_PLAN]');
      if (start == -1 || end == -1) return null;

      final jsonStr = text.substring(start + 12, end).trim();
      final map     = jsonDecode(jsonStr) as Map<String, dynamic>;

      final milestones = (map['milestones'] as List<dynamic>? ?? [])
          .map((m) => StudyMilestoneData(
                title: m['title'] ?? '',
                description: m['description'] ?? '',
                dueDate: _parseDate(m['dueDate'] ?? ''),
                tasks: List<String>.from(m['tasks'] ?? []),
              ))
          .toList();

      final calendarEvents = (map['calendarEvents'] as List<dynamic>? ?? [])
          .map((e) => _mapToCalendarEvent(e))
          .whereType<CalendarEventData>()
          .toList();

      return StudyPlanData(
        title: map['title'] ?? 'Kế hoạch học tiếng Anh',
        description: map['description'] ?? '',
        targetLevel: map['targetLevel'] ?? 'B2',
        hoursPerWeek: map['hoursPerWeek'] ?? 5,
        milestones: milestones,
        calendarEvents: calendarEvents,
      );
    } catch (_) {
      return null;
    }
  }

  static CalendarEventData? _mapToCalendarEvent(Map<String, dynamic> map) {
    try {
      final date = _parseDate(map['date'] as String? ?? '');
      TimeComponents time;
      try {
        final parts = (map['time'] as String).split(':');
        time = TimeComponents(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      } catch (_) {
        time = TimeComponents(hour: 8, minute: 0);
      }
      return CalendarEventData(
        title:       map['title']       as String? ?? 'Sự kiện',
        description: map['description'] as String? ?? '',
        date:        date,
        time:        time,
      );
    } catch (_) {
      return null;
    }
  }

  static DateTime _parseDate(String dateStr) {
    final s = dateStr.trim().toLowerCase();
    try {
      return DateTime.parse(s);
    } catch (_) {
      final now = DateTime.now();
      if (s.contains('mai') || s.contains('tomorrow')) {
        return now.add(const Duration(days: 1));
      } else if (s.contains('tuần sau') || s.contains('next week')) {
        return now.add(const Duration(days: 7));
      }
      return now;
    }
  }

  static String _removeAllBlocks(String text) {
    var result = text;

    // Xóa tất cả block [TAG]...[/TAG] bằng regex (kể cả block nằm giữa text)
    // Dùng DOTALL để match newline bên trong block
    final blockPattern = RegExp(
      r'\[(?:CALENDAR_EVENT|STUDY_PLAN|CALENDAR_EVENTS?|STUDY_PLANS?)\].*?\[/(?:CALENDAR_EVENT|STUDY_PLAN|CALENDAR_EVENTS?|STUDY_PLANS?)\]',
      dotAll: true,
      caseSensitive: false,
    );
    result = result.replaceAll(blockPattern, '');

    // Xóa các dòng chỉ chứa JSON thuần (đề phòng model không wrap trong tag)
    // Ví dụ: model trả về ```json ... ``` hoặc { ... } standalone
    final jsonCodeBlock = RegExp(
      r'```(?:json)?\s*\{.*?\}\s*```',
      dotAll: true,
      caseSensitive: false,
    );
    result = result.replaceAll(jsonCodeBlock, '');

    // Xóa các dòng trống thừa (nhiều hơn 2 dòng trống liên tiếp)
    result = result.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return result.trim();
  }

  // ── Lưu sự kiện vào Firestore ─────────────────────────
  static Future<bool> saveEventToCalendar(CalendarEventData event) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      final timeStr =
          '${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';

      await FirebaseFirestore.instance.collection('events').add({
        'uid':         uid,
        'title':       event.title,
        'description': event.description,
        'date':        Timestamp.fromDate(event.date),
        'time':        timeStr,
        'createdAt':   FieldValue.serverTimestamp(),
        'completed':   false,
        'source':      'meow_ai',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Lưu nhiều sự kiện cùng lúc (dùng cho study plan)
  static Future<int> saveMultipleEventsToCalendar(
    List<CalendarEventData> events,
  ) async {
    int saved = 0;
    for (final event in events) {
      final ok = await saveEventToCalendar(event);
      if (ok) saved++;
    }
    return saved;
  }

  /// Kiểm tra xung đột lịch
  static Future<List<Map<String, dynamic>>> checkConflicts(
    CalendarEventData newEvent,
  ) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return [];

      final startOfDay = DateTime(
        newEvent.date.year,
        newEvent.date.month,
        newEvent.date.day,
      );
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final snap = await FirebaseFirestore.instance
          .collection('events')
          .where('uid', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThan: Timestamp.fromDate(endOfDay))
          .get();

      final newStart = newEvent.time.hour * 60 + newEvent.time.minute;
      final conflicts = <Map<String, dynamic>>[];

      for (final doc in snap.docs) {
        final data = doc.data();
        final timeStr = data['time'] as String? ?? '00:00';
        final parts = timeStr.split(':');
        final existStart = int.parse(parts[0]) * 60 + int.parse(parts[1]);

        // Coi mỗi sự kiện kéo dài 60 phút
        if ((newStart - existStart).abs() < 60) {
          conflicts.add({...data, 'id': doc.id});
        }
      }
      return conflicts;
    } catch (_) {
      return [];
    }
  }

  /// Lùi thời gian sự kiện trong Firestore
  static Future<bool> rescheduleEvent(
    String eventId,
    DateTime newDate,
    TimeComponents newTime,
  ) async {
    try {
      final timeStr =
          '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
      await FirebaseFirestore.instance.collection('events').doc(eventId).update({
        'date': Timestamp.fromDate(newDate),
        'time': timeStr,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Xóa sự kiện
  static Future<bool> deleteEvent(String eventId) async {
    try {
      await FirebaseFirestore.instance.collection('events').doc(eventId).delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Lưu kế hoạch học vào Firestore ────────────────────
  static Future<bool> saveStudyPlan(StudyPlanData plan) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return false;

      await FirebaseFirestore.instance.collection('study_plans').add({
        'uid': uid,
        'title': plan.title,
        'description': plan.description,
        'targetLevel': plan.targetLevel,
        'hoursPerWeek': plan.hoursPerWeek,
        'milestones': plan.milestones
            .map((m) => {
                  'title': m.title,
                  'description': m.description,
                  'dueDate': Timestamp.fromDate(m.dueDate),
                  'tasks': m.tasks,
                  'isCompleted': false,
                })
            .toList(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Lấy thông tin người dùng để cá nhân hóa (legacy helper) ──
  static Future<Map<String, dynamic>> getUserContext() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return {};
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      return doc.data() ?? {};
    } catch (_) {
      return {};
    }
  }

  // ── Lịch sử chat ──────────────────────────────────────
  static Future<void> _saveMessage(String role, String content) async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_historyKey) ?? '[]';
    final list  = jsonDecode(raw) as List;
    list.add({'role': role, 'content': content});
    final trimmed = list.length > 40 ? list.sublist(list.length - 40) : list;
    await prefs.setString(_historyKey, jsonEncode(trimmed));
  }

  static Future<List<Map<String, String>>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_historyKey) ?? '[]';
    final list  = jsonDecode(raw) as List;
    return list
        .map((e) => {
              'role':    e['role']    as String,
              'content': e['content'] as String,
            })
        .toList();
  }

  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }

  // ── Translate Vietnamese → English ────────────────────
  /// Dịch câu tiếng Việt sang tiếng Anh.
  /// Trả về null nếu text không phải tiếng Việt hoặc quá ngắn.
  static Future<TranslateResult?> translateViToEn(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.split(' ').length < 2) return null;

    try {
      final res = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content': '''
Bạn là trợ lý dịch thuật chuyên nghiệp.
Nhiệm vụ: Dịch câu tiếng Việt sang tiếng Anh tự nhiên, chuẩn xác.

QUY TẮC:
1. Nếu text KHÔNG PHẢI tiếng Việt → trả lời: {"isVietnamese": false}
2. Nếu là tiếng Việt → trả lời JSON:
   {"isVietnamese": true, "translation": "bản dịch tiếng Anh", "note": "ghi chú ngắn nếu có (tùy chọn)"}
3. Dịch tự nhiên như người bản ngữ, không dịch từng từ
4. KHÔNG thêm bất kỳ text nào ngoài JSON
''',
                },
                {
                  'role': 'user',
                  'content': 'Dịch câu này: "$trimmed"',
                },
              ],
              'max_tokens': 200,
              'temperature': 0.2,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      final reply = (data['choices'][0]['message']['content'] as String).trim();

      final jsonStart = reply.indexOf('{');
      final jsonEnd   = reply.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final parsed = jsonDecode(reply.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
      if (parsed['isVietnamese'] != true) return null;

      final translation = parsed['translation'] as String?;
      if (translation == null || translation.trim().isEmpty) return null;

      return TranslateResult(
        original:    trimmed,
        translation: translation.trim(),
        note:        parsed['note'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  // ── Pronunciation Assessment ──────────────────────────
  /// Đánh giá phát âm: so sánh từ người dùng nói với từ gốc.
  /// [spokenText] là kết quả STT, [targetWord] là từ cần phát âm.
  /// Trả về [PronunciationResult] với score 0-100 và nhận xét của Meow.
  static Future<PronunciationResult> assessPronunciation({
    required String spokenText,
    required String targetWord,
    required String phonetic,
  }) async {
    final spoken = spokenText.trim().toLowerCase();
    final target = targetWord.trim().toLowerCase();

    // Tính similarity score cơ bản trước (fallback nếu AI lỗi)
    final baseScore = _computeSimilarity(spoken, target);

    try {
      final res = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content': '''
Bạn là Meow 😺 — chuyên gia đánh giá phát âm tiếng Anh thân thiện.
Nhiệm vụ: So sánh từ người dùng nói với từ gốc và đưa ra đánh giá.

QUY TẮC:
1. Phân tích sự tương đồng âm thanh giữa từ nói và từ gốc
2. Tính điểm từ 0-100 dựa trên độ chính xác phát âm
3. Đưa ra nhận xét ngắn gọn, động viên bằng tiếng Việt (tối đa 1 câu)
4. Trả lời ĐÚNG định dạng JSON sau, KHÔNG thêm text nào khác:
{"score": 85, "comment": "Gần đúng rồi! Chú ý âm cuối nhé 😺", "tip": "Thử phát âm rõ hơn phần '-tion'"}

Thang điểm:
- 90-100: Xuất sắc 🌟
- 75-89: Tốt 👍
- 55-74: Khá 😊
- 30-54: Cần luyện thêm 💪
- 0-29: Thử lại nhé 🐱
''',
                },
                {
                  'role': 'user',
                  'content':
                      'Từ gốc: "$targetWord" (phiên âm: $phonetic)\nNgười dùng nói: "$spokenText"\nHãy đánh giá phát âm.',
                },
              ],
              'max_tokens': 150,
              'temperature': 0.3,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply =
            (data['choices'][0]['message']['content'] as String).trim();

        final jsonStart = reply.indexOf('{');
        final jsonEnd = reply.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final parsed = jsonDecode(reply.substring(jsonStart, jsonEnd + 1))
              as Map<String, dynamic>;
          final score = ((parsed['score'] ?? baseScore) as num).toInt().clamp(0, 100);
          return PronunciationResult(
            score: score,
            comment: parsed['comment'] as String? ?? _defaultComment(score),
            tip: parsed['tip'] as String? ?? '',
            spokenText: spokenText,
            targetWord: targetWord,
          );
        }
      }
    } catch (_) {}

    // Fallback: dùng similarity score
    return PronunciationResult(
      score: baseScore,
      comment: _defaultComment(baseScore),
      tip: '',
      spokenText: spokenText,
      targetWord: targetWord,
    );
  }

  /// Tính độ tương đồng chuỗi đơn giản (Levenshtein-based, 0-100)
  static int _computeSimilarity(String a, String b) {
    if (a == b) return 100;
    if (a.isEmpty || b.isEmpty) return 0;

    // Normalize: chỉ lấy từ đầu tiên nếu STT trả về nhiều từ
    final aWord = a.split(' ').first;
    final bWord = b.split(' ').first;

    final maxLen = aWord.length > bWord.length ? aWord.length : bWord.length;
    final dist = _levenshtein(aWord, bWord);
    final similarity = ((1 - dist / maxLen) * 100).round().clamp(0, 100);
    return similarity;
  }

  static int _levenshtein(String s, String t) {
    final m = s.length, n = t.length;
    final dp = List.generate(m + 1, (i) => List.filled(n + 1, 0));
    for (int i = 0; i <= m; i++) dp[i][0] = i;
    for (int j = 0; j <= n; j++) dp[0][j] = j;
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        dp[i][j] = s[i - 1] == t[j - 1]
            ? dp[i - 1][j - 1]
            : 1 + [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                .reduce((a, b) => a < b ? a : b);
      }
    }
    return dp[m][n];
  }

  static String _defaultComment(int score) {
    if (score >= 90) return 'Xuất sắc! Phát âm chuẩn lắm 🌟';
    if (score >= 75) return 'Tốt lắm! Tiếp tục luyện tập nhé 👍';
    if (score >= 55) return 'Khá rồi! Cố gắng thêm chút nữa 😊';
    if (score >= 30) return 'Cần luyện thêm, đừng nản nhé 💪';
    return 'Thử lại nhé, Meow tin bạn làm được 🐱';
  }

  // ── Grammar Correction ────────────────────────────────
  /// Kiểm tra và sửa grammar câu tiếng Anh.
  /// Trả về câu đã sửa nếu có lỗi, null nếu câu đúng hoặc không phải tiếng Anh.
  static Future<GrammarResult?> correctGrammar(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || trimmed.split(' ').length < 2) return null;

    try {
      final res = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content': '''
Bạn là trợ lý sửa lỗi ngữ pháp tiếng Anh.
Nhiệm vụ: Phân tích câu tiếng Anh người dùng nhập và sửa lỗi ngữ pháp nếu có.

QUY TẮC:
1. Nếu câu ĐÃ ĐÚNG hoặc KHÔNG PHẢI tiếng Anh → trả lời: {"correct": true}
2. Nếu có lỗi grammar → trả lời JSON:
   {"correct": false, "corrected": "câu đã sửa", "explanation": "giải thích ngắn bằng tiếng Việt"}
3. CHỈ sửa lỗi ngữ pháp, KHÔNG thay đổi ý nghĩa
4. KHÔNG thêm bất kỳ text nào ngoài JSON
''',
                },
                {
                  'role': 'user',
                  'content': 'Kiểm tra câu này: "$trimmed"',
                },
              ],
              'max_tokens': 200,
              'temperature': 0.1,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      final reply = (data['choices'][0]['message']['content'] as String).trim();

      // Extract JSON từ reply (đề phòng model thêm text thừa)
      final jsonStart = reply.indexOf('{');
      final jsonEnd   = reply.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final parsed = jsonDecode(reply.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
      if (parsed['correct'] == true) return null;

      final corrected   = parsed['corrected']   as String?;
      final explanation = parsed['explanation'] as String?;
      if (corrected == null || corrected.trim().isEmpty) return null;
      if (corrected.trim() == trimmed) return null;

      return GrammarResult(
        original:    trimmed,
        corrected:   corrected.trim(),
        explanation: explanation ?? '',
      );
    } catch (_) {
      return null; // Lỗi mạng / timeout → im lặng, không làm phiền user
    }
  }

  // ── Generate Example Sentence ─────────────────────────
  /// Tạo câu ví dụ cho từ vựng bằng AI.
  /// Trả về [ExampleResult] gồm câu tiếng Anh và dịch tiếng Việt.
  static Future<ExampleResult?> generateExample({
    required String word,
    required String meaning,
    String? phonetic,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': [
                {
                  'role': 'system',
                  'content': '''
Bạn là trợ lý tạo câu ví dụ tiếng Anh cho học sinh Việt Nam.
Nhiệm vụ: Tạo 1 câu ví dụ tự nhiên, đơn giản, dễ hiểu cho từ vựng được cung cấp.

QUY TẮC:
1. Câu ví dụ phải dùng đúng từ đó (không biến thể quá phức tạp)
2. Độ dài: 8-15 từ, phù hợp trình độ B1-B2
3. Nội dung tích cực, gần gũi cuộc sống hàng ngày
4. Trả lời ĐÚNG định dạng JSON sau, KHÔNG thêm text nào khác:
{"en": "câu tiếng Anh", "vi": "dịch tiếng Việt"}
''',
                },
                {
                  'role': 'user',
                  'content': 'Tạo câu ví dụ cho từ: "$word" (nghĩa: $meaning)',
                },
              ],
              'max_tokens': 150,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return null;

      final data = jsonDecode(res.body);
      final reply = (data['choices'][0]['message']['content'] as String).trim();

      final jsonStart = reply.indexOf('{');
      final jsonEnd   = reply.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) return null;

      final parsed = jsonDecode(reply.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
      final en = parsed['en'] as String?;
      final vi = parsed['vi'] as String?;
      if (en == null || en.trim().isEmpty) return null;

      return ExampleResult(en: en.trim(), vi: vi?.trim() ?? '');
    } catch (_) {
      return null;
    }
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class MeowResponse {
  final String text;
  final CalendarEventData? calendarEvent;
  final StudyPlanData? studyPlan;
  const MeowResponse({
    required this.text,
    this.calendarEvent,
    this.studyPlan,
  });
}

class CalendarEventData {
  final String         title;
  final String         description;
  final DateTime       date;
  final TimeComponents time;
  const CalendarEventData({
    required this.title,
    required this.description,
    required this.date,
    required this.time,
  });
}

class TimeComponents {
  final int hour;
  final int minute;
  const TimeComponents({required this.hour, required this.minute});
  @override
  String toString() =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

class StudyPlanData {
  final String title;
  final String description;
  final String targetLevel;
  final int hoursPerWeek;
  final List<StudyMilestoneData> milestones;
  final List<CalendarEventData> calendarEvents;

  const StudyPlanData({
    required this.title,
    required this.description,
    required this.targetLevel,
    required this.hoursPerWeek,
    required this.milestones,
    required this.calendarEvents,
  });
}

class StudyMilestoneData {
  final String title;
  final String description;
  final DateTime dueDate;
  final List<String> tasks;

  const StudyMilestoneData({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.tasks,
  });
}

/// Kết quả kiểm tra grammar
class GrammarResult {
  final String original;    // Câu gốc
  final String corrected;   // Câu đã sửa
  final String explanation; // Giải thích bằng tiếng Việt

  const GrammarResult({
    required this.original,
    required this.corrected,
    required this.explanation,
  });
}

/// Kết quả dịch Việt → Anh
class TranslateResult {
  final String original;    // Câu tiếng Việt gốc
  final String translation; // Bản dịch tiếng Anh
  final String note;        // Ghi chú thêm (tùy chọn)

  const TranslateResult({
    required this.original,
    required this.translation,
    required this.note,
  });
}

/// Kết quả đánh giá phát âm
class PronunciationResult {
  final int score;        // 0-100
  final String comment;   // Nhận xét của Meow (tiếng Việt)
  final String tip;       // Gợi ý cải thiện
  final String spokenText;  // Từ người dùng nói
  final String targetWord;  // Từ gốc cần phát âm

  const PronunciationResult({
    required this.score,
    required this.comment,
    required this.tip,
    required this.spokenText,
    required this.targetWord,
  });

  /// Màu sắc theo điểm
  Color get scoreColor {
    if (score >= 90) return const Color(0xFF06D6A0);
    if (score >= 75) return const Color(0xFF4CAF50);
    if (score >= 55) return const Color(0xFFFFB347);
    if (score >= 30) return const Color(0xFFFF8C69);
    return const Color(0xFFFF4757);
  }

  /// Emoji theo điểm
  String get scoreEmoji {
    if (score >= 90) return '🌟';
    if (score >= 75) return '👍';
    if (score >= 55) return '😊';
    if (score >= 30) return '💪';
    return '🐱';
  }
}

/// Kết quả tạo câu ví dụ bằng AI
class ExampleResult {
  final String en; // Câu tiếng Anh
  final String vi; // Dịch tiếng Việt

  const ExampleResult({required this.en, required this.vi});
}
