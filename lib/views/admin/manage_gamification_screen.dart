import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Admin: Quản lý Gamification — Games, Farm/House, Friends/Chat
class ManageGamificationScreen extends StatefulWidget {
  const ManageGamificationScreen({super.key});

  @override
  State<ManageGamificationScreen> createState() =>
      _ManageGamificationScreenState();
}

class _ManageGamificationScreenState extends State<ManageGamificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: const Color(0xFF1A1A2E),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: const Color(0xFF667eea),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(text: '🎮 Games'),
              Tab(text: '🌿 Farm & House'),
              Tab(text: '👥 Bạn bè & Chat'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _GamesTab(),
              _FarmHouseTab(),
              _SocialTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Games Tab ────────────────────────────────────────────────────────────────

class _GamesTab extends StatelessWidget {
  const _GamesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('game_progress')
          .orderBy('completedAt', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        // Aggregate by game type
        final typeCounts = <String, int>{};
        final typeScores = <String, List<int>>{};
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final type = data['gameType'] as String? ?? 'unknown';
          typeCounts[type] = (typeCounts[type] ?? 0) + 1;
          typeScores.putIfAbsent(type, () => []);
          typeScores[type]!.add((data['score'] as num?)?.toInt() ?? 0);
        }

        final gameEmojis = {
          'speed_quiz': '⚡',
          'word_connect': '🔗',
          'memory_match': '🃏',
          'word_search': '🔍',
          'anagram': '🧩',
        };
        final gameLabels = {
          'speed_quiz': 'Speed Quiz',
          'word_connect': 'Nối Từ',
          'memory_match': 'Lật Thẻ',
          'word_search': 'Tìm Từ',
          'anagram': 'Sắp Xếp',
        };

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary
              Row(
                children: [
                  _StatPill('🎮 Tổng sessions', '${docs.length}',
                      const Color(0xFF667eea)),
                  const SizedBox(width: 8),
                  _StatPill('👥 Người chơi',
                      '${docs.map((d) => (d.data() as Map)['uid']).toSet().length}',
                      Colors.green),
                ],
              ),
              const SizedBox(height: 16),

              // Game type breakdown
              const Text('Thống kê theo loại game:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: typeCounts.entries.map((e) {
                  final scores = typeScores[e.key] ?? [];
                  final avg = scores.isEmpty
                      ? 0
                      : scores.reduce((a, b) => a + b) ~/ scores.length;
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF667eea).withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(gameEmojis[e.key] ?? '🎮',
                            style: const TextStyle(fontSize: 28)),
                        const SizedBox(height: 4),
                        Text(gameLabels[e.key] ?? e.key,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        Text('${e.value} lần',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667eea))),
                        Text('TB: $avg/10',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey)),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              // Top players
              const Text('Top người chơi (Speed Quiz):',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 8),
              ...docs
                  .where((d) =>
                      (d.data() as Map<String, dynamic>)['gameType'] ==
                      'speed_quiz')
                  .take(15)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) {
                final i = entry.key;
                final d = entry.value.data() as Map<String, dynamic>;
                final medals = ['🥇', '🥈', '🥉'];
                final rank = i < 3 ? medals[i] : '${i + 1}';
                final date = d['completedAt'] != null
                    ? DateFormat('dd/MM HH:mm')
                        .format((d['completedAt'] as Timestamp).toDate())
                    : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Text(rank,
                          style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Màn ${d['level'] ?? 1} · ${d['score'] ?? 0}/10',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13),
                            ),
                            Text(
                              '${(d['uid'] as String? ?? '').substring(0, 8)}... · $date',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: List.generate(
                          3,
                          (s) => Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: s < (d['stars'] ?? 0)
                                ? Colors.amber
                                : Colors.grey.shade200,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Farm & House Tab ─────────────────────────────────────────────────────────

class _FarmHouseTab extends StatelessWidget {
  const _FarmHouseTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('farms').snapshots(),
      builder: (context, farmSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('houses').snapshots(),
          builder: (context, houseSnap) {
            final farmCount = farmSnap.data?.docs.length ?? 0;
            final houseCount = houseSnap.data?.docs.length ?? 0;

            // Aggregate farm stats
            int totalPlots = 0, totalAnimals = 0, totalFish = 0;
            if (farmSnap.hasData) {
              for (final doc in farmSnap.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                totalPlots +=
                    ((d['plots'] as List?)?.length ?? 0) as int;
                totalAnimals +=
                    ((d['animals'] as List?)?.length ?? 0) as int;
                totalFish +=
                    ((d['fishPond'] as List?)?.length ?? 0) as int;
              }
            }

            // Aggregate house stats
            int totalItems = 0;
            final petTypes = <String, int>{};
            if (houseSnap.hasData) {
              for (final doc in houseSnap.data!.docs) {
                final d = doc.data() as Map<String, dynamic>;
                totalItems +=
                    ((d['placedItems'] as List?)?.length ?? 0) as int;
                final petType =
                    (d['pet'] as Map?)?['type'] as String? ?? 'cat';
                petTypes[petType] = (petTypes[petType] ?? 0) + 1;
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Stats
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatPill('🌿 Nông trại', '$farmCount',
                          Colors.green),
                      _StatPill('🏡 Nhà', '$houseCount', Colors.blue),
                      _StatPill('🌱 Ô đất', '$totalPlots',
                          Colors.teal),
                      _StatPill('🐄 Động vật', '$totalAnimals',
                          Colors.orange),
                      _StatPill('🐟 Hồ cá', '$totalFish',
                          Colors.cyan),
                      _StatPill('🛋️ Vật phẩm', '$totalItems',
                          Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Pet distribution
                  if (petTypes.isNotEmpty) ...[
                    const Text('Phân bố thú cưng:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: petTypes.entries.map((e) {
                        final emojis = {
                          'cat': '🐱',
                          'dog': '🐶',
                          'rabbit': '🐰',
                          'hamster': '🐹',
                        };
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              Text(emojis[e.key] ?? '🐾',
                                  style:
                                      const TextStyle(fontSize: 28)),
                              Text(e.key,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey)),
                              Text('${e.value}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.amber)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Recent farms
                  const Text('Nông trại gần đây:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (!farmSnap.hasData)
                    const Center(child: CircularProgressIndicator())
                  else if (farmSnap.data!.docs.isEmpty)
                    const Text('Chưa có nông trại nào',
                        style: TextStyle(color: Colors.grey))
                  else
                    ...farmSnap.data!.docs.take(10).map((doc) {
                      final d = doc.data() as Map<String, dynamic>;
                      final plots =
                          (d['plots'] as List?)?.length ?? 0;
                      final animals =
                          (d['animals'] as List?)?.length ?? 0;
                      final fish =
                          (d['fishPond'] as List?)?.length ?? 0;
                      final coins = d['coins'] ?? 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border:
                              Border.all(color: Colors.grey.shade100),
                        ),
                        child: Row(
                          children: [
                            const Text('🌿',
                                style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${doc.id.substring(0, 8)}...',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                        fontFamily: 'monospace'),
                                  ),
                                  Text(
                                    '🌱 $plots ô · 🐄 $animals · 🐟 $fish · 🪙 $coins',
                                    style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Social Tab ───────────────────────────────────────────────────────────────

class _SocialTab extends StatelessWidget {
  const _SocialTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friendships')
          .limit(100)
          .snapshots(),
      builder: (context, friendSnap) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('friend_requests')
              .where('status', isEqualTo: 'pending')
              .snapshots(),
          builder: (context, reqSnap) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .limit(50)
                  .snapshots(),
              builder: (context, convSnap) {
                final friendCount =
                    friendSnap.data?.docs.length ?? 0;
                final pendingReqs =
                    reqSnap.data?.docs.length ?? 0;
                final convCount =
                    convSnap.data?.docs.length ?? 0;

                // Count messages per conversation
                final convDocs = convSnap.data?.docs ?? [];

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stats
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _StatPill(
                              '🤝 Kết bạn', '$friendCount', Colors.blue),
                          _StatPill('📬 Lời mời chờ', '$pendingReqs',
                              Colors.orange),
                          _StatPill(
                              '💬 Cuộc trò chuyện', '$convCount', Colors.purple),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Friendships list
                      const Text('Danh sách kết bạn:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (!friendSnap.hasData)
                        const Center(child: CircularProgressIndicator())
                      else if (friendSnap.data!.docs.isEmpty)
                        const Text('Chưa có kết bạn nào',
                            style: TextStyle(color: Colors.grey))
                      else
                        ...friendSnap.data!.docs.take(20).map((doc) {
                          final d =
                              doc.data() as Map<String, dynamic>;
                          final uids =
                              (d['uids'] as List?)?.cast<String>() ??
                                  [];
                          final date = d['createdAt'] != null
                              ? DateFormat('dd/MM/yyyy').format(
                                  (d['createdAt'] as Timestamp)
                                      .toDate())
                              : '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                const Text('🤝',
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        uids.length >= 2
                                            ? '${uids[0].substring(0, 8)}... ↔ ${uids[1].substring(0, 8)}...'
                                            : doc.id,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            fontFamily: 'monospace'),
                                      ),
                                      if (date.isNotEmpty)
                                        Text(date,
                                            style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 11)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18),
                                  onPressed: () => FirebaseFirestore
                                      .instance
                                      .collection('friendships')
                                      .doc(doc.id)
                                      .delete(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 20),

                      // Pending requests
                      Row(
                        children: [
                          const Text('Lời mời đang chờ:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14)),
                          const SizedBox(width: 8),
                          if (pendingReqs > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$pendingReqs',
                                style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!reqSnap.hasData)
                        const Center(child: CircularProgressIndicator())
                      else if (reqSnap.data!.docs.isEmpty)
                        const Text('Không có lời mời nào đang chờ',
                            style: TextStyle(color: Colors.grey))
                      else
                        ...reqSnap.data!.docs.take(10).map((doc) {
                          final d =
                              doc.data() as Map<String, dynamic>;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      Colors.orange.withOpacity(0.2)),
                            ),
                            child: Row(
                              children: [
                                const Text('📬',
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    '${d['fromName'] ?? 'Unknown'} → ${(d['toUid'] as String? ?? '').substring(0, 8)}...',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 18),
                                  onPressed: () => FirebaseFirestore
                                      .instance
                                      .collection('friend_requests')
                                      .doc(doc.id)
                                      .delete(),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          );
                        }),

                      const SizedBox(height: 20),

                      // Conversations
                      const Text('Cuộc trò chuyện:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      if (convDocs.isEmpty)
                        const Text('Chưa có cuộc trò chuyện nào',
                            style: TextStyle(color: Colors.grey))
                      else
                        ...convDocs.take(10).map((doc) {
                          final d =
                              doc.data() as Map<String, dynamic>;
                          final participants =
                              (d['participants'] as List?)
                                      ?.cast<String>() ??
                                  [];
                          final lastMsg =
                              d['lastMessage'] as String? ?? '';
                          final date = d['lastMessageAt'] != null
                              ? DateFormat('dd/MM HH:mm').format(
                                  (d['lastMessageAt'] as Timestamp)
                                      .toDate())
                              : '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Colors.grey.shade100),
                            ),
                            child: Row(
                              children: [
                                const Text('💬',
                                    style: TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        participants.length >= 2
                                            ? '${participants[0].substring(0, 6)}... ↔ ${participants[1].substring(0, 6)}...'
                                            : doc.id,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                            fontFamily: 'monospace'),
                                      ),
                                      if (lastMsg.isNotEmpty)
                                        Text(
                                          '"$lastMsg" · $date',
                                          style: const TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11),
                                          maxLines: 1,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
