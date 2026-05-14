import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/app_secrets.dart';

/// 🤖 Tính năng 8: AI Conversation Partner
/// Meow AI đóng vai người bản ngữ, sửa lỗi ngữ pháp inline
class AIConversationScreen extends StatefulWidget {
  const AIConversationScreen({super.key});

  @override
  State<AIConversationScreen> createState() => _AIConversationScreenState();
}

class _AIConversationScreenState extends State<AIConversationScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  List<ConvMessage> _messages = [];
  bool _loading = false;
  ConversationScenario _scenario = ConversationScenario.freeChat;
  bool _scenarioPicked = false;

  static String get _apiKey => AppSecrets.groqApiKey;
  static const _model = 'llama-3.3-70b-versatile';

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _buildSystemPrompt() {
    final scenarioDesc = switch (_scenario) {
      ConversationScenario.restaurant => 'Bạn là nhân viên phục vụ tại nhà hàng Mỹ. Người dùng là khách hàng.',
      ConversationScenario.jobInterview => 'Bạn là nhà tuyển dụng đang phỏng vấn người dùng cho vị trí Software Engineer.',
      ConversationScenario.shopping => 'Bạn là nhân viên bán hàng tại cửa hàng thời trang. Người dùng muốn mua đồ.',
      ConversationScenario.travel => 'Bạn là nhân viên sân bay. Người dùng cần hỗ trợ về chuyến bay.',
      ConversationScenario.freeChat => 'Bạn là người bạn thân người Mỹ, nói chuyện tự nhiên về bất kỳ chủ đề nào.',
    };

    return '''
You are an English conversation partner. $scenarioDesc

RULES:
1. ALWAYS respond in English naturally (as a native speaker would)
2. After your response, add a correction section if the user made grammar mistakes:
   [CORRECTION]
   - Original: "user's sentence"
   - Better: "corrected version"
   - Why: brief explanation in Vietnamese
   [/CORRECTION]
3. If the user's English is perfect, do NOT add [CORRECTION]
4. Keep responses conversational and encouraging
5. Occasionally suggest better vocabulary with: 💡 Better word: "word" instead of "word"
6. Max 3-4 sentences per response to keep it natural
''';
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;

    setState(() {
      _messages.add(ConvMessage(
        isUser: true,
        text: text,
        original: text,
      ));
      _loading = true;
    });
    _ctrl.clear();
    _focus.requestFocus();
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => m.cleanText.isNotEmpty)
          .take(20)
          .map((m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.cleanText,
              })
          .toList();

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
                {'role': 'system', 'content': _buildSystemPrompt()},
                ...history,
              ],
              'max_tokens': 400,
              'temperature': 0.75,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply =
            (data['choices'][0]['message']['content'] as String).trim();

        // Parse correction
        final correction = _parseCorrection(reply);
        final cleanReply = _removeCorrection(reply);

        if (mounted) {
          setState(() {
            // Update last user message with correction if any
            if (correction != null && _messages.isNotEmpty) {
              final last = _messages.last;
              _messages[_messages.length - 1] = ConvMessage(
                isUser: true,
                text: last.text,
                original: last.original,
                correction: correction,
              );
            }
            _messages.add(ConvMessage(
              isUser: false,
              text: cleanReply,
              original: cleanReply,
            ));
            _loading = false;
          });
          _scrollToBottom();
          _saveSession();
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  GrammarCorrection? _parseCorrection(String text) {
    try {
      final start = text.indexOf('[CORRECTION]');
      final end = text.indexOf('[/CORRECTION]');
      if (start == -1 || end == -1) return null;
      final block = text.substring(start + 12, end).trim();
      final lines = block.split('\n').map((l) => l.trim()).toList();
      String original = '', better = '', why = '';
      for (final line in lines) {
        if (line.startsWith('- Original:')) {
          original = line.replaceFirst('- Original:', '').trim().replaceAll('"', '');
        } else if (line.startsWith('- Better:')) {
          better = line.replaceFirst('- Better:', '').trim().replaceAll('"', '');
        } else if (line.startsWith('- Why:')) {
          why = line.replaceFirst('- Why:', '').trim();
        }
      }
      if (better.isEmpty) return null;
      return GrammarCorrection(original: original, better: better, why: why);
    } catch (_) {
      return null;
    }
  }

  String _removeCorrection(String text) {
    return text
        .replaceAll(
            RegExp(r'\[CORRECTION\].*?\[/CORRECTION\]', dotAll: true), '')
        .trim();
  }

  Future<void> _saveSession() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance
          .collection('conversation_sessions')
          .doc('${uid}_${DateTime.now().millisecondsSinceEpoch}')
          .set({
        'uid': uid,
        'scenario': _scenario.name,
        'messageCount': _messages.length,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🤖 AI Conversation',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            if (_scenarioPicked)
              Text(
                _scenario.label,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          if (_scenarioPicked)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded),
              onPressed: () => setState(() {
                _scenarioPicked = false;
                _messages.clear();
              }),
              tooltip: 'Đổi kịch bản',
            ),
        ],
      ),
      body: !_scenarioPicked
          ? _buildScenarioPicker()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) {
                        return const _TypingBubble();
                      }
                      return _MessageBubble(msg: _messages[i]);
                    },
                  ),
                ),
                _InputBar(
                  ctrl: _ctrl,
                  focus: _focus,
                  loading: _loading,
                  onSend: _send,
                ),
              ],
            ),
    );
  }

  Widget _buildScenarioPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Text('🤖', style: TextStyle(fontSize: 32)),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Conversation Partner',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Luyện nói tiếng Anh với AI. Meow sẽ sửa lỗi ngữ pháp và gợi ý từ hay hơn.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chọn kịch bản:',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333)),
          ),
          const SizedBox(height: 12),
          ...ConversationScenario.values.map((s) => _ScenarioCard(
                scenario: s,
                onTap: () {
                  setState(() {
                    _scenario = s;
                    _scenarioPicked = true;
                    _messages = [
                      ConvMessage(
                        isUser: false,
                        text: s.openingLine,
                        original: s.openingLine,
                      ),
                    ];
                  });
                },
              )),
        ],
      ),
    );
  }
}

// ─── Scenario Card ────────────────────────────────────────────────────────────

class _ScenarioCard extends StatelessWidget {
  final ConversationScenario scenario;
  final VoidCallback onTap;

  const _ScenarioCard({required this.scenario, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Text(scenario.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF222222)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scenario.description,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final ConvMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            msg.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: msg.isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!msg.isUser) ...[
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                      child: Text('🤖', style: TextStyle(fontSize: 14))),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: msg.isUser
                        ? const Color(0xFF667eea)
                        : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft:
                          Radius.circular(msg.isUser ? 18 : 4),
                      bottomRight:
                          Radius.circular(msg.isUser ? 4 : 18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    msg.text,
                    style: TextStyle(
                      color: msg.isUser
                          ? Colors.white
                          : const Color(0xFF222222),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Grammar correction card
          if (msg.correction != null) ...[
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.only(right: 4),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFFB347).withOpacity(0.4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('✏️ Gợi ý sửa:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF8C00))),
                  const SizedBox(height: 4),
                  Text(
                    '❌ ${msg.correction!.original}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF4757),
                        decoration: TextDecoration.lineThrough),
                  ),
                  Text(
                    '✅ ${msg.correction!.better}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF06D6A0),
                        fontWeight: FontWeight.w600),
                  ),
                  if (msg.correction!.why.isNotEmpty)
                    Text(
                      '💡 ${msg.correction!.why}',
                      style: const TextStyle(
                          fontSize: 11, color: Colors.grey),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Typing Bubble ────────────────────────────────────────────────────────────

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 14))),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: const Text('...', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
  }
}

// ─── Input Bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final bool loading;
  final VoidCallback onSend;

  const _InputBar({
    required this.ctrl,
    required this.focus,
    required this.loading,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              focusNode: focus,
              enabled: !loading,
              decoration: InputDecoration(
                hintText: 'Type in English...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: loading ? null : onSend,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: loading
                    ? Colors.grey.shade300
                    : const Color(0xFF667eea),
                shape: BoxShape.circle,
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

enum ConversationScenario {
  freeChat,
  restaurant,
  jobInterview,
  shopping,
  travel;

  String get label => switch (this) {
        ConversationScenario.freeChat => 'Free Chat',
        ConversationScenario.restaurant => 'Tại nhà hàng',
        ConversationScenario.jobInterview => 'Phỏng vấn xin việc',
        ConversationScenario.shopping => 'Mua sắm',
        ConversationScenario.travel => 'Du lịch / Sân bay',
      };

  String get emoji => switch (this) {
        ConversationScenario.freeChat => '💬',
        ConversationScenario.restaurant => '🍽️',
        ConversationScenario.jobInterview => '💼',
        ConversationScenario.shopping => '🛍️',
        ConversationScenario.travel => '✈️',
      };

  String get description => switch (this) {
        ConversationScenario.freeChat => 'Nói chuyện tự do về bất kỳ chủ đề nào',
        ConversationScenario.restaurant => 'Gọi món, hỏi về menu, thanh toán',
        ConversationScenario.jobInterview => 'Trả lời câu hỏi phỏng vấn bằng tiếng Anh',
        ConversationScenario.shopping => 'Hỏi giá, size, màu sắc, trả giá',
        ConversationScenario.travel => 'Check-in, hỏi đường, đặt phòng',
      };

  String get openingLine => switch (this) {
        ConversationScenario.freeChat =>
          "Hey! I'm your English conversation partner. What would you like to talk about today? 😊",
        ConversationScenario.restaurant =>
          "Welcome! Table for how many? Can I start you off with something to drink?",
        ConversationScenario.jobInterview =>
          "Good morning! Please have a seat. So, tell me a little about yourself and why you're interested in this position.",
        ConversationScenario.shopping =>
          "Hi there! Welcome to our store. Are you looking for anything in particular today?",
        ConversationScenario.travel =>
          "Good afternoon! Welcome to the check-in counter. May I see your passport and booking confirmation, please?",
      };
}

class ConvMessage {
  final bool isUser;
  final String text, original;
  final GrammarCorrection? correction;

  const ConvMessage({
    required this.isUser,
    required this.text,
    required this.original,
    this.correction,
  });

  String get cleanText => text;
}

class GrammarCorrection {
  final String original, better, why;
  const GrammarCorrection({
    required this.original,
    required this.better,
    required this.why,
  });
}
