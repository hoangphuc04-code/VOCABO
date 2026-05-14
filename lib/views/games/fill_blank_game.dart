import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_data.dart';
import 'game_result_screen.dart';

// ignore_for_file: library_private_types_in_public_api

/// ✏️ Điền Từ — gõ từ tiếng Anh từ gợi ý nghĩa tiếng Việt

class FillBlankGame extends StatefulWidget {
  final int level;
  const FillBlankGame({super.key, required this.level});

  @override
  State<FillBlankGame> createState() => _FillBlankGameState();
}

class _FillBlankGameState extends State<FillBlankGame>
    with SingleTickerProviderStateMixin {
  static const _color = Color(0xFFE91E8C);

  late List<WordPair> _questions;
  late int _timeLimit;
  late int _totalQuestions;

  int _current = 0;
  int _score = 0;
  int _correct = 0;
  int _elapsed = 0;
  Timer? _timer;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  // Trạng thái câu hiện tại
  _AnswerState _answerState = _AnswerState.idle;
  String _correctAnswer = '';
  int _hintLevel = 0; // 0=chưa gợi ý, 1=chữ đầu, 2=nửa từ

  // Shake animation khi sai
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _setup();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _setup() {
    final words = GameData.getWords(widget.level);
    _timeLimit = GameData.timeLimitForLevel(widget.level) + 30;
    _totalQuestions = min(10, words.length);
    final rng = Random();
    final shuffled = List<WordPair>.from(words)..shuffle(rng);
    _questions = shuffled.take(_totalQuestions).toList();

    _current = 0;
    _score = 0;
    _correct = 0;
    _elapsed = 0;
    _hintLevel = 0;
    _answerState = _AnswerState.idle;
    _controller.clear();

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _timeLimit) {
        _timer?.cancel();
        _finish();
      }
    });

    Future.delayed(const Duration(milliseconds: 300),
        () => _focusNode.requestFocus());
  }

  WordPair get _currentQ => _questions[_current];

  void _submit() {
    if (_answerState != _AnswerState.idle) return;
    final input = _controller.text.trim().toLowerCase();
    final answer = _currentQ.word.toLowerCase();

    if (input == answer) {
      // Đúng
      HapticFeedback.lightImpact();
      final bonus = max(0, 20 - _hintLevel * 8);
      setState(() {
        _answerState = _AnswerState.correct;
        _score += 30 + bonus;
        _correct++;
        _correctAnswer = _currentQ.word;
      });
      Future.delayed(const Duration(milliseconds: 800), _nextQuestion);
    } else {
      // Sai
      HapticFeedback.mediumImpact();
      _shakeCtrl.forward(from: 0);
      setState(() => _answerState = _AnswerState.wrong);
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) {
          setState(() {
            _answerState = _AnswerState.idle;
            _controller.clear();
          });
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _useHint() {
    if (_hintLevel >= 2) return;
    setState(() {
      _hintLevel++;
      final word = _currentQ.word;
      if (_hintLevel == 1) {
        // Gợi ý chữ cái đầu
        _controller.text = word[0];
        _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length));
      } else {
        // Gợi ý nửa từ
        final half = (word.length / 2).ceil();
        _controller.text = word.substring(0, half);
        _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length));
      }
    });
    _focusNode.requestFocus();
  }

  void _skip() {
    setState(() {
      _answerState = _AnswerState.skipped;
      _correctAnswer = _currentQ.word;
    });
    Future.delayed(const Duration(milliseconds: 1000), _nextQuestion);
  }

  void _nextQuestion() {
    if (!mounted) return;
    if (_current + 1 >= _totalQuestions) {
      _finish();
      return;
    }
    setState(() {
      _current++;
      _answerState = _AnswerState.idle;
      _hintLevel = 0;
      _controller.clear();
    });
    _focusNode.requestFocus();
  }

  void _finish() {
    if (!mounted) return;
    _timer?.cancel();
    final maxScore = _totalQuestions * 50;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          gameType: 'fill_blank',
          gameName: '✏️ Điền Từ',
          level: widget.level,
          score: _score,
          maxScore: maxScore,
          timeSeconds: _elapsed,
          timeLimitSeconds: _timeLimit,
          color: _color,
          onReplay: (ctx) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(
                builder: (_) => FillBlankGame(level: widget.level)),
          ),
          onNextLevel: (ctx) {
            final next = (widget.level < GameData.totalLevels)
                ? widget.level + 1
                : widget.level;
            Navigator.pushReplacement(
              ctx,
              MaterialPageRoute(builder: (_) => FillBlankGame(level: next)),
            );
          },
          onHome: (ctx) => Navigator.popUntil(ctx, (r) => r.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = max(0, _timeLimit - _elapsed);
    final timeColor = remaining <= 15
        ? Colors.red
        : remaining <= 30
            ? Colors.orange
            : Colors.white;
    final progress = _totalQuestions > 0 ? _current / _totalQuestions : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: _color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '✏️ Điền Từ — Màn ${widget.level}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded, color: timeColor, size: 15),
                const SizedBox(width: 4),
                Text('${remaining}s',
                    style: TextStyle(
                        color: timeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text('$_score',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: const AlwaysStoppedAnimation(Colors.white),
            minHeight: 6,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Progress
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Câu ${_current + 1}/$_totalQuestions',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _color),
                  ),
                  Text(
                    '✅ $_correct đúng',
                    style: TextStyle(
                        fontSize: 13,
                        color: _correct > 0 ? Colors.green : Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Question card
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) {
                  final offset = _shakeCtrl.isAnimating
                      ? sin(_shakeCtrl.value * pi * 5) * _shakeAnim.value
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: _color.withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Nghĩa tiếng Việt:',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _currentQ.meaning,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      // Blank display
                      Text(
                        _buildBlankDisplay(),
                        style: TextStyle(
                          fontSize: 18,
                          letterSpacing: 4,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Feedback
              if (_answerState == _AnswerState.correct)
                _FeedbackBanner(
                    text: '✅ Chính xác! "$_correctAnswer"',
                    color: const Color(0xFF06D6A0))
              else if (_answerState == _AnswerState.wrong)
                _FeedbackBanner(
                    text: '❌ Sai rồi, thử lại!',
                    color: const Color(0xFFEF5350))
              else if (_answerState == _AnswerState.skipped)
                _FeedbackBanner(
                    text: '⏭️ Đáp án: "$_correctAnswer"',
                    color: Colors.orange),

              const SizedBox(height: 16),

              // Input field
              TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: _answerState == _AnswerState.idle,
                textCapitalization: TextCapitalization.none,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'Nhập từ tiếng Anh...',
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: _color, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 16),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.send_rounded, color: _color),
                    onPressed: _submit,
                  ),
                ),
                onSubmitted: (_) => _submit(),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  // Hint button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _hintLevel < 2 &&
                              _answerState == _AnswerState.idle
                          ? _useHint
                          : null,
                      icon: const Text('💡', style: TextStyle(fontSize: 14)),
                      label: Text(
                        _hintLevel == 0
                            ? 'Gợi ý'
                            : _hintLevel == 1
                                ? 'Gợi ý thêm'
                                : 'Hết gợi ý',
                        style: const TextStyle(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _color,
                        side: BorderSide(color: _color.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Skip button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed:
                          _answerState == _AnswerState.idle ? _skip : null,
                      icon: const Icon(Icons.skip_next_rounded, size: 18),
                      label: const Text('Bỏ qua',
                          style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _answerState == _AnswerState.idle ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Xác nhận',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildBlankDisplay() {
    final word = _currentQ.word;
    final len = word.length;
    if (_hintLevel == 0) return '_ ' * len;
    if (_hintLevel == 1) {
      return word[0] + (' _' * (len - 1));
    }
    final half = (len / 2).ceil();
    return word.substring(0, half) + (' _' * (len - half));
  }
}

// ─── Answer State ─────────────────────────────────────────────────────────────

enum _AnswerState { idle, correct, wrong, skipped }

// ─── Feedback Banner ──────────────────────────────────────────────────────────

class _FeedbackBanner extends StatelessWidget {
  final String text;
  final Color color;

  const _FeedbackBanner({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w600, color: color),
        textAlign: TextAlign.center,
      ),
    );
  }
}
