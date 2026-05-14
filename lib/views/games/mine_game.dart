import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'game_result_screen.dart';

// ignore_for_file: library_private_types_in_public_api

// ─── Config theo màn ──────────────────────────────────────────────────────────

class _MineConfig {
  final int rows;
  final int cols;
  final int mines;
  final int timeLimit; // giây

  const _MineConfig({
    required this.rows,
    required this.cols,
    required this.mines,
    required this.timeLimit,
  });
}

const _configs = <_MineConfig>[
  _MineConfig(rows: 6,  cols: 6,  mines: 4,  timeLimit: 180), // 1
  _MineConfig(rows: 7,  cols: 7,  mines: 6,  timeLimit: 180), // 2
  _MineConfig(rows: 7,  cols: 7,  mines: 8,  timeLimit: 180), // 3
  _MineConfig(rows: 8,  cols: 8,  mines: 10, timeLimit: 240), // 4
  _MineConfig(rows: 8,  cols: 8,  mines: 12, timeLimit: 240), // 5
  _MineConfig(rows: 9,  cols: 9,  mines: 14, timeLimit: 300), // 6
  _MineConfig(rows: 9,  cols: 9,  mines: 16, timeLimit: 300), // 7
  _MineConfig(rows: 10, cols: 10, mines: 18, timeLimit: 360), // 8
  _MineConfig(rows: 10, cols: 10, mines: 20, timeLimit: 360), // 9
  _MineConfig(rows: 10, cols: 10, mines: 24, timeLimit: 360), // 10
];

// ─── Cell model ───────────────────────────────────────────────────────────────

enum _CellState { hidden, revealed, flagged }

class _Cell {
  bool isMine = false;
  int adjacentMines = 0;
  _CellState state = _CellState.hidden;
}

// ─── Main game widget ─────────────────────────────────────────────────────────

class MineGame extends StatefulWidget {
  final int level;
  const MineGame({super.key, required this.level});

  @override
  State<MineGame> createState() => _MineGameState();
}

class _MineGameState extends State<MineGame> with TickerProviderStateMixin {
  static const _color = Color(0xFF26C6DA); // cyan accent

  late _MineConfig _cfg;
  late List<List<_Cell>> _board;
  bool _initialized = false; // board chưa đặt mìn (đặt sau click đầu tiên)
  bool _gameOver = false;
  bool _won = false;
  int _flagsLeft = 0;
  int _elapsed = 0;
  int _score = 0;
  Timer? _timer;

  // Animation cho ô nổ
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  int? _explodeRow, _explodeCol;

  @override
  void initState() {
    super.initState();
    _cfg = _configs[(widget.level - 1).clamp(0, _configs.length - 1)];
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 8).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _resetBoard();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Board setup ─────────────────────────────────────────────────────────────

  void _resetBoard() {
    _board = List.generate(
      _cfg.rows,
      (_) => List.generate(_cfg.cols, (_) => _Cell()),
    );
    _initialized = false;
    _gameOver = false;
    _won = false;
    _flagsLeft = _cfg.mines;
    _elapsed = 0;
    _score = 0;
    _explodeRow = null;
    _explodeCol = null;
    _timer?.cancel();
  }

  void _placeMines(int safeRow, int safeCol) {
    final rng = Random();
    int placed = 0;
    while (placed < _cfg.mines) {
      final r = rng.nextInt(_cfg.rows);
      final c = rng.nextInt(_cfg.cols);
      // Tránh ô đầu tiên và 8 ô xung quanh
      if ((r - safeRow).abs() <= 1 && (c - safeCol).abs() <= 1) continue;
      if (_board[r][c].isMine) continue;
      _board[r][c].isMine = true;
      placed++;
    }
    // Tính số mìn kề
    for (int r = 0; r < _cfg.rows; r++) {
      for (int c = 0; c < _cfg.cols; c++) {
        if (_board[r][c].isMine) continue;
        _board[r][c].adjacentMines = _countAdjacentMines(r, c);
      }
    }
    _initialized = true;
    _startTimer();
  }

  int _countAdjacentMines(int r, int c) {
    int count = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr;
        final nc = c + dc;
        if (nr >= 0 && nr < _cfg.rows && nc >= 0 && nc < _cfg.cols) {
          if (_board[nr][nc].isMine) count++;
        }
      }
    }
    return count;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
      if (_elapsed >= _cfg.timeLimit) {
        _timer?.cancel();
        _triggerGameOver(null, null);
      }
    });
  }

  // ── Interactions ─────────────────────────────────────────────────────────────

  void _onTap(int r, int c) {
    if (_gameOver || _won) return;
    final cell = _board[r][c];
    if (cell.state == _CellState.flagged) return;
    if (cell.state == _CellState.revealed) return;

    if (!_initialized) {
      _placeMines(r, c);
    }

    if (cell.isMine) {
      HapticFeedback.heavyImpact();
      setState(() {
        cell.state = _CellState.revealed;
        _explodeRow = r;
        _explodeCol = c;
      });
      _shakeCtrl.forward(from: 0);
      _triggerGameOver(r, c);
      return;
    }

    setState(() => _reveal(r, c));
    _checkWin();
  }

  void _onLongPress(int r, int c) {
    if (_gameOver || _won) return;
    final cell = _board[r][c];
    if (cell.state == _CellState.revealed) return;
    HapticFeedback.mediumImpact();

    setState(() {
      if (cell.state == _CellState.hidden) {
        if (_flagsLeft > 0) {
          cell.state = _CellState.flagged;
          _flagsLeft--;
        }
      } else if (cell.state == _CellState.flagged) {
        cell.state = _CellState.hidden;
        _flagsLeft++;
      }
    });
    _checkWin();
  }

  void _reveal(int r, int c) {
    if (r < 0 || r >= _cfg.rows || c < 0 || c >= _cfg.cols) return;
    final cell = _board[r][c];
    if (cell.state != _CellState.hidden) return;
    cell.state = _CellState.revealed;
    // Flood fill nếu ô trống
    if (cell.adjacentMines == 0 && !cell.isMine) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          _reveal(r + dr, c + dc);
        }
      }
    }
  }

  void _checkWin() {
    // Win khi tất cả ô không phải mìn đã được reveal
    for (int r = 0; r < _cfg.rows; r++) {
      for (int c = 0; c < _cfg.cols; c++) {
        final cell = _board[r][c];
        if (!cell.isMine && cell.state != _CellState.revealed) return;
      }
    }
    _timer?.cancel();
    // Tính điểm: base + time bonus
    final timeBonus = max(0, _cfg.timeLimit - _elapsed) * 2;
    final base = _cfg.mines * 20;
    _score = base + timeBonus;
    setState(() => _won = true);
    Future.delayed(const Duration(milliseconds: 600), _goToResult);
  }

  void _triggerGameOver(int? r, int? c) {
    _timer?.cancel();
    // Reveal tất cả mìn
    setState(() {
      _gameOver = true;
      for (int row = 0; row < _cfg.rows; row++) {
        for (int col = 0; col < _cfg.cols; col++) {
          if (_board[row][col].isMine) {
            _board[row][col].state = _CellState.revealed;
          }
        }
      }
    });
    Future.delayed(const Duration(milliseconds: 1200), _goToResult);
  }

  void _goToResult() {
    if (!mounted) return;
    final maxScore = _cfg.mines * 20 + _cfg.timeLimit * 2;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GameResultScreen(
          gameType: 'mine_game',
          gameName: '💣 Dò Mìn',
          level: widget.level,
          score: _won ? _score : 0,
          maxScore: maxScore,
          timeSeconds: _elapsed,
          timeLimitSeconds: _cfg.timeLimit,
          color: _color,
          onReplay: (ctx) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(
              builder: (_) => MineGame(level: widget.level),
            ),
          ),
          onNextLevel: (ctx) => Navigator.pushReplacement(
            ctx,
            MaterialPageRoute(
              builder: (_) => MineGame(
                level: widget.level < _configs.length
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

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final remaining = max(0, _cfg.timeLimit - _elapsed);
    final timeColor = remaining <= 30
        ? Colors.red
        : remaining <= 60
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
          '💣 Dò Mìn — Màn ${widget.level}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        actions: [
          // Timer
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_rounded, color: timeColor, size: 15),
                const SizedBox(width: 4),
                Text(
                  '${remaining}s',
                  style: TextStyle(
                      color: timeColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          // Flags
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🚩', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '$_flagsLeft',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: _cfg.timeLimit > 0 ? remaining / _cfg.timeLimit : 0,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(timeColor),
            minHeight: 6,
          ),
        ),
      ),
      body: Column(
        children: [
          // Status bar
          _StatusBar(
            mines: _cfg.mines,
            flagsLeft: _flagsLeft,
            won: _won,
            gameOver: _gameOver,
            color: _color,
          ),
          // Board
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) {
                  final offset = _shakeCtrl.isAnimating
                      ? sin(_shakeCtrl.value * pi * 6) * _shakeAnim.value
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(offset, 0),
                    child: child,
                  );
                },
                child: _BoardWidget(
                  board: _board,
                  rows: _cfg.rows,
                  cols: _cfg.cols,
                  gameOver: _gameOver,
                  won: _won,
                  explodeRow: _explodeRow,
                  explodeCol: _explodeCol,
                  color: _color,
                  onTap: _onTap,
                  onLongPress: _onLongPress,
                ),
              ),
            ),
          ),
          // Hint
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              'Nhấn để mở ô  •  Giữ để cắm cờ 🚩',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Bar ───────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final int mines;
  final int flagsLeft;
  final bool won;
  final bool gameOver;
  final Color color;

  const _StatusBar({
    required this.mines,
    required this.flagsLeft,
    required this.won,
    required this.gameOver,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    String msg;
    Color bg;
    if (won) {
      msg = '🎉 Bạn thắng! Tất cả mìn đã được tìm ra!';
      bg = const Color(0xFF06D6A0);
    } else if (gameOver) {
      msg = '💥 Bùm! Bạn đã đạp phải mìn!';
      bg = const Color(0xFFEF5350);
    } else {
      msg = '💣 $mines mìn  •  🚩 $flagsLeft cờ còn lại';
      bg = color.withValues(alpha: 0.1);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: bg,
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: (won || gameOver) ? Colors.white : color,
        ),
      ),
    );
  }
}

// ─── Board Widget ─────────────────────────────────────────────────────────────

class _BoardWidget extends StatelessWidget {
  final List<List<_Cell>> board;
  final int rows;
  final int cols;
  final bool gameOver;
  final bool won;
  final int? explodeRow;
  final int? explodeCol;
  final Color color;
  final void Function(int r, int c) onTap;
  final void Function(int r, int c) onLongPress;

  const _BoardWidget({
    required this.board,
    required this.rows,
    required this.cols,
    required this.gameOver,
    required this.won,
    required this.explodeRow,
    required this.explodeCol,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final maxW = constraints.maxWidth - 24;
        final maxH = constraints.maxHeight - 24;
        final cellSize = min(maxW / cols, maxH / rows).clamp(28.0, 48.0);

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(rows, (r) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(cols, (c) {
                  return _CellWidget(
                    cell: board[r][c],
                    size: cellSize,
                    isExplode: r == explodeRow && c == explodeCol,
                    color: color,
                    onTap: () => onTap(r, c),
                    onLongPress: () => onLongPress(r, c),
                  );
                }),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─── Cell Widget ──────────────────────────────────────────────────────────────

class _CellWidget extends StatelessWidget {
  final _Cell cell;
  final double size;
  final bool isExplode;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CellWidget({
    required this.cell,
    required this.size,
    required this.isExplode,
    required this.color,
    required this.onTap,
    required this.onLongPress,
  });

  static const _numColors = [
    Colors.transparent,
    Color(0xFF1565C0), // 1 — xanh đậm
    Color(0xFF2E7D32), // 2 — xanh lá
    Color(0xFFC62828), // 3 — đỏ
    Color(0xFF4A148C), // 4 — tím
    Color(0xFF880E4F), // 5 — hồng đậm
    Color(0xFF006064), // 6 — cyan đậm
    Color(0xFF212121), // 7 — đen
    Color(0xFF546E7A), // 8 — xám
  ];

  @override
  Widget build(BuildContext context) {
    final padding = size * 0.06;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size - padding * 2,
          height: size - padding * 2,
          decoration: _buildDecoration(),
          child: Center(child: _buildContent(size)),
        ),
      ),
    );
  }

  BoxDecoration _buildDecoration() {
    if (cell.state == _CellState.hidden || cell.state == _CellState.flagged) {
      return BoxDecoration(
        color: const Color(0xFFB0BEC5),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 2,
            offset: Offset(0, 2),
          ),
        ],
      );
    }
    // Revealed
    if (cell.isMine) {
      return BoxDecoration(
        color: isExplode ? const Color(0xFFEF5350) : const Color(0xFFFFCDD2),
        borderRadius: BorderRadius.circular(6),
      );
    }
    return BoxDecoration(
      color: const Color(0xFFECEFF1),
      borderRadius: BorderRadius.circular(6),
    );
  }

  Widget _buildContent(double size) {
    final fontSize = size * 0.42;

    if (cell.state == _CellState.flagged) {
      return Text('🚩', style: TextStyle(fontSize: fontSize * 0.9));
    }
    if (cell.state == _CellState.hidden) {
      return const SizedBox.shrink();
    }
    // Revealed
    if (cell.isMine) {
      return Text(isExplode ? '💥' : '💣',
          style: TextStyle(fontSize: fontSize * 0.9));
    }
    if (cell.adjacentMines == 0) {
      return const SizedBox.shrink();
    }
    return Text(
      '${cell.adjacentMines}',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: _numColors[cell.adjacentMines.clamp(0, 8)],
      ),
    );
  }
}
