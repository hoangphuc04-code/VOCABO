import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../data/services/conversation_service.dart';
import 'conversation_report_screen.dart';

/// 🎤 Conversation Screen — luyện hội thoại với AI
class ConversationScreen extends StatefulWidget {
  final ConversationScenario scenario;
  const ConversationScreen({super.key, required this.scenario});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  List<_ConvMsg> _messages = [];
  List<Map<String, String>> _history = [];
  bool _loading = true;
  bool _isListening = false;
  bool _sttAvailable = false;
  int _turnCount = 0;

  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _initStt();
    _startConversation();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    _focus.dispose();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (e) {
        if (mounted) setState(() => _isListening = false);
      },
      debugLogging: false,
    );
    if (mounted) setState(() => _sttAvailable = ok);
  }

  Future<void> _startConversation() async {
    setState(() => _loading = true);
    final turn = await ConversationService.startConversation(widget.scenario);
    if (mounted) {
      setState(() {
        _messages.add(_ConvMsg(text: turn.text, isUser: false));
        _history.add({'role': 'assistant', 'content': turn.text});
        _loading = false;
      });
      _tts.speak(turn.text);
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _loading) return;

    _ctrl.clear();
    setState(() {
      _messages.add(_ConvMsg(text: text, isUser: true));
      _history.add({'role': 'user', 'content': text});
      _loading = true;
      _turnCount++;
    });
    _scrollToBottom();

    final turn = await ConversationService.sendMessage(
      scenario: widget.scenario,
      history: _history,
      userMessage: text,
    );

    if (mounted) {
      setState(() {
        _messages.add(_ConvMsg(text: turn.text, isUser: false));
        _history.add({'role': 'assistant', 'content': turn.text});
        _loading = false;
      });
      _tts.speak(turn.text);
      _scrollToBottom();
    }
  }

  Future<void> _startListening() async {
    if (!_sttAvailable || _isListening) return;
    setState(() => _isListening = true);

    final started = await _stt.listen(
      localeId: 'en_US',
      listenFor: const Duration(seconds: 8),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      cancelOnError: true,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult result) {
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          // Hiển thị nguyên văn câu nói vào text field realtime
          _ctrl.text = words;
          _ctrl.selection = TextSelection.fromPosition(
            TextPosition(offset: _ctrl.text.length),
          );
        }
        if (result.finalResult) {
          if (mounted) setState(() => _isListening = false);
        }
      },
    );

    if (!started && mounted) {
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    setState(() => _isListening = false);
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

  Future<void> _endConversation() async {
    if (_turnCount == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _loading = true);
    final report = await ConversationService.evaluateConversation(
      scenario: widget.scenario,
      history: _history,
    );
    if (mounted) {
      setState(() => _loading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationReportScreen(
            scenario: widget.scenario,
            report: report,
            turnCount: _turnCount,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.scenario.color);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Text(widget.scenario.emoji,
                style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.scenario.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
                Text('AI: ${widget.scenario.aiRoleVi}',
                    style: const TextStyle(
                        fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _endConversation,
            icon: const Icon(Icons.assessment_rounded,
                color: Colors.white, size: 18),
            label: const Text('Kết thúc',
                style: TextStyle(color: Colors.white, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Vocab hints
          _VocabHints(scenario: widget.scenario, color: color),

          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return _TypingBubble(color: color);
                return _MessageBubble(
                  msg: _messages[i],
                  color: color,
                  scenario: widget.scenario,
                  onSpeak: (text) => _tts.speak(text),
                );
              },
            ),
          ),

          // Input
          _InputBar(
            ctrl: _ctrl,
            focus: _focus,
            loading: _loading,
            isListening: _isListening,
            sttAvailable: _sttAvailable,
            color: color,
            onSend: _sendMessage,
            onMic: _isListening ? _stopListening : _startListening,
          ),
        ],
      ),
    );
  }
}

// ─── Vocab Hints ──────────────────────────────────────────────────────────────

class _VocabHints extends StatelessWidget {
  final ConversationScenario scenario;
  final Color color;
  const _VocabHints({required this.scenario, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('🎯 Từ mục tiêu: ',
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: scenario.targetVocab
                    .map((v) => Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(v,
                              style: TextStyle(
                                  fontSize: 11, color: color)),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message Bubble ───────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _ConvMsg msg;
  final Color color;
  final ConversationScenario scenario;
  final void Function(String) onSpeak;
  const _MessageBubble({
    required this.msg,
    required this.color,
    required this.scenario,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(scenario.emoji,
                    style: const TextStyle(fontSize: 16)),
              ),
            ),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? color : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
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
                      color: isUser ? Colors.white : const Color(0xFF222222),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                if (!isUser)
                  GestureDetector(
                    onTap: () => onSpeak(msg.text),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4, left: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.volume_up_rounded,
                              size: 14, color: color),
                          const SizedBox(width: 3),
                          Text('Nghe lại',
                              style: TextStyle(
                                  fontSize: 11, color: color)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typing Bubble ────────────────────────────────────────────────────────────

class _TypingBubble extends StatelessWidget {
  final Color color;
  const _TypingBubble({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Center(
                child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    offset: const Offset(0, 2))
              ],
            ),
            child: const Text('Đang trả lời...',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
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
  final bool isListening;
  final bool sttAvailable;
  final Color color;
  final void Function([String?]) onSend;
  final VoidCallback onMic;

  const _InputBar({
    required this.ctrl,
    required this.focus,
    required this.loading,
    required this.isListening,
    required this.sttAvailable,
    required this.color,
    required this.onSend,
    required this.onMic,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Mic button
          if (sttAvailable)
            GestureDetector(
              onTap: onMic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isListening
                      ? Colors.red
                      : color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                  color: isListening ? Colors.white : color,
                  size: 22,
                ),
              ),
            ),

          // Text field
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: ctrl,
                focusNode: focus,
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: isListening
                      ? '🎙️ Đang nghe...'
                      : 'Nhập câu trả lời bằng tiếng Anh...',
                  hintStyle: TextStyle(
                      color: isListening ? Colors.red : Colors.grey.shade400,
                      fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: loading ? null : () => onSend(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: loading ? Colors.grey.shade300 : color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.send_rounded,
                color: loading ? Colors.grey : Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class _ConvMsg {
  final String text;
  final bool isUser;
  const _ConvMsg({required this.text, required this.isUser});
}
