import 'package:flutter/material.dart';

class AchievementCard extends StatelessWidget {
  final int streak;
  final int words;
  final double progress;

  const AchievementCard({
    super.key,
    required this.streak,
    required this.words,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Tính kích thước tương đối theo chiều rộng card
        final w = constraints.maxWidth;
        final iconSize = (w * 0.09).clamp(28.0, 44.0);
        final valueFontSize = (w * 0.065).clamp(18.0, 28.0);
        final labelFontSize = (w * 0.032).clamp(10.0, 14.0);
        final titleFontSize = (w * 0.05).clamp(14.0, 20.0);
        final circleSize = (w * 0.14).clamp(48.0, 68.0);

        return Container(
          padding: EdgeInsets.all(w * 0.05),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thành tích',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
              SizedBox(height: w * 0.04),
              Row(
                children: [
                  // ── Streak ──────────────────────────────────────────────
                  Expanded(
                    child: _StatItem(
                      icon: Icons.emoji_events,
                      iconColor: Colors.orange,
                      iconSize: iconSize,
                      value: '$streak',
                      label: 'Streak',
                      valueFontSize: valueFontSize,
                      labelFontSize: labelFontSize,
                      cs: cs,
                    ),
                  ),

                  // Divider
                  Container(
                    width: 1,
                    height: circleSize,
                    color: cs.onSurface.withValues(alpha: 0.08),
                  ),

                  // ── Words ────────────────────────────────────────────────
                  Expanded(
                    child: _StatItem(
                      icon: Icons.bookmark_rounded,
                      iconColor: Colors.blue,
                      iconSize: iconSize,
                      value: '$words',
                      label: 'Từ đã nhớ',
                      valueFontSize: valueFontSize,
                      labelFontSize: labelFontSize,
                      cs: cs,
                    ),
                  ),

                  // Divider
                  Container(
                    width: 1,
                    height: circleSize,
                    color: cs.onSurface.withValues(alpha: 0.08),
                  ),

                  // ── Progress circle ──────────────────────────────────────
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: circleSize,
                          height: circleSize,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: progress.clamp(0.0, 1.0),
                                strokeWidth: circleSize * 0.09,
                                backgroundColor:
                                    cs.onSurface.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF667eea)),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onSurface,
                                  fontSize: labelFontSize * 1.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: w * 0.015),
                        Text(
                          'Tiến bộ',
                          style: TextStyle(
                            fontSize: labelFontSize,
                            color: cs.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Stat Item ────────────────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String value;
  final String label;
  final double valueFontSize;
  final double labelFontSize;
  final ColorScheme cs;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.value,
    required this.label,
    required this.valueFontSize,
    required this.labelFontSize,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: iconSize),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: valueFontSize,
            fontWeight: FontWeight.bold,
            color: cs.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: labelFontSize,
            color: cs.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
