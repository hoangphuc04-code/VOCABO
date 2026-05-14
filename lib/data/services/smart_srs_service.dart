import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'srs_service.dart';
import '../../../core/config/app_secrets.dart';

/// 🧠 Tính năng 3: Smart SRS với AI
/// Phân tích pattern sai → tự điều chỉnh interval → gợi ý "bạn hay nhầm từ này với từ kia"
class SmartSrsService {
  static String get _apiKey => AppSecrets.groqApiKey;
  static const _model = 'llama-3.3-70b-versatile';
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Ghi nhận lỗi sai ─────────────────────────────────
  static Future<void> recordMistake({
    required String wordId,
    required String word,
    required String meaning,
    required String wrongAnswer,
    required String correctAnswer,
  }) async {
    if (_uid.isEmpty) return;
    await _db.collection('srs_mistakes').add({
      'uid': _uid,
      'wordId': wordId,
      'word': word,
      'meaning': meaning,
      'wrongAnswer': wrongAnswer,
      'correctAnswer': correctAnswer,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── Phân tích pattern sai và gợi ý ───────────────────
  static Future<SrsInsight?> analyzeWeakWords() async {
    if (_uid.isEmpty) return null;
    try {
      // Lấy 30 lỗi gần nhất
      final snap = await _db
          .collection('srs_mistakes')
          .where('uid', isEqualTo: _uid)
          .orderBy('timestamp', descending: true)
          .limit(30)
          .get();

      if (snap.docs.isEmpty) return null;

      final mistakes = snap.docs.map((d) => d.data()).toList();
      final mistakeText = mistakes
          .map((m) =>
              '- Từ: "${m['word']}" (${m['meaning']}) → Sai: "${m['wrongAnswer']}"')
          .join('\n');

      final res = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
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
Bạn là chuyên gia phân tích học tiếng Anh.
Phân tích danh sách lỗi sai của học viên và đưa ra nhận xét.

Trả lời JSON:
{
  "weakWords": ["word1", "word2", "word3"],
  "confusedPairs": [
    {"word1": "affect", "word2": "effect", "reason": "Cả hai đều liên quan đến tác động"}
  ],
  "pattern": "Mô tả pattern lỗi chính bằng tiếng Việt (1-2 câu)",
  "tip": "Lời khuyên cụ thể để cải thiện bằng tiếng Việt (1-2 câu)"
}
''',
                },
                {
                  'role': 'user',
                  'content': 'Phân tích lỗi sai:\n$mistakeText',
                },
              ],
              'max_tokens': 400,
              'temperature': 0.3,
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply =
            (data['choices'][0]['message']['content'] as String).trim();
        final jsonStart = reply.indexOf('{');
        final jsonEnd = reply.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final parsed =
              jsonDecode(reply.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
          return SrsInsight.fromMap(parsed);
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Điều chỉnh interval dựa trên AI insight ──────────
  static Future<void> adjustIntervalForWeakWords(
      List<String> weakWords) async {
    if (_uid.isEmpty || weakWords.isEmpty) return;
    final batch = _db.batch();
    for (final word in weakWords) {
      final snap = await _db
          .collection('vocabulary_progress')
          .where('uid', isEqualTo: _uid)
          .where('word', isEqualTo: word)
          .limit(1)
          .get();
      for (final doc in snap.docs) {
        // Reset interval về 1 ngày để ôn lại sớm hơn
        batch.update(doc.reference, {
          'interval': 1,
          'nextReview': Timestamp.fromDate(DateTime.now()),
          'easeFactor': 2.0, // Giảm ease factor
        });
      }
    }
    await batch.commit();
  }

  // ── Lấy thống kê tổng quan ────────────────────────────
  static Future<SrsStats> getStats() async {
    if (_uid.isEmpty) return SrsStats.empty;
    try {
      final allSnap = await _db
          .collection('vocabulary_progress')
          .where('uid', isEqualTo: _uid)
          .get();

      final now = DateTime.now();
      int mastered = 0, learning = 0, newWords = 0, dueToday = 0;

      for (final doc in allSnap.docs) {
        final d = doc.data();
        final strength = (d['strength'] as num? ?? 0).toDouble();
        final nextReview = d['nextReview'] != null
            ? (d['nextReview'] as Timestamp).toDate()
            : now;

        if (strength >= 0.8) mastered++;
        else if (strength >= 0.4) learning++;
        else newWords++;

        if (nextReview.isBefore(now)) dueToday++;
      }

      return SrsStats(
        total: allSnap.docs.length,
        mastered: mastered,
        learning: learning,
        newWords: newWords,
        dueToday: dueToday,
      );
    } catch (_) {
      return SrsStats.empty;
    }
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class SrsInsight {
  final List<String> weakWords;
  final List<ConfusedPair> confusedPairs;
  final String pattern;
  final String tip;

  const SrsInsight({
    required this.weakWords,
    required this.confusedPairs,
    required this.pattern,
    required this.tip,
  });

  factory SrsInsight.fromMap(Map<String, dynamic> m) {
    final pairs = (m['confusedPairs'] as List? ?? [])
        .map((p) => ConfusedPair(
              word1: p['word1'] as String? ?? '',
              word2: p['word2'] as String? ?? '',
              reason: p['reason'] as String? ?? '',
            ))
        .toList();
    return SrsInsight(
      weakWords: List<String>.from(m['weakWords'] ?? []),
      confusedPairs: pairs,
      pattern: m['pattern'] as String? ?? '',
      tip: m['tip'] as String? ?? '',
    );
  }
}

class ConfusedPair {
  final String word1, word2, reason;
  const ConfusedPair({
    required this.word1,
    required this.word2,
    required this.reason,
  });
}

class SrsStats {
  final int total, mastered, learning, newWords, dueToday;

  const SrsStats({
    required this.total,
    required this.mastered,
    required this.learning,
    required this.newWords,
    required this.dueToday,
  });

  static const empty = SrsStats(
    total: 0,
    mastered: 0,
    learning: 0,
    newWords: 0,
    dueToday: 0,
  );
}
