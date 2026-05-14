import 'package:flutter/material.dart';
import '../../data/services/game_service.dart';

// ignore_for_file: library_private_types_in_public_api

/// Màn hình kết quả chung cho tất cả game
class GameResultScreen extends StatefulWidget {
  final String gameType;
  final String gameName;
  final int level;
  final int score;
  final int maxScore;
  final int timeSeconds;
  final int timeLimitSeconds;
  final Color color;
  final void Function(BuildContext ctx) onReplay;
  final void Function(BuildContext ctx) onNextLevel;
  final void Function(BuildContext ctx) onHome;

  const GameResultScreen({
    super.key,
    required this.gameType,
    required this.gameName,
    required this.level,
    required this.score,
    required this.maxScore,
    required this.timeSeconds,
    required this.timeLimitSeconds,
    required this.color,
    required this.onReplay,
    required this.onNextLevel,
    required this.onHome,
  });

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  int _coinsEarned = 0;
  int _stars = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _scaleAnim = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);

    _stars = _calcStars();
    _saveAndReward();
  }

  int _calcStars() {
    final pct = widget.maxScore > 0 ? widget.score / widget.maxScore : 0.0;
    if (pct >= 0.85) return 3;
    if (pct >= 0.6) return 2;
    if (pct > 0) return 1;
    return 0;
  }

  Future<void> _saveAndReward() async {
    final coins = GameService.coinReward(widget.level, _stars);
    if (coins > 0) await GameService.addCoins(coins);
    await GameService.saveLevel(
      gameType: widget.gameType,
      level: widget.level,
      stars: _stars,
      score: widget.score,
      timeSeconds: widget.timeSeconds,
    );
    if (mounted) setState(() => _coinsEarned = coins);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pct = widget.maxScore > 0
        ? (widget.score / widget.maxScore).clamp(0.0, 1.0)
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Game name
              Text(
                widget.gameName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
              Text(
                'Màn ${widget.level}',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),

              // Score card
              ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: widget.color.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Stars
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final filled = i < _stars;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(
                              filled ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: filled ? const Color(0xFFFFBE0B) : Colors.grey.shade300,
                              size: 44,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // Score
                      Text(
                        '${widget.score}',
                        style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          color: widget.color,
                        ),
                      ),
                      Text(
                        'điểm / ${widget.maxScore}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 16),

                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: pct,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(widget.color),
                          minHeight: 10,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Stats row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatChip(
                            icon: '⏱️',
                            label: 'Thời gian',
                            value: '${widget.timeSeconds}s',
                          ),
                          _StatChip(
                            icon: '🪙',
                            label: 'Coin nhận',
                            value: '+$_coinsEarned',
                            valueColor: const Color(0xFFFFBE0B),
                          ),
                          _StatChip(
                            icon: '⭐',
                            label: 'Sao',
                            value: '$_stars/3',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _ResultBtn(
                      label: '🏠 Thoát',
                      color: Colors.grey.shade200,
                      textColor: Colors.grey.shade700,
                      onTap: () => widget.onHome(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ResultBtn(
                      label: '🔄 Chơi lại',
                      color: widget.color.withValues(alpha: 0.15),
                      textColor: widget.color,
                      onTap: () => widget.onReplay(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ResultBtn(
                      label: '▶️ Tiếp',
                      color: widget.color,
                      textColor: Colors.white,
                      onTap: () => widget.onNextLevel(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF333333),
          ),
        ),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
      ],
    );
  }
}

class _ResultBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;

  const _ResultBtn({
    required this.label,
    required this.color,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
