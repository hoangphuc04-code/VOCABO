import 'package:flutter/material.dart';

// ignore_for_file: library_private_types_in_public_api

/// Widget AppBar dùng chung cho các game
class GameAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Color color;
  final int score;
  final int remaining;
  final double progress;
  final int level;

  const GameAppBar({
    super.key,
    required this.title,
    required this.color,
    required this.score,
    required this.remaining,
    required this.progress,
    required this.level,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 6);

  @override
  Widget build(BuildContext context) {
    final timeColor = remaining <= 10
        ? Colors.red
        : remaining <= 20
            ? Colors.orange
            : Colors.white;

    return AppBar(
      backgroundColor: color,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      actions: [
        // Timer
        Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.timer_rounded, color: timeColor, size: 16),
              const SizedBox(width: 4),
              Text(
                '${remaining}s',
                style: TextStyle(
                  color: timeColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Score
        Container(
          margin: const EdgeInsets.only(right: 12),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '$score',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
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
    );
  }
}

/// Level selector dùng chung
class LevelSelectorSheet extends StatelessWidget {
  final String gameType;
  final String gameName;
  final Color color;
  final Map<int, dynamic> progress; // level -> LevelProgress
  final int totalLevels;
  final void Function(int level) onSelect;

  const LevelSelectorSheet({
    super.key,
    required this.gameType,
    required this.gameName,
    required this.color,
    required this.progress,
    required this.totalLevels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF0F2F8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    gameName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${progress.length}/$totalLevels màn',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                controller: ctrl,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: totalLevels,
                itemBuilder: (_, i) {
                  final level = i + 1;
                  final prog = progress[level];
                  final stars = prog?.stars ?? 0;
                  final isUnlocked = level == 1 || (progress[level - 1]?.isCompleted ?? false);

                  return GestureDetector(
                    onTap: isUnlocked ? () => onSelect(level) : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isUnlocked ? Colors.white : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: stars > 0 ? color : Colors.grey.shade300,
                          width: stars > 0 ? 2 : 1,
                        ),
                        boxShadow: isUnlocked
                            ? [
                                BoxShadow(
                                  color: color.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isUnlocked)
                            Icon(Icons.lock_rounded, color: Colors.grey.shade400, size: 20)
                          else
                            Text(
                              '$level',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          if (isUnlocked && stars > 0) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                3,
                                (s) => Icon(
                                  s < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                                  color: s < stars ? const Color(0xFFFFBE0B) : Colors.grey.shade300,
                                  size: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
