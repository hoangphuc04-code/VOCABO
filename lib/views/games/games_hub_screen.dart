import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/game_service.dart';
import 'game_data.dart';
import 'game_widgets.dart';
import 'speed_quiz_game.dart';
import 'mine_game.dart';
import 'word_match_game.dart';
import 'flip_card_game.dart';
import 'fill_blank_game.dart';
import 'leaderboard_screen.dart';

// ignore_for_file: library_private_types_in_public_api

/// 🎮 Games Hub — màn hình chọn game
class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({super.key});

  @override
  State<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends State<GamesHubScreen> {
  Map<int, LevelProgress> _speedQuizProgress = {};
  Map<int, LevelProgress> _mineProgress = {};
  Map<int, LevelProgress> _wordMatchProgress = {};
  Map<int, LevelProgress> _flipCardProgress = {};
  Map<int, LevelProgress> _fillBlankProgress = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final results = await Future.wait([
      GameService.getLevelProgress('speed_quiz'),
      GameService.getLevelProgress('mine_game'),
      GameService.getLevelProgress('word_match'),
      GameService.getLevelProgress('flip_card'),
      GameService.getLevelProgress('fill_blank'),
    ]);
    if (mounted) {
      setState(() {
        _speedQuizProgress = results[0];
        _mineProgress = results[1];
        _wordMatchProgress = results[2];
        _flipCardProgress = results[3];
        _fillBlankProgress = results[4];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: CustomScrollView(
        slivers: [
          // ── Header ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 150,
            pinned: true,
            backgroundColor: const Color(0xFF667eea),
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🎮 Mini Games',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Học từ vựng qua trò chơi thú vị',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // Coin display
                            StreamBuilder<int>(
                              stream: GameService.coinsStream(),
                              builder: (_, snap) {
                                final coins = snap.data ?? 0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🪙',
                                          style: TextStyle(fontSize: 15)),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$coins coins',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            // Leaderboard button
                            GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LeaderboardScreen(),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('🏆',
                                        style: TextStyle(fontSize: 15)),
                                    SizedBox(width: 6),
                                    Text(
                                      'Xếp hạng',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Game cards ───────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                const _SectionTitle('🕹️ Trò chơi'),
                const SizedBox(height: 12),

                // ── Speed Quiz ──────────────────────────────────────────────
                _GameCard(
                  emoji: '⚡',
                  title: 'Trả Lời Nhanh',
                  description: 'Chọn nghĩa đúng trong thời gian giới hạn',
                  color: const Color(0xFFFFBE0B),
                  totalLevels: GameData.totalLevels,
                  completedLevels: _speedQuizProgress.values
                      .where((p) => p.isCompleted)
                      .length,
                  loading: _loading,
                  onPlay: () => _showLevelSelector(
                    context,
                    gameType: 'speed_quiz',
                    gameName: '⚡ Trả Lời Nhanh',
                    color: const Color(0xFFFFBE0B),
                    progress: _speedQuizProgress,
                    onSelect: (level) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => SpeedQuizGame(level: level)),
                      ).then((_) => _loadProgress());
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ── Dò Mìn ─────────────────────────────────────────────────
                _GameCard(
                  emoji: '💣',
                  title: 'Dò Mìn',
                  description: 'Tìm tất cả mìn mà không bị nổ',
                  color: const Color(0xFF26C6DA),
                  totalLevels: 10,
                  completedLevels: _mineProgress.values
                      .where((p) => p.isCompleted)
                      .length,
                  loading: _loading,
                  onPlay: () => _showLevelSelector(
                    context,
                    gameType: 'mine_game',
                    gameName: '💣 Dò Mìn',
                    color: const Color(0xFF26C6DA),
                    progress: _mineProgress,
                    totalLevels: 10,
                    onSelect: (level) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => MineGame(level: level)),
                      ).then((_) => _loadProgress());
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ── Nối Từ ──────────────────────────────────────────────────
                _GameCard(
                  emoji: '🔗',
                  title: 'Nối Từ',
                  description: 'Nối từ tiếng Anh với nghĩa tiếng Việt',
                  color: const Color(0xFF06D6A0),
                  totalLevels: GameData.totalLevels,
                  completedLevels: _wordMatchProgress.values
                      .where((p) => p.isCompleted)
                      .length,
                  loading: _loading,
                  onPlay: () => _showLevelSelector(
                    context,
                    gameType: 'word_match',
                    gameName: '🔗 Nối Từ',
                    color: const Color(0xFF06D6A0),
                    progress: _wordMatchProgress,
                    onSelect: (level) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => WordMatchGame(level: level)),
                      ).then((_) => _loadProgress());
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ── Lật Thẻ ─────────────────────────────────────────────────
                _GameCard(
                  emoji: '🃏',
                  title: 'Lật Thẻ',
                  description: 'Lật thẻ tìm cặp từ — nghĩa tương ứng',
                  color: const Color(0xFF4A90D9),
                  totalLevels: GameData.totalLevels,
                  completedLevels: _flipCardProgress.values
                      .where((p) => p.isCompleted)
                      .length,
                  loading: _loading,
                  onPlay: () => _showLevelSelector(
                    context,
                    gameType: 'flip_card',
                    gameName: '🃏 Lật Thẻ',
                    color: const Color(0xFF4A90D9),
                    progress: _flipCardProgress,
                    onSelect: (level) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => FlipCardGame(level: level)),
                      ).then((_) => _loadProgress());
                    },
                  ),
                ),
                const SizedBox(height: 12),

                // ── Điền Từ ─────────────────────────────────────────────────
                _GameCard(
                  emoji: '✏️',
                  title: 'Điền Từ',
                  description: 'Gõ từ tiếng Anh từ gợi ý nghĩa tiếng Việt',
                  color: const Color(0xFFE91E8C),
                  totalLevels: GameData.totalLevels,
                  completedLevels: _fillBlankProgress.values
                      .where((p) => p.isCompleted)
                      .length,
                  loading: _loading,
                  onPlay: () => _showLevelSelector(
                    context,
                    gameType: 'fill_blank',
                    gameName: '✏️ Điền Từ',
                    color: const Color(0xFFE91E8C),
                    progress: _fillBlankProgress,
                    onSelect: (level) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => FillBlankGame(level: level)),
                      ).then((_) => _loadProgress());
                    },
                  ),
                ),

                const SizedBox(height: 24),

                // ── Leaderboard shortcut ─────────────────────────────────────
                const _SectionTitle('🏆 Bảng xếp hạng'),
                const SizedBox(height: 12),
                _LeaderboardShortcut(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const LeaderboardScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                const _LeaderboardPreview(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showLevelSelector(
    BuildContext context, {
    required String gameType,
    required String gameName,
    required Color color,
    required Map<int, LevelProgress> progress,
    int? totalLevels,
    required void Function(int) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LevelSelectorSheet(
        gameType: gameType,
        gameName: gameName,
        color: color,
        progress: progress,
        totalLevels: totalLevels ?? GameData.totalLevels,
        onSelect: onSelect,
      ),
    );
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333))),
      ],
    );
  }
}

// ─── Game Card ────────────────────────────────────────────────────────────────

class _GameCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final int totalLevels;
  final int completedLevels;
  final bool loading;
  final VoidCallback onPlay;

  const _GameCard({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    required this.totalLevels,
    required this.completedLevels,
    required this.loading,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final pct = totalLevels > 0 ? completedLevels / totalLevels : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            // Emoji icon
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 30)),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: pct,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation(color),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$completedLevels/$totalLevels',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Play button
            GestureDetector(
              onTap: onPlay,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Leaderboard Shortcut ─────────────────────────────────────────────────────

class _LeaderboardShortcut extends StatelessWidget {
  final VoidCallback onTap;
  const _LeaderboardShortcut({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF667eea).withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Text('🏆', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Xem bảng xếp hạng đầy đủ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Top người chơi tất cả game & màn',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Leaderboard Preview ──────────────────────────────────────────────────────

class _LeaderboardPreview extends StatefulWidget {
  const _LeaderboardPreview();

  @override
  State<_LeaderboardPreview> createState() => _LeaderboardPreviewState();
}

class _LeaderboardPreviewState extends State<_LeaderboardPreview> {
  List<LeaderboardEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await GameService.getLeaderboard('speed_quiz', 1);
      if (mounted) {
        setState(() {
          _entries = entries.take(5).toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: Text('Chưa có dữ liệu xếp hạng',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Text('⚡ Trả Lời Nhanh — Màn 1',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
          const Divider(height: 1),
          ...List.generate(_entries.length, (i) {
            final e = _entries[i];
            final isMe = e.uid == myUid;
            final medals = ['🥇', '🥈', '🥉'];
            final rank = i < 3 ? medals[i] : '${i + 1}';

            return Container(
              color: isMe
                  ? const Color(0xFF667eea).withValues(alpha: 0.06)
                  : null,
              child: ListTile(
                dense: true,
                leading: Text(rank,
                    style: TextStyle(
                        fontSize: i < 3 ? 20 : 14,
                        fontWeight: FontWeight.bold)),
                title: Text(
                  e.name,
                  style: TextStyle(
                    fontWeight:
                        isMe ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ...List.generate(
                      3,
                      (s) => Icon(
                        s < e.stars
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: s < e.stars
                            ? const Color(0xFFFFBE0B)
                            : Colors.grey.shade300,
                        size: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${e.score}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
