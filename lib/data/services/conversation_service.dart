import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/config/app_secrets.dart';

/// ConversationService — AI Conversation Practice
/// Dùng Groq API (cùng key với MeowAI)
class ConversationService {
  static String get _apiKey => AppSecrets.groqApiKey;
  static const _model = 'llama-3.3-70b-versatile';
  static const _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  // ── Danh sách scenarios ───────────────────────────────
  static const List<ConversationScenario> scenarios = [
    ConversationScenario(
      id: 'airport',
      title: 'Tại sân bay',
      titleEn: 'At the Airport',
      emoji: '✈️',
      description: 'Làm thủ tục check-in, hỏi đường, mua đồ',
      color: 0xFF4A90D9,
      aiRole: 'airport staff',
      aiRoleVi: 'nhân viên sân bay',
      difficulty: 'Beginner',
      targetVocab: ['boarding pass', 'departure', 'gate', 'luggage', 'customs'],
    ),
    ConversationScenario(
      id: 'restaurant',
      title: 'Đặt đồ ăn',
      titleEn: 'At a Restaurant',
      emoji: '🍽️',
      description: 'Gọi món, hỏi menu, thanh toán',
      color: 0xFFFF8C69,
      aiRole: 'waiter',
      aiRoleVi: 'nhân viên phục vụ',
      difficulty: 'Beginner',
      targetVocab: ['menu', 'order', 'recommend', 'bill', 'reservation'],
    ),
    ConversationScenario(
      id: 'job_interview',
      title: 'Phỏng vấn xin việc',
      titleEn: 'Job Interview',
      emoji: '💼',
      description: 'Giới thiệu bản thân, trả lời câu hỏi HR',
      color: 0xFF667eea,
      aiRole: 'HR interviewer',
      aiRoleVi: 'nhà tuyển dụng',
      difficulty: 'Intermediate',
      targetVocab: ['experience', 'qualification', 'strength', 'weakness', 'salary'],
    ),
    ConversationScenario(
      id: 'hotel',
      title: 'Đặt phòng khách sạn',
      titleEn: 'Hotel Check-in',
      emoji: '🏨',
      description: 'Check-in, yêu cầu dịch vụ, giải quyết vấn đề',
      color: 0xFF06D6A0,
      aiRole: 'hotel receptionist',
      aiRoleVi: 'lễ tân khách sạn',
      difficulty: 'Beginner',
      targetVocab: ['reservation', 'room service', 'checkout', 'amenities', 'complaint'],
    ),
    ConversationScenario(
      id: 'doctor',
      title: 'Khám bệnh',
      titleEn: 'Doctor Visit',
      emoji: '🏥',
      description: 'Mô tả triệu chứng, hỏi về thuốc',
      color: 0xFFE91E8C,
      aiRole: 'doctor',
      aiRoleVi: 'bác sĩ',
      difficulty: 'Intermediate',
      targetVocab: ['symptom', 'prescription', 'diagnosis', 'treatment', 'allergy'],
    ),
    ConversationScenario(
      id: 'shopping',
      title: 'Mua sắm',
      titleEn: 'Shopping',
      emoji: '🛍️',
      description: 'Hỏi giá, thử đồ, mặc cả',
      color: 0xFFFFBE0B,
      aiRole: 'shop assistant',
      aiRoleVi: 'nhân viên bán hàng',
      difficulty: 'Beginner',
      targetVocab: ['discount', 'size', 'exchange', 'receipt', 'fitting room'],
    ),
  ];

  // ── Bắt đầu hội thoại mới ─────────────────────────────
  static Future<ConversationTurn> startConversation(
      ConversationScenario scenario) async {
    final systemPrompt = _buildSystemPrompt(scenario);
    final openingPrompt =
        'Start the conversation as a ${scenario.aiRole}. '
        'Greet the customer/user naturally in English. '
        'Keep it short (1-2 sentences). Be friendly and natural.';

    return _sendMessage(
      systemPrompt: systemPrompt,
      history: [],
      userMessage: openingPrompt,
      isOpening: true,
    );
  }

  // ── Gửi tin nhắn trong hội thoại ─────────────────────
  static Future<ConversationTurn> sendMessage({
    required ConversationScenario scenario,
    required List<Map<String, String>> history,
    required String userMessage,
  }) async {
    final systemPrompt = _buildSystemPrompt(scenario);
    return _sendMessage(
      systemPrompt: systemPrompt,
      history: history,
      userMessage: userMessage,
      isOpening: false,
    );
  }

  // ── Đánh giá toàn bộ hội thoại ───────────────────────
  static Future<ConversationReport> evaluateConversation({
    required ConversationScenario scenario,
    required List<Map<String, String>> history,
  }) async {
    final userMessages = history
        .where((m) => m['role'] == 'user')
        .map((m) => m['content'] ?? '')
        .join('\n');

    if (userMessages.trim().isEmpty) {
      return ConversationReport(
        overallScore: 0,
        grammarScore: 0,
        vocabularyScore: 0,
        fluencyScore: 0,
        grammarFeedback: 'Chưa có dữ liệu',
        vocabularyFeedback: 'Chưa có dữ liệu',
        fluencyFeedback: 'Chưa có dữ liệu',
        suggestions: [],
        usedTargetVocab: [],
        missedVocab: scenario.targetVocab,
        summary: 'Bạn chưa nói gì trong buổi hội thoại này.',
      );
    }

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
You are an English conversation coach. Evaluate the student's English in a conversation.
Respond ONLY with valid JSON in this exact format:
{
  "overallScore": 75,
  "grammarScore": 70,
  "vocabularyScore": 80,
  "fluencyScore": 75,
  "grammarFeedback": "feedback in Vietnamese",
  "vocabularyFeedback": "feedback in Vietnamese",
  "fluencyFeedback": "feedback in Vietnamese",
  "suggestions": ["suggestion 1 in Vietnamese", "suggestion 2"],
  "usedTargetVocab": ["word1", "word2"],
  "summary": "overall summary in Vietnamese"
}
''',
                },
                {
                  'role': 'user',
                  'content': '''
Scenario: ${scenario.titleEn}
Target vocabulary: ${scenario.targetVocab.join(', ')}

Student's messages:
$userMessages

Please evaluate the student's English performance.
''',
                },
              ],
              'max_tokens': 600,
              'temperature': 0.3,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data['choices'][0]['message']['content'] as String;
        final jsonStart = reply.indexOf('{');
        final jsonEnd = reply.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final parsed =
              jsonDecode(reply.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
          final usedVocab = List<String>.from(parsed['usedTargetVocab'] ?? []);
          final missedVocab = scenario.targetVocab
              .where((v) => !usedVocab.contains(v))
              .toList();
          return ConversationReport(
            overallScore: (parsed['overallScore'] ?? 0).toInt(),
            grammarScore: (parsed['grammarScore'] ?? 0).toInt(),
            vocabularyScore: (parsed['vocabularyScore'] ?? 0).toInt(),
            fluencyScore: (parsed['fluencyScore'] ?? 0).toInt(),
            grammarFeedback: parsed['grammarFeedback'] ?? '',
            vocabularyFeedback: parsed['vocabularyFeedback'] ?? '',
            fluencyFeedback: parsed['fluencyFeedback'] ?? '',
            suggestions: List<String>.from(parsed['suggestions'] ?? []),
            usedTargetVocab: usedVocab,
            missedVocab: missedVocab,
            summary: parsed['summary'] ?? '',
          );
        }
      }
    } catch (_) {}

    return ConversationReport(
      overallScore: 60,
      grammarScore: 60,
      vocabularyScore: 60,
      fluencyScore: 60,
      grammarFeedback: 'Không thể đánh giá chi tiết',
      vocabularyFeedback: 'Không thể đánh giá chi tiết',
      fluencyFeedback: 'Không thể đánh giá chi tiết',
      suggestions: ['Hãy thử lại để nhận đánh giá chi tiết hơn'],
      usedTargetVocab: [],
      missedVocab: scenario.targetVocab,
      summary: 'Đã hoàn thành hội thoại.',
    );
  }

  // ── Core send ─────────────────────────────────────────
  static Future<ConversationTurn> _sendMessage({
    required String systemPrompt,
    required List<Map<String, String>> history,
    required String userMessage,
    required bool isOpening,
  }) async {
    try {
      final messages = [
        {'role': 'system', 'content': systemPrompt},
        ...history.map((m) => {'role': m['role']!, 'content': m['content']!}),
        if (!isOpening) {'role': 'user', 'content': userMessage},
        if (isOpening) {'role': 'user', 'content': userMessage},
      ];

      final res = await http
          .post(
            Uri.parse(_baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': _model,
              'messages': messages,
              'max_tokens': 300,
              'temperature': 0.7,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply = data['choices'][0]['message']['content'] as String;
        return ConversationTurn(text: reply.trim(), isError: false);
      }
      return ConversationTurn(
          text: 'Sorry, I could not respond. Please try again.',
          isError: true);
    } catch (e) {
      return ConversationTurn(
          text: 'Connection error. Please check your internet.',
          isError: true);
    }
  }

  static String _buildSystemPrompt(ConversationScenario scenario) {
    return '''
You are playing the role of a ${scenario.aiRole} in a "${scenario.titleEn}" scenario.
Rules:
1. ALWAYS respond in English only
2. Stay in character as a ${scenario.aiRole}
3. Keep responses SHORT (1-3 sentences max)
4. Be natural and conversational
5. Gently correct major grammar mistakes by using the correct form naturally in your response
6. Try to use these vocabulary words naturally: ${scenario.targetVocab.join(', ')}
7. If the user writes in Vietnamese, kindly ask them to try in English
8. Keep the conversation relevant to the scenario
''';
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class ConversationScenario {
  final String id;
  final String title;
  final String titleEn;
  final String emoji;
  final String description;
  final int color;
  final String aiRole;
  final String aiRoleVi;
  final String difficulty;
  final List<String> targetVocab;

  const ConversationScenario({
    required this.id,
    required this.title,
    required this.titleEn,
    required this.emoji,
    required this.description,
    required this.color,
    required this.aiRole,
    required this.aiRoleVi,
    required this.difficulty,
    required this.targetVocab,
  });
}

class ConversationTurn {
  final String text;
  final bool isError;
  const ConversationTurn({required this.text, required this.isError});
}

class ConversationReport {
  final int overallScore;
  final int grammarScore;
  final int vocabularyScore;
  final int fluencyScore;
  final String grammarFeedback;
  final String vocabularyFeedback;
  final String fluencyFeedback;
  final List<String> suggestions;
  final List<String> usedTargetVocab;
  final List<String> missedVocab;
  final String summary;

  const ConversationReport({
    required this.overallScore,
    required this.grammarScore,
    required this.vocabularyScore,
    required this.fluencyScore,
    required this.grammarFeedback,
    required this.vocabularyFeedback,
    required this.fluencyFeedback,
    required this.suggestions,
    required this.usedTargetVocab,
    required this.missedVocab,
    required this.summary,
  });
}
