import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Admin: Quản lý tính năng mới — Word Stories, Daily Challenge, Conversations
class ManageNewFeaturesScreen extends StatefulWidget {
  const ManageNewFeaturesScreen({super.key});

  @override
  State<ManageNewFeaturesScreen> createState() =>
      _ManageNewFeaturesScreenState();
}

class _ManageNewFeaturesScreenState extends State<ManageNewFeaturesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
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
        // Tab bar
        Container(
          color: const Color(0xFF1A1A2E),
          child: TabBar(
            controller: _tab,
            isScrollable: true,
            indicatorColor: const Color(0xFF667eea),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white38,
            tabs: const [
              Tab(text: '📖 Word Stories'),
              Tab(text: '🏆 Daily Challenge'),
              Tab(text: '🤖 AI Conversations'),
              Tab(text: '📊 SRS Insights'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: const [
              _WordStoriesTab(),
              _DailyChallengeTab(),
              _ConversationsTab(),
              _SrsInsightsTab(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Word Stories Tab ─────────────────────────────────────────────────────────

class _WordStoriesTab extends StatelessWidget {
  const _WordStoriesTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('word_stories')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('📖', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Chưa có câu chuyện nào',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return Column(
          children: [
            // Stats bar
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF667eea).withOpacity(0.05),
              child: Row(
                children: [
                  _StatPill('📖 Tổng', '${docs.length}', const Color(0xFF667eea)),
                  const SizedBox(width: 8),
                  _StatPill('👥 Users', '${docs.map((d) => (d.data() as Map)['uid']).toSet().length}', Colors.green),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final words = (d['words'] as List? ?? []).join(', ');
                  final date = d['createdAt'] != null
                      ? DateFormat('dd/MM/yyyy HH:mm')
                          .format((d['createdAt'] as Timestamp).toDate())
                      : '';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                d['title'] as String? ?? 'Untitled',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red, size: 18),
                              onPressed: () => _deleteStory(docs[i].id),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Từ: $words',
                          style: const TextStyle(
                              color: Color(0xFF667eea), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          d['story'] as String? ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(date,
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 11)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteStory(String id) async {
    await FirebaseFirestore.instance
        .collection('word_stories')
        .doc(id)
        .delete();
  }
}

// ─── Daily Challenge Tab ──────────────────────────────────────────────────────

class _DailyChallengeTab extends StatefulWidget {
  const _DailyChallengeTab();

  @override
  State<_DailyChallengeTab> createState() => _DailyChallengeTabState();
}

class _DailyChallengeTabState extends State<_DailyChallengeTab> {
  String _dateFilter = _todayKey();

  static String _todayKey() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date filter
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Ngày: ',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: _dateFilter),
                  decoration: InputDecoration(
                    hintText: 'YYYY-MM-DD',
                    isDense: true,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  onSubmitted: (v) => setState(() => _dateFilter = v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => setState(() => _dateFilter = _todayKey()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Hôm nay'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('daily_challenge_scores')
                .where('date', isEqualTo: _dateFilter)
                .orderBy('score', descending: true)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Center(
                  child: Text('Không có dữ liệu cho ngày $_dateFilter',
                      style: const TextStyle(color: Colors.grey)),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final medals = ['🥇', '🥈', '🥉'];
                  final rank = i < 3 ? medals[i] : '${i + 1}';
                  return ListTile(
                    leading: Text(rank,
                        style: const TextStyle(fontSize: 20)),
                    title: Text(
                      d['displayName'] as String? ?? 'User',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(d['type'] as String? ?? ''),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${d['score']} điểm',
                        style: const TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─── Conversations Tab ────────────────────────────────────────────────────────

class _ConversationsTab extends StatelessWidget {
  const _ConversationsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('conversation_sessions')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        // Aggregate by scenario
        final scenarioCounts = <String, int>{};
        for (final d in docs) {
          final scenario =
              (d.data() as Map<String, dynamic>)['scenario'] as String? ??
                  'unknown';
          scenarioCounts[scenario] = (scenarioCounts[scenario] ?? 0) + 1;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary cards
              const Text('Thống kê theo kịch bản:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: scenarioCounts.entries.map((e) {
                  final emojis = {
                    'freeChat': '💬',
                    'restaurant': '🍽️',
                    'jobInterview': '💼',
                    'shopping': '🛍️',
                    'travel': '✈️',
                  };
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF667eea).withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        Text(emojis[e.key] ?? '🤖',
                            style: const TextStyle(fontSize: 24)),
                        const SizedBox(height: 4),
                        Text(e.key,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.grey)),
                        Text('${e.value}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667eea))),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text('Tổng phiên: ${docs.length}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              ...docs.take(20).map((doc) {
                final d = doc.data() as Map<String, dynamic>;
                final date = d['createdAt'] != null
                    ? DateFormat('dd/MM HH:mm')
                        .format((d['createdAt'] as Timestamp).toDate())
                    : '';
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Row(
                    children: [
                      Text(
                        {'freeChat': '💬', 'restaurant': '🍽️', 'jobInterview': '💼', 'shopping': '🛍️', 'travel': '✈️'}[d['scenario']] ?? '🤖',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(d['scenario'] as String? ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(
                                '${d['messageCount'] ?? 0} tin nhắn · $date',
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
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
  }
}

// ─── SRS Insights Tab ─────────────────────────────────────────────────────────

class _SrsInsightsTab extends StatelessWidget {
  const _SrsInsightsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('srs_mistakes')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .snapshots(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snap.data!.docs;

        // Aggregate mistakes by word
        final wordCounts = <String, int>{};
        for (final d in docs) {
          final word =
              (d.data() as Map<String, dynamic>)['word'] as String? ?? '';
          if (word.isNotEmpty) {
            wordCounts[word] = (wordCounts[word] ?? 0) + 1;
          }
        }
        final sorted = wordCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatPill('📊 Tổng lỗi', '${docs.length}', Colors.red),
                  const SizedBox(width: 8),
                  _StatPill('📝 Từ bị sai', '${wordCounts.length}', Colors.orange),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Top từ bị sai nhiều nhất:',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              ...sorted.take(20).map((e) {
                final pct = e.value / (sorted.first.value);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(
                          e.key,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                      Expanded(
                        child: Stack(
                          children: [
                            Container(
                              height: 20,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct,
                              child: Container(
                                height: 20,
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${e.value}x',
                          style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
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
