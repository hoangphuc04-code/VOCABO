import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/mission_service.dart';

/// 📋 Màn hình nhiệm vụ
class MissionScreen extends StatefulWidget {
  const MissionScreen({super.key});

  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF667eea);

  late TabController _tabCtrl;
  Timer? _countdownTimer;
  Duration _timeUntilReset = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _startCountdown();
    MissionService.generateDailyMissions();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _updateCountdown();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateCountdown();
    });
  }

  void _updateCountdown() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    if (mounted) {
      setState(() => _timeUntilReset = midnight.difference(now));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: _primary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('📋 Nhiệm vụ',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 48),
                    child: _CountdownWidget(timeLeft: _timeUntilReset),
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: '📋 Hôm nay'),
                Tab(text: '📜 Lịch sử'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            _TodayMissionsTab(),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Countdown Widget ─────────────────────────────────────────────────────────

class _CountdownWidget extends StatelessWidget {
  final Duration timeLeft;
  const _CountdownWidget({required this.timeLeft});

  @override
  Widget build(BuildContext context) {
    final h = timeLeft.inHours.toString().padLeft(2, '0');
    final m = (timeLeft.inMinutes % 60).toString().padLeft(2, '0');
    final s = (timeLeft.inSeconds % 60).toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          Text(
            'Reset sau $h:$m:$s',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ─── Today Missions Tab ───────────────────────────────────────────────────────

class _TodayMissionsTab extends StatelessWidget {
  const _TodayMissionsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MissionData>>(
      stream: MissionService.missionsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final missions = snap.data ?? [];
        if (missions.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📋', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Đang tải nhiệm vụ...',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        final completed = missions.where((m) => m.isCompleted).length;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Progress summary
            _MissionSummary(completed: completed, total: missions.length),
            const SizedBox(height: 16),
            // Mission cards
            ...missions.map((m) => _MissionCard(mission: m)),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }
}

class _MissionSummary extends StatelessWidget {
  final int completed;
  final int total;
  const _MissionSummary({required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF06D6A0)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$completed/$total nhiệm vụ hoàn thành',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? completed / total : 0,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor:
                        const AlwaysStoppedAnimation(Colors.white),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            completed == total && total > 0 ? '🎉' : '⚔️',
            style: const TextStyle(fontSize: 36),
          ),
        ],
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  final MissionData mission;
  const _MissionCard({required this.mission});

  static const _typeIcons = {
    'delivery': '🚚',
    'harvest': '🌾',
    'collect': '🧺',
    'sell': '🏪',
  };

  @override
  Widget build(BuildContext context) {
    final icon = _typeIcons[mission.type] ?? '📋';
    final isExpired = mission.isExpired;

    Color borderColor;
    if (mission.isCompleted) {
      borderColor = const Color(0xFF06D6A0);
    } else if (isExpired) {
      borderColor = Colors.grey;
    } else if (mission.canComplete) {
      borderColor = const Color(0xFFFFBE0B);
    } else {
      borderColor = Colors.transparent;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mission.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(mission.description,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                // Reward
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 2),
                        Text(
                          '+${mission.reward.coins}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF9F1C),
                              fontSize: 13),
                        ),
                      ],
                    ),
                    Text(
                      '+${mission.reward.xp} XP',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF667eea),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${mission.progress}/${mission.requirement.amount} ${mission.requirement.itemType}',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600),
                          ),
                          Text(
                            '${(mission.progressPercent * 100).toInt()}%',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667eea)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: mission.progressPercent,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation(
                            mission.isCompleted
                                ? const Color(0xFF06D6A0)
                                : const Color(0xFF667eea),
                          ),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Complete button
                if (mission.isCompleted)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF06D6A0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('✅ Xong',
                        style: TextStyle(
                            color: Color(0xFF06D6A0),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  )
                else if (isExpired)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('⏰ Hết hạn',
                        style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  )
                else if (mission.canComplete)
                  GestureDetector(
                    onTap: () async {
                      final ok = await MissionService.completeMission(
                          mission.id);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Không đủ điều kiện hoàn thành')),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFBE0B),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFBE0B).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Text('Hoàn thành!',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatefulWidget {
  const _HistoryTab();

  @override
  State<_HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<_HistoryTab> {
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await MissionService.getMissionHistory();
    if (mounted) setState(() {
      _history = h;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📜', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('Chưa có lịch sử nhiệm vụ',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, i) {
        final entry = _history[i];
        final date = entry['date'] as String;
        final missions = entry['missions'] as List<MissionData>;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '📅 $date',
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea)),
              ),
            ),
            ...missions.map((m) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF06D6A0).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Text('✅', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(m.title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      Text('+${m.reward.coins} 🪙',
                          style: const TextStyle(
                              color: Color(0xFFFF9F1C),
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }
}
