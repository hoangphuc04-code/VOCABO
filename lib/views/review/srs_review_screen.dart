import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../data/services/srs_service.dart';
import '../../data/services/smart_srs_service.dart';

/// 📊 SRS Review Screen — Ôn tập theo thuật toán Spaced Repetition (SM-2)
class SrsReviewScreen extends StatefulWidget {
  const SrsReviewScreen({super.key});

  @override
  State<SrsReviewScreen> createState() => _SrsReviewScreenState();
}

class _SrsReviewScreenState extends State<SrsReviewScreen>
    with SingleTickerProviderStateMixin {
  List<SrsCard> _cards = [];
  int _current = 0;
  bool _loading = true;
  bool _flipped = false;
  int _reviewed = 0;
  int _easy = 0;
  int _hard = 0;
  int _again = 0;

  late AnimationController _flipCtrl;
  late Animation<double> _flipAnim;
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _flipCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 350));
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut));
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.45);
    _loadCards();
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _loadCards() async {
    setState(() => _loading = true);
    await SrsService.initSrsForLearnedWords();
    final cards = await SrsService.getDueCards(limit: 30);
    setState(() {
      _cards = cards..shuffle(Random());
      _loading = false;
    });
  }

  void _flip() {
    if (_flipped) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _flipped = !_flipped);
  }

  Future<void> _speak(String text) async {
    await _tts.speak(text);
  }

  // quality: 5=easy, 3=good, 1=hard, 0=again
  Future<void> _answer(int quality, String label) async {
    final card = _cards[_current];
    await SrsService.recordReview(
      wordId: card.wordId,
      topicId: card.topicId,
      quality: quality,
    );

    // Ghi nhận lỗi sai để AI phân tích (quality < 3 = hard hoặc again)
    if (quality < 3) {
      SmartSrsService.recordMistake(
        wordId: card.wordId,
        word: card.word,
        meaning: card.meaning,
        wrongAnswer: label,
        correctAnswer: card.meaning,
      );
    }

    if (quality >= 4) _easy++;
    else if (quality >= 2) _hard++;
    else _again++;
    _reviewed++;

    if (_flipped) {
      _flipCtrl.reverse();
      setState(() => _flipped = false);
    }

    if (_current + 1 >= _cards.length) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) _showResult();
    } else {
      setState(() => _current++);
    }
  }

  void _showResult() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _SrsResultDialog(
        reviewed: _reviewed,
        easy: _easy,
        hard: _hard,
        again: _again,
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
        onReview: () {
          Navigator.pop(context);
          _easy = _hard = _again = _reviewed = 0;
          _loadCards();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('📊 Ôn tập SRS',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (!_loading && _cards.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${_current + 1}/${_cards.length}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : _cards.isEmpty
              ? _buildEmpty()
              : _buildContent(),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🎉', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text('Không có từ nào cần ôn hôm nay!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Quay lại sau để ôn tập tiếp nhé 😊',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Quay lại'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final card = _cards[_current];
    return Column(
      children: [
        // Progress bar
        Container(
          color: const Color(0xFF667eea),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_current + 1} / ${_cards.length}',
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  Text('✅ $_easy dễ  💪 $_hard khó  🔄 $_again lại',
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _cards.isEmpty ? 0 : (_current + 1) / _cards.length,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // SRS info badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _strengthColor(card.strength).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _strengthColor(card.strength).withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: _strengthColor(card.strength)),
                      const SizedBox(width: 4),
                      Text(card.strengthLabel,
                          style: TextStyle(
                              fontSize: 12,
                              color: _strengthColor(card.strength),
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                      Text('Ôn lần ${card.repetitions + 1}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Flashcard
                GestureDetector(
                  onTap: _flip,
                  child: AnimatedBuilder(
                    animation: _flipAnim,
                    builder: (_, __) {
                      final angle = _flipAnim.value * pi;
                      final showFront = _flipAnim.value < 0.5;
                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: showFront
                            ? _SrsFront(card: card, onSpeak: () => _speak(card.word))
                            : Transform(
                                alignment: Alignment.center,
                                transform: Matrix4.identity()..rotateY(pi),
                                child: _SrsBack(card: card),
                              ),
                      );
                    },
                  ),
                ),

                if (!_flipped) ...[
                  const SizedBox(height: 16),
                  Text('Nhấn vào thẻ để xem nghĩa',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],

                if (_flipped) ...[
                  const SizedBox(height: 20),
                  const Text('Bạn nhớ từ này như thế nào?',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _RatingBtn(
                          label: 'Lại',
                          emoji: '🔄',
                          color: const Color(0xFFFF4757),
                          onTap: () => _answer(0, 'again'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RatingBtn(
                          label: 'Khó',
                          emoji: '😓',
                          color: const Color(0xFFFF8C69),
                          onTap: () => _answer(2, 'hard'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RatingBtn(
                          label: 'Tốt',
                          emoji: '👍',
                          color: const Color(0xFF4CAF50),
                          onTap: () => _answer(4, 'good'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RatingBtn(
                          label: 'Dễ',
                          emoji: '⭐',
                          color: const Color(0xFF667eea),
                          onTap: () => _answer(5, 'easy'),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _strengthColor(double strength) {
    if (strength >= 0.8) return const Color(0xFF06D6A0);
    if (strength >= 0.6) return const Color(0xFF4CAF50);
    if (strength >= 0.4) return const Color(0xFFFFB347);
    if (strength >= 0.2) return const Color(0xFFFF8C69);
    return const Color(0xFFFF4757);
  }
}

// ─── Card Front ───────────────────────────────────────────────────────────────

class _SrsFront extends StatelessWidget {
  final SrsCard card;
  final VoidCallback onSpeak;
  const _SrsFront({required this.card, required this.onSpeak});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    card.word,
                    style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF222222)),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onSpeak,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.volume_up_rounded,
                        color: Color(0xFF667eea), size: 22),
                  ),
                ),
              ],
            ),
            if (card.phonetic.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(card.phonetic,
                  style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic)),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded,
                    color: Colors.grey.shade300, size: 18),
                const SizedBox(width: 6),
                Text('Nhấn để xem nghĩa',
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Card Back ────────────────────────────────────────────────────────────────

class _SrsBack extends StatelessWidget {
  final SrsCard card;
  const _SrsBack({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF667eea).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(card.word,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const Divider(color: Colors.white24, height: 20),
          Text('Nghĩa',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.6),
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(card.meaning,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          if (card.example.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('"${card.example}"',
                      style: TextStyle(
                          fontStyle: FontStyle.italic,
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13)),
                  if (card.exampleVi.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(card.exampleVi,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 12)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Rating Button ────────────────────────────────────────────────────────────

class _RatingBtn extends StatelessWidget {
  final String label;
  final String emoji;
  final Color color;
  final VoidCallback onTap;
  const _RatingBtn({
    required this.label,
    required this.emoji,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Result Dialog ────────────────────────────────────────────────────────────

class _SrsResultDialog extends StatelessWidget {
  final int reviewed, easy, hard, again;
  final VoidCallback onDone;
  final VoidCallback onReview;
  const _SrsResultDialog({
    required this.reviewed,
    required this.easy,
    required this.hard,
    required this.again,
    required this.onDone,
    required this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Hoàn thành! 🎉',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Đã ôn $reviewed từ hôm nay',
              style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 16),
          _Row('⭐ Dễ', easy, const Color(0xFF667eea)),
          const SizedBox(height: 8),
          _Row('👍 Tốt / Khó', hard, const Color(0xFFFF8C69)),
          const SizedBox(height: 8),
          _Row('🔄 Cần ôn lại', again, const Color(0xFFFF4757)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '💡 SM-2 đã lên lịch ôn tập tiếp theo cho bạn!',
              style: TextStyle(fontSize: 12, color: Color(0xFF667eea)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.spaceEvenly,
      actions: [
        TextButton(onPressed: onDone, child: const Text('Xong')),
        ElevatedButton(
          onPressed: onReview,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF667eea),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Ôn thêm'),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _Row(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label, style: const TextStyle(fontSize: 14)),
      const Spacer(),
      Text('$count',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}
