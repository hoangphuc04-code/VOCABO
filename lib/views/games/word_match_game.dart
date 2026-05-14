import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_data.dart';
import 'game_result_screen.dart';

// ignore_for_file: library_private_types_in_public_api

/// 🔗 Nối Từ — kéo nối từ tiếng Anh với nghĩa tiếng Việt

class WordMatchGame extends StatefulWidget {
  final int level;
  const WordMatchGame({super.key, required this.level});

  @override
  State<WordMatchGame> createState() => _WordMatchGameState();
}

class _WordMatchGameState extends State<WordMatchGame>
    with SingleTickerProviderStateMixin {
  static const _color = Color(0xFF06D6A0);
  static const _pairCount = 6; // số cặp mỗi màn

  late List<WordPair> _pairs;
  late int _timeLimit;

  // Danh sách item bên trái (từ) và bên phải (nghĩa)
  late List<_MatchItem> _leftItems;
  late List<_MatchItem> _rightItems;

  int? _selectedLeft;  // index đang chọn bên trái
  int? _selectedRight; // index đang chọn bên phải

  int _score = 0;
  int _elapsed = 0;
  int _mistakes = 0;
  Timer? _timer;
  bool _finished = false;

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
    _shakeAnim = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _setup();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _setup() {
    final words = GameData.getWords(widget.level);
    _timeLimit = GameData.timeLimitForLevel(widget.level) + 30;
    final rng = Random();
    final shuffled = List<WordPair>.from(words)..shuffle(rng);
    _pairs = shuffled.take(_pairCount).toList();

    _leftItems = _pairs
        .asMap()
        .entries
        .map((e) => _MatchItem(id: e.key, text: e.value.word))
        .toList()
      ..shuffle(rng);

    _rightItems = _pairs
        .asMap()
        .entries
        .map((e) => _MatchItem(id: e.key, text: e.value.meaning))
        .toList()
      ..shuffle(rng);

    _selectedLeft = null;
    _selectedRight = null;
    _score = 0;
    _elapsed = 0;
    _mistakes = 0;
    _finished = false;

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _timeLimit) {
        _timer?.cancel();
        _finish();
      }
    });
  }

  void _onSelectLeft(int index) {
    if (_finished) return;
    final item = _leftItems[index];
    if (item.matched) return;
    setState(() => _selectedLeft = index);
    _tryMatch();
  }

  void _onSelectRight(int index) {
    if (_finished) return;
    final item = _rightItems[index];
    if (item.matched) return;
    setState(() => _selectedRight = index);
    _tryMatch();
  }

  void _tryMatch() {
    if (_selectedLeft == null || _selectedRight == null) return;
    final left = _leftItems[_selectedLeft!];
    final right = _rightItems[_selectedRight!];

    if (left.id == right.id) {
      // Đúng
      HapticFeedback.lightImpact();
      setState(() {
        left.matched = true;
        right.matched = true;
        _score += max(10, 30 - _mistakes * 3);
        _selectedLeft = null;
        _selectedRight = null;
      });
      // Kiểm tra hoàn thành
      if (_leftItems.every((i) => i.matched)) {
        _timer?.cancel();
        setState(() => _finished = true);
        Future.delayed(const Duration(milliseconds: 500), _finish);
      }
    } else {
      // Sai
      HapticFeedback.mediumImpact();
      _mistakes++;
      _shakeCtrl.forward(from: 0);
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() { _selectedLeft = null; _selectedRight = null; });
      });
    }
  }

  void _finish() {
    if (!mounted) return;
    final matched = _leftItems.where((i) => i.matched).length;
    final maxScore = _pairCount * 30;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          gameType: 'word_match',
          gameName: '🔗 Nối Từ',
          level: widget.level,
          score: _score,
          maxScore: maxScore,
          timeSeconds: _elapsed,
          timeLimitSeconds: _timeLimit,
          color: _color,
          onReplay: (ctx) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(builder: (_) => WordMatchGame(level: widget.level)),
          ),
          onNextLevel: (ctx) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(
              builder: (_) => WordMatchGame(
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
    // Suppress unused variable warning
    matched;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = max(0, _timeLimit - _elapsed);
    final timeColor = remaining <= 15
        ? Colors.red
        : remaining <= 30
            ? Colors.orange
            : Colors.white;

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
          '🔗 Nối Từ — Màn ${widget.level}',
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
          // Progress chips
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_leftItems.where((i) => i.matched).length}/$_pairCount cặp',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _color),
                ),
                Text(
                  'Sai: $_mistakes',
                  style: TextStyle(
                      fontSize: 13,
                      color: _mistakes > 0 ? Colors.red : Colors.grey),
                ),
              ],
            ),
          ),
          // Board
          Expanded(
            child: AnimatedBuilder(
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
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    // Left column — từ tiếng Anh
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_leftItems.length, (i) {
                          final item = _leftItems[i];
                          final selected = _selectedLeft == i;
                          return _MatchTile(
                            text: item.text,
                            matched: item.matched,
                            selected: selected,
                            color: _color,
                            onTap: () => _onSelectLeft(i),
                          );
                        }),
                      ),
                    ),
                    // Connector lines
                    SizedBox(
                      width: 32,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_leftItems.length, (_) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 6),
                            child: Icon(Icons.arrow_forward_rounded,
                                color: Color(0xFFCFD8DC), size: 18),
                          );
                        }),
                      ),
                    ),
                    // Right column — nghĩa tiếng Việt
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_rightItems.length, (i) {
                          final item = _rightItems[i];
                          final selected = _selectedRight == i;
                          return _MatchTile(
                            text: item.text,
                            matched: item.matched,
                            selected: selected,
                            color: _color,
                            onTap: () => _onSelectRight(i),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Chọn từ bên trái rồi chọn nghĩa bên phải để nối',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Match Item model ─────────────────────────────────────────────────────────

class _MatchItem {
  final int id;
  final String text;
  bool matched = false;
  _MatchItem({required this.id, required this.text});
}

// ─── Match Tile ───────────────────────────────────────────────────────────────

class _MatchTile extends StatelessWidget {
  final String text;
  final bool matched;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _MatchTile({
    required this.text,
    required this.matched,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color textColor;

    if (matched) {
      bg = color.withValues(alpha: 0.12);
      border = color;
      textColor = color;
    } else if (selected) {
      bg = color.withValues(alpha: 0.18);
      border = color;
      textColor = color;
    } else {
      bg = Colors.white;
      border = Colors.grey.shade200;
      textColor = const Color(0xFF333333);
    }

    return GestureDetector(
      onTap: matched ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: selected ? 2 : 1),
          boxShadow: selected
              ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 8)]
              : null,
        ),
        child: Row(
          children: [
            if (matched)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.check_circle_rounded, color: color, size: 16),
              ),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selected || matched ? FontWeight.bold : FontWeight.normal,
                  color: textColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
