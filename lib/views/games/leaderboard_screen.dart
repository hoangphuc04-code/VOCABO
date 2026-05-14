import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/game_service.dart';

// ignore_for_file: library_private_types_in_public_api

/// 🏆 Bảng Xếp Hạng — xem top người chơi theo từng game và màn

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  static const _games = [
    _GameTab(type: 'speed_quiz', name: '⚡ Trả Lời Nhanh', color: Color(0xFFFFBE0B)),
    _GameTab(type: 'mine_game',  name: '💣 Dò Mìn',        color: Color(0xFF26C6DA)),
    _GameTab(type: 'word_match', name: '🔗 Nối Từ',         color: Color(0xFF06D6A0)),
    _GameTab(type: 'flip_card',  name: '🃏 Lật Thẻ',        color: Color(0xFF4A90D9)),
    _GameTab(type: 'fill_blank', name: '✏️ Điền Từ',        color: Color(0xFFE91E8C)),
  ];

  late TabController _tabCtrl;
  int _selectedLevel = 1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _games.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF667eea),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
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
                        const SizedBox(height: 40),
                        const Text(
                          '🏆 Bảng Xếp Hạng',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Top người chơi xuất sắc nhất',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                        const SizedBox(height: 12),
                        // Level selector
                        _LevelSelector(
                          selected: _selectedLevel,
                          onChanged: (v) => setState(() => _selectedLevel = v),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold),
              tabs: _games
                  .map((g) => Tab(text: g.name))
                  .toList(),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: _games
              .map((g) => _LeaderboardTab(
                    gameType: g.type,
                    color: g.color,
                    level: _selectedLevel,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

// ─── Level Selector ───────────────────────────────────────────────────────────

class _LevelSelector extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _LevelSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 10,
        itemBuilder: (_, i) {
          final level = i + 1;
          final isSelected = level == selected;
          return GestureDetector(
            onTap: () => onChanged(level),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Màn $level',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? const Color(0xFF667eea)
                      : Colors.white,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Leaderboard Tab ──────────────────────────────────────────────────────────

class _LeaderboardTab extends StatefulWidget {
  final String gameType;
  final Color color;
  final int level;

  const _LeaderboardTab({
    required this.gameType,
    required this.color,
    required this.level,
  });

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab>
    with AutomaticKeepAliveClientMixin {
  List<LeaderboardEntry>? _entries;
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => false; // reload khi level thay đổi

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_LeaderboardTab old) {
    super.didUpdateWidget(old);
    if (old.level != widget.level || old.gameType != widget.gameType) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final entries =
          await GameService.getLeaderboard(widget.gameType, widget.level);
      if (mounted) setState(() { _entries = entries; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('😕', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text('Không tải được dữ liệu',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    if (_entries == null || _entries!.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏅', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'Chưa có ai chơi màn này',
              style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Hãy là người đầu tiên!',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final myIndex = _entries!.indexWhere((e) => e.uid == myUid);

    return RefreshIndicator(
      onRefresh: _load,
      color: widget.color,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Top 3 podium
          if (_entries!.length >= 3)
            _Podium(entries: _entries!.take(3).toList(), color: widget.color),

          const SizedBox(height: 16),

          // My rank banner (nếu không trong top 3)
          if (myIndex >= 3)
            _MyRankBanner(
              entry: _entries![myIndex],
              rank: myIndex + 1,
              color: widget.color,
            ),

          if (myIndex >= 3) const SizedBox(height: 12),

          // Full list
          Container(
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
              children: List.generate(_entries!.length, (i) {
                final e = _entries![i];
                final isMe = e.uid == myUid;
                return _RankRow(
                  rank: i + 1,
                  entry: e,
                  isMe: isMe,
                  color: widget.color,
                  isLast: i == _entries!.length - 1,
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Podium (Top 3) ───────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<LeaderboardEntry> entries;
  final Color color;

  const _Podium({required this.entries, required this.color});

  @override
  Widget build(BuildContext context) {
    // Sắp xếp: 2nd, 1st, 3rd
    final order = [1, 0, 2]; // index trong entries
    final heights = [80.0, 110.0, 60.0];
    final medals = ['🥈', '🥇', '🥉'];
    final sizes = [40.0, 52.0, 36.0];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            '🏆 Top 3',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333)),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final idx = order[i];
              if (idx >= entries.length) return const Expanded(child: SizedBox());
              final e = entries[idx];
              return Expanded(
                child: Column(
                  children: [
                    Text(medals[i], style: TextStyle(fontSize: sizes[i] * 0.6)),
                    const SizedBox(height: 4),
                    // Avatar
                    CircleAvatar(
                      radius: sizes[i] / 2,
                      backgroundColor: color.withValues(alpha: 0.15),
                      backgroundImage: e.photoURL.isNotEmpty
                          ? NetworkImage(e.photoURL)
                          : null,
                      child: e.photoURL.isEmpty
                          ? Text(
                              e.name.isNotEmpty ? e.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                  fontSize: sizes[i] * 0.4,
                                  fontWeight: FontWeight.bold,
                                  color: color),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      e.name,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${e.score} đ',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: color),
                    ),
                    const SizedBox(height: 8),
                    // Podium bar
                    Container(
                      height: heights[i],
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8)),
                      ),
                      child: Center(
                        child: Text(
                          '${order[i] + 1}',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: color),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── My Rank Banner ───────────────────────────────────────────────────────────

class _MyRankBanner extends StatelessWidget {
  final LeaderboardEntry entry;
  final int rank;
  final Color color;

  const _MyRankBanner(
      {required this.entry, required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Xếp hạng của bạn',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                Text(
                  entry.name,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${entry.score} điểm',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  3,
                  (s) => Icon(
                    s < entry.stars
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: s < entry.stars
                        ? const Color(0xFFFFBE0B)
                        : Colors.grey.shade300,
                    size: 14,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Rank Row ─────────────────────────────────────────────────────────────────

class _RankRow extends StatelessWidget {
  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;
  final Color color;
  final bool isLast;

  const _RankRow({
    required this.rank,
    required this.entry,
    required this.isMe,
    required this.color,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final medals = {1: '🥇', 2: '🥈', 3: '🥉'};
    final rankLabel = medals[rank] ?? '$rank';

    return Container(
      decoration: BoxDecoration(
        color: isMe ? color.withValues(alpha: 0.06) : null,
        borderRadius: isLast
            ? const BorderRadius.vertical(bottom: Radius.circular(20))
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 36,
                  child: Text(
                    rankLabel,
                    style: TextStyle(
                      fontSize: rank <= 3 ? 20 : 14,
                      fontWeight: FontWeight.bold,
                      color: rank <= 3 ? null : Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 10),
                // Avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withValues(alpha: 0.15),
                  backgroundImage: entry.photoURL.isNotEmpty
                      ? NetworkImage(entry.photoURL)
                      : null,
                  child: entry.photoURL.isEmpty
                      ? Text(
                          entry.name.isNotEmpty
                              ? entry.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: color),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                // Name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              entry.name,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isMe
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Bạn',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      // Stars
                      Row(
                        children: List.generate(
                          3,
                          (s) => Icon(
                            s < entry.stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: s < entry.stars
                                ? const Color(0xFFFFBE0B)
                                : Colors.grey.shade300,
                            size: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Score
                Text(
                  '${entry.score}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isMe ? color : const Color(0xFF333333),
                  ),
                ),
              ],
            ),
          ),
          if (!isLast)
            Divider(
                height: 1,
                indent: 62,
                endIndent: 16,
                color: Colors.grey.shade100),
        ],
      ),
    );
  }
}

// ─── Game Tab config ──────────────────────────────────────────────────────────

class _GameTab {
  final String type;
  final String name;
  final Color color;
  const _GameTab({required this.type, required this.name, required this.color});
}
