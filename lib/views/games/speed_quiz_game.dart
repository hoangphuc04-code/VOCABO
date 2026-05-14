import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'game_data.dart';
import 'game_result_screen.dart';
import 'game_widgets.dart';

/// ⚡ Speed Quiz — chọn đáp án đúng trong thời gian giới hạn
class SpeedQuizGame extends StatefulWidget {
  final int level;
  const SpeedQuizGame({super.key, required this.level});

  @override
  State<SpeedQuizGame> createState() => _SpeedQuizGameState();
}

class _SpeedQuizGameState extends State<SpeedQuizGame> {
  static const _color = Color(0xFFFFBE0B);

  late List<WordPair> _words;
  late int _timeLimit;
  late int _totalQuestions;

  int _current = 0;
  int _score = 0;
  int _correct = 0;
  int _elapsed = 0;
  int? _selectedAnswer;
  bool _answered = false;
  Timer? _timer;
  Timer? _answerTimer;

  late List<_Question> _questions;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    _words = GameData.getWords(widget.level);
    _timeLimit = GameData.timeLimitForLevel(widget.level);
    _totalQuestions = min(10 + widget.level ~/ 2, _words.length);
    _questions = _buildQuestions();
    _startTimer();
  }

  List<_Question> _buildQuestions() {
    final rng = Random();
    final shuffled = List<WordPair>.from(_words)..shuffle(rng);
    final selected = shuffled.sublist(0, _totalQuestions.clamp(1, shuffled.length));

    return selected.map((w) {
      final wrong = List<WordPair>.from(_words)
        ..removeWhere((x) => x.word == w.word)
        ..shuffle(rng);
      final options = [w.meaning, ...wrong.take(3).map((x) => x.meaning)]
        ..shuffle(rng);
      return _Question(word: w.word, correct: w.meaning, options: options);
    }).toList();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _timeLimit) _finish();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _answerTimer?.cancel();
    super.dispose();
  }

  void _answer(int optionIndex) {
    if (_answered) return;
    final q = _questions[_current];
    final isCorrect = q.options[optionIndex] == q.correct;

    setState(() {
      _selectedAnswer = optionIndex;
      _answered = true;
      if (isCorrect) {
        _correct++;
        final timeBonus = max(0, 5 - _elapsed ~/ (_current + 1));
        _score += 10 + timeBonus;
      }
    });

    _answerTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      if (_current + 1 >= _questions.length) {
        _finish();
      } else {
        setState(() {
          _current++;
          _selectedAnswer = null;
          _answered = false;
        });
      }
    });
  }

  void _finish() {
    _timer?.cancel();
    _answerTimer?.cancel();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => GameResultScreen(
            gameType: 'speed_quiz',
            gameName: 'Trả Lời Nhanh',
            level: widget.level,
            score: _score,
            maxScore: _totalQuestions * 15,
            timeSeconds: _elapsed,
            timeLimitSeconds: _timeLimit,
            color: _color,
            onReplay: (ctx) => Navigator.pushReplacement(
              ctx,
              MaterialPageRoute(builder: (_) => SpeedQuizGame(level: widget.level)),
            ),
            onNextLevel: (ctx) => Navigator.pushReplacement(
              ctx,
              MaterialPageRoute(
                builder: (_) => SpeedQuizGame(
                  level: widget.level < GameData.totalLevels
                      ? widget.level + 1
                      : widget.level,
                ),
              ),
            ),
            onHome: (ctx) => Navigator.popUntil(ctx, (r) => r.isFirst),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_questions.isEmpty) return const SizedBox();
    final remaining = max(0, _timeLimit - _elapsed);
    final q = _questions[min(_current, _questions.length - 1)];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: GameAppBar(
        title: '⚡ Trả Lời Nhanh — Màn ${widget.level}',
        color: _color,
        score: _score,
        remaining: remaining,
        progress: remaining / _timeLimit,
        level: widget.level,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Câu ${_current + 1}/$_totalQuestions',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text('✅ $_correct đúng',
                    style: const TextStyle(
                        color: Color(0xFF06D6A0), fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (_current + 1) / _totalQuestions,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation(_color),
              borderRadius: BorderRadius.circular(4),
              minHeight: 6,
            ),
            const SizedBox(height: 32),

            // Question card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_color, _color.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _color.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text('Nghĩa của từ:',
                      style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 12),
                  Text(q.word,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Options
            ...List.generate(q.options.length, (i) {
              final isCorrect = q.options[i] == q.correct;
              final isSelected = _selectedAnswer == i;

              Color bgColor = Colors.white;
              Color borderColor = Colors.grey.shade200;
              Color textColor = const Color(0xFF333333);
              IconData? icon;

              if (_answered) {
                if (isCorrect) {
                  bgColor = const Color(0xFF06D6A0).withValues(alpha: 0.15);
                  borderColor = const Color(0xFF06D6A0);
                  textColor = const Color(0xFF06D6A0);
                  icon = Icons.check_circle_rounded;
                } else if (isSelected) {
                  bgColor = Colors.red.withValues(alpha: 0.08);
                  borderColor = Colors.red.shade300;
                  textColor = Colors.red.shade400;
                  icon = Icons.cancel_rounded;
                }
              }

              return GestureDetector(
                onTap: () => _answer(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: borderColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            ['A', 'B', 'C', 'D'][i],
                            style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(q.options[i],
                            style: TextStyle(
                                color: textColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500)),
                      ),
                      if (icon != null) Icon(icon, color: textColor, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Question {
  final String word;
  final String correct;
  final List<String> options;
  const _Question({required this.word, required this.correct, required this.options});
}
