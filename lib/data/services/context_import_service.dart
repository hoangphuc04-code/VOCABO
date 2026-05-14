import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_secrets.dart';

/// ContextImportService — Học từ vựng qua Lyrics / Text
/// Dùng Groq AI để extract từ vựng từ nội dung người dùng paste vào
class ContextImportService {
  static String get _apiKey => AppSecrets.groqApiKey;
  static const _model = 'llama-3.3-70b-versatile';
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Extract từ vựng từ text/lyrics ───────────────────
  static Future<ContextImportResult> extractVocabulary({
    required String content,
    required String sourceTitle,
    required ContextSourceType sourceType,
    int maxWords = 15,
  }) async {
    if (content.trim().isEmpty) {
      return ContextImportResult(
          words: [], sourceTitle: sourceTitle, sourceType: sourceType);
    }

    // Giới hạn content để tránh token quá lớn
    final trimmedContent =
        content.length > 3000 ? content.substring(0, 3000) : content;

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
You are a vocabulary extraction assistant for Vietnamese English learners.
Extract the $maxWords most useful/interesting English vocabulary words from the given text.

Rules:
1. Focus on intermediate-advanced vocabulary (not basic words like "the", "is", "a")
2. Include words that are useful for daily life or commonly tested
3. For each word, provide Vietnamese meaning and a simple example sentence
4. Respond ONLY with valid JSON array:
[
  {
    "word": "abandon",
    "phonetic": "/əˈbændən/",
    "meaning": "từ bỏ, bỏ rơi",
    "example": "He had to abandon his car in the snow.",
    "exampleVi": "Anh ấy phải bỏ xe lại trong tuyết.",
    "contextSentence": "the original sentence from the text containing this word"
  }
]
''',
                },
                {
                  'role': 'user',
                  'content':
                      'Extract vocabulary from this ${sourceType.name}:\n\n$trimmedContent',
                },
              ],
              'max_tokens': 2000,
              'temperature': 0.3,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data['choices'][0]['message']['content'] as String;
        final jsonStart = reply.indexOf('[');
        final jsonEnd = reply.lastIndexOf(']');
        if (jsonStart != -1 && jsonEnd != -1) {
          final list =
              jsonDecode(reply.substring(jsonStart, jsonEnd + 1)) as List;
          final words = list
              .map((item) => ContextWord.fromMap(
                    Map<String, dynamic>.from(item),
                    sourceTitle: sourceTitle,
                    sourceType: sourceType,
                  ))
              .toList();
          return ContextImportResult(
            words: words,
            sourceTitle: sourceTitle,
            sourceType: sourceType,
          );
        }
      }
    } catch (_) {}

    return ContextImportResult(
        words: [], sourceTitle: sourceTitle, sourceType: sourceType);
  }

  // ── Lưu từ vựng vào Firestore ─────────────────────────
  static Future<int> saveWordsToFirestore({
    required List<ContextWord> words,
    required String sourceTitle,
    required ContextSourceType sourceType,
  }) async {
    if (_uid.isEmpty || words.isEmpty) return 0;

    // Tạo topic mới cho nguồn này
    final topicRef = _db.collection('topics').doc();
    final emoji = sourceType == ContextSourceType.lyrics ? '🎵' : '📄';
    final colorHex = '#FF667eea';

    await topicRef.set({
      'uid': _uid,
      'name': sourceTitle,
      'nameVi': sourceTitle,
      'emoji': emoji,
      'color': colorHex,
      'wordCount': words.length,
      'isPreset': false,
      'sourceType': sourceType.name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Lưu từng từ vào subcollection words
    final batch = _db.batch();
    for (final word in words) {
      final wordRef = topicRef.collection('words').doc();
      batch.set(wordRef, {
        'word': word.word,
        'meaning': word.meaning,
        'phonetic': word.phonetic,
        'example': word.example,
        'exampleVi': word.exampleVi,
        'contextSentence': word.contextSentence,
        'sourceTitle': sourceTitle,
        'sourceType': sourceType.name,
        'imageUrl': '',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    return words.length;
  }

  // ── Fetch nội dung từ URL ─────────────────────────────
  /// Scrape text từ URL bài báo (dùng free API)
  static Future<UrlFetchResult> fetchFromUrl(String url) async {
    try {
      // Dùng Jina AI Reader (miễn phí, không cần key)
      final jinaUrl = 'https://r.jina.ai/$url';
      final res = await http.get(
        Uri.parse(jinaUrl),
        headers: {'Accept': 'text/plain'},
      ).timeout(const Duration(seconds: 15));

      if (res.statusCode == 200) {
        final text = res.body;
        // Lấy title từ dòng đầu
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final title = lines.isNotEmpty
            ? lines.first.replaceAll(RegExp(r'^#+ '), '').trim()
            : url;
        // Lấy nội dung (bỏ qua metadata đầu)
        final content = lines.skip(1).take(100).join('\n');
        return UrlFetchResult(
          title: title.length > 60 ? title.substring(0, 60) : title,
          content: content,
          success: true,
        );
      }
    } catch (_) {}
    return UrlFetchResult(title: '', content: '', success: false);
  }

  // ── Parse SRT subtitle ────────────────────────────────
  static String parseSrt(String srtContent) {
    // Xóa timestamp và số thứ tự, chỉ giữ text
    final lines = srtContent.split('\n');
    final textLines = <String>[];
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      if (RegExp(r'^\d+$').hasMatch(trimmed)) continue; // số thứ tự
      if (RegExp(r'\d{2}:\d{2}:\d{2}').hasMatch(trimmed)) continue; // timestamp
      if (trimmed.startsWith('<') && trimmed.endsWith('>')) continue; // HTML tags
      textLines.add(trimmed.replaceAll(RegExp(r'<[^>]+>'), ''));
    }
    return textLines.join(' ');
  }

  // ── Lấy danh sách context topics của user ─────────────
  static Future<List<ContextTopic>> getContextTopics() async {
    if (_uid.isEmpty) return [];
    final snap = await _db
        .collection('topics')
        .where('uid', isEqualTo: _uid)
        .where('sourceType', whereIn: ['lyrics', 'text', 'article'])
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return ContextTopic(
        id: doc.id,
        title: d['name'] ?? '',
        sourceType: ContextSourceType.values.firstWhere(
          (e) => e.name == (d['sourceType'] ?? 'text'),
          orElse: () => ContextSourceType.text,
        ),
        wordCount: (d['wordCount'] ?? 0).toInt(),
        emoji: d['emoji'] ?? '📄',
      );
    }).toList();
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

enum ContextSourceType { lyrics, text, article, url, srt }

class ContextWord {
  final String word;
  final String phonetic;
  final String meaning;
  final String example;
  final String exampleVi;
  final String contextSentence;
  final String sourceTitle;
  final ContextSourceType sourceType;
  bool isSelected;

  ContextWord({
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.example,
    required this.exampleVi,
    required this.contextSentence,
    required this.sourceTitle,
    required this.sourceType,
    this.isSelected = true,
  });

  factory ContextWord.fromMap(
    Map<String, dynamic> m, {
    required String sourceTitle,
    required ContextSourceType sourceType,
  }) =>
      ContextWord(
        word: m['word'] ?? '',
        phonetic: m['phonetic'] ?? '',
        meaning: m['meaning'] ?? '',
        example: m['example'] ?? '',
        exampleVi: m['exampleVi'] ?? '',
        contextSentence: m['contextSentence'] ?? '',
        sourceTitle: sourceTitle,
        sourceType: sourceType,
      );
}

class ContextImportResult {
  final List<ContextWord> words;
  final String sourceTitle;
  final ContextSourceType sourceType;
  const ContextImportResult({
    required this.words,
    required this.sourceTitle,
    required this.sourceType,
  });
}

class UrlFetchResult {
  final String title, content;
  final bool success;
  const UrlFetchResult({
    required this.title,
    required this.content,
    required this.success,
  });
}

class ContextTopic {
  final String id;
  final String title;
  final ContextSourceType sourceType;
  final int wordCount;
  final String emoji;
  const ContextTopic({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.wordCount,
    required this.emoji,
  });
}
