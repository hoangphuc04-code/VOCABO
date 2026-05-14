import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_data.dart';
import 'game_result_screen.dart';

// ignore_for_file: library_private_types_in_public_api

/// 🃏 Lật Thẻ — tìm cặp từ tiếng Anh và nghĩa tiếng Việt

class FlipCardGame extends StatefulWidget {
  final int level;
  const FlipCardGame({super.key, required this.level});

  @override
  State<FlipCardGame> createState() => _FlipCardGameState();
}

class _FlipCardGameState extends State<FlipCardGame> {
  static const _color = Color(0xFF4A90D9);

  // Số cặp theo level: level 1-3: 6 cặp, 4-6: 8 cặp, 7-10: 10 cặp
  int get _pairCount {
    if (widget.level <= 3) return 6;
    if (widget.level <= 6) return 8;
    return 10;
  }

  late List<_CardItem> _cards;
  late int _timeLimit;

  int? _firstFlipped;  // index thẻ đầu tiên đang lật
  int? _secondFlipped; // index thẻ thứ hai đang lật
  bool _checking = false; // đang kiểm tra cặp, block input

  int _score = 0;
  int _moves = 0;
  int _elapsed = 0;
  int _matched = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setup() {
    final words = GameData.getWords(widget.level);
    _timeLimit = GameData.timeLimitForLevel(widget.level) + 60;
    final rng = Random();
    final shuffled = List<WordPair>.from(words)..shuffle(rng);
    final selected = shuffled.take(_pairCount).toList();

    // Tạo 2 thẻ cho mỗi cặp: 1 thẻ từ tiếng Anh, 1 thẻ nghĩa
    _cards = [];
    for (int i = 0; i < selected.length; i++) {
      _cards.add(_CardItem(
          pairId: i, text: selected[i].word, isWord: true));
      _cards.add(_CardItem(
          pairId: i, text: selected[i].meaning, isWord: false));
    }
    _cards.shuffle(rng);

    _firstFlipped = null;
    _secondFlipped = null;
    _checking = false;
    _score = 0;
    _moves = 0;
    _elapsed = 0;
    _matched = 0;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _timeLimit) {
        _timer?.cancel();
        _finish();
      }
    });
  }

  void _onTap(int index) {
    if (_checking) return;
    final card = _cards[index];
    if (card.matched || card.flipped) return;
    if (_firstFlipped == index) return;

    HapticFeedback.selectionClick();
    setState(() => card.flipped = true);

    if (_firstFlipped == null) {
      _firstFlipped = index;
    } else {
      _secondFlipped = index;
      _moves++;
      _checking = true;
      _checkMatch();
    }
  }

  void _checkMatch() {
    final first = _cards[_firstFlipped!];
    final second = _cards[_secondFlipped!];

    if (first.pairId == second.pairId) {
      // Đúng cặp
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() {
          first.matched = true;
          second.matched = true;
          _matched++;
          // Điểm: nhiều hơn nếu ít moves
          final bonus = max(0, 20 - _moves);
          _score += 30 + bonus;
          _firstFlipped = null;
          _secondFlipped = null;
          _checking = false;
        });
        if (_matched == _pairCount) {
          _timer?.cancel();
          Future.delayed(const Duration(milliseconds: 400), _finish);
        }
      });
    } else {
      // Sai — lật lại sau 800ms
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        setState(() {
          first.flipped = false;
          second.flipped = false;
          _firstFlipped = null;
          _secondFlipped = null;
          _checking = false;
        });
      });
    }
  }

  void _finish() {
    if (!mounted) return;
    final maxScore = _pairCount * 50;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          gameType: 'flip_card',
          gameName: '🃏 Lật Thẻ',
          level: widget.level,
          score: _score,
          maxScore: maxScore,
          timeSeconds: _elapsed,
          timeLimitSeconds: _timeLimit,
          color: _color,
          onReplay: (ctx) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(builder: (_) => FlipCardGame(level: widget.level)),
          ),
          onNextLevel: (ctx) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(
              builder: (_) => FlipCardGame(
                level: (widget.level < GameData.totalLevels)
                    ? widget.level + 1
                    : widget.level,
              ),
            ),
          ),
          onHome: (ctx) => Navigator.popUntil(ctx, (r) => r.isFirst),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final remaining = max(0, _timeLimit - _elapsed);
    final timeColor = remaining <= 20
        ? Colors.red
        : remaining <= 40
            ? Colors.orange
            : Colors.white;

    // Grid: 4 cột cho 6 cặp (12 thẻ), 4 cột cho 8 cặp (16 thẻ), 4 cột cho 10 cặp (20 thẻ)
    const crossAxisCount = 4;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: _color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '🃏 Lật Thẻ — Màn ${widget.level}',
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
            value: _timeLimit > 0 ? remaining / _timeLimit : 0,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(timeColor),
            minHeight: 6,
          ),
        ),
      ),
      body: Column(
        children: [
          // Stats bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatPill(
                    icon: '🃏',
                    label: '$_matched/$_pairCount cặp',
                    color: _color),
                _StatPill(
                    icon: '👆',
                    label: '$_moves lượt',
                    color: Colors.grey.shade600),
              ],
            ),
          ),
          // Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.85,
                ),
                itemCount: _cards.length,
                itemBuilder: (_, i) => _FlipCardTile(
                  card: _cards[i],
                  color: _color,
                  onTap: () => _onTap(i),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              'Lật 2 thẻ để tìm cặp từ — nghĩa tương ứng',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card Item model ──────────────────────────────────────────────────────────

class _CardItem {
  final int pairId;
  final String text;
  final bool isWord; // true = tiếng Anh, false = tiếng Việt
  bool flipped = false;
  bool matched = false;
  _CardItem({required this.pairId, required this.text, required this.isWord});
}

// ─── Flip Card Tile ───────────────────────────────────────────────────────────

class _FlipCardTile extends StatelessWidget {
  final _CardItem card;
  final Color color;
  final VoidCallback onTap;

  const _FlipCardTile({
    required this.card,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final showFront = card.flipped || card.matched;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: card.matched
              ? color.withValues(alpha: 0.15)
              : showFront
                  ? Colors.white
                  : const Color(0xFF667eea),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: card.matched
                ? color
                : showFront
                    ? color.withValues(alpha: 0.4)
                    : Colors.transparent,
            width: card.matched ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (card.matched ? color : const Color(0xFF667eea))
                  .withValues(alpha: 0.2),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: showFront
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (card.matched)
                        Icon(Icons.check_circle_rounded,
                            color: color, size: 16),
                      if (card.matched) const SizedBox(height: 4),
                      Text(
                        card.text,
                        style: TextStyle(
                          fontSize: card.text.length > 8 ? 11 : 13,
                          fontWeight: FontWeight.bold,
                          color: card.matched ? color : const Color(0xFF333333),
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        card.isWord ? 'EN' : 'VI',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              : const Text('?',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
        ),
      ),
    );
  }
}

// ─── Stat Pill ────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _StatPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }
}
