import 'package:flutter/material.dart';
import '../../data/services/battle_service.dart';
import 'battle_screen.dart';

/// 🏆 Battle Hub — màn hình chọn chế độ battle
class BattleHubScreen extends StatefulWidget {
  const BattleHubScreen({super.key});

  @override
  State<BattleHubScreen> createState() => _BattleHubScreenState();
}

class _BattleHubScreenState extends State<BattleHubScreen> {
  BattleStats? _stats;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await BattleService.getBattleStats();
    if (mounted) setState(() => _stats = stats);
  }

  Future<void> _findMatch() async {
    setState(() => _loading = true);
    try {
      final roomId = await BattleService.findOrCreateRoom();
      if (mounted) {
        setState(() => _loading = false);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => BattleScreen(roomId: roomId)),
        ).then((_) => _loadStats());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1A1A2E),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1A1A2E), Color(0xFF2D2D44)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('🏆', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 8),
                      const Text('Battle Mode',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900)),
                      const Text('Đấu từ vựng 1v1 Realtime',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Stats card
                if (_stats != null) _StatsCard(stats: _stats!),
                const SizedBox(height: 20),

                // Find match button
                _FindMatchButton(
                  loading: _loading,
                  onTap: _findMatch,
                ),
                const SizedBox(height: 20),

                // Rules card
                const _RulesCard(),
                const SizedBox(height: 20),

                // Rewards card
                const _RewardsCard(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Stats Card ───────────────────────────────────────────────────────────────

class _StatsCard extends StatelessWidget {
  final BattleStats stats;
  const _StatsCard({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📊 Thống kê của bạn',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _StatItem('Trận đấu', '${stats.played}', Colors.white)),
              Expanded(
                  child: _StatItem(
                      'Thắng', '${stats.won}', const Color(0xFF06D6A0))),
              Expanded(
                  child: _StatItem(
                      'Thua', '${stats.lost}', const Color(0xFFFF4757))),
              Expanded(
                  child: _StatItem(
                      'Hòa', '${stats.draw}', const Color(0xFFFFBE0B))),
            ],
          ),
          if (stats.played > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: stats.winRate,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF06D6A0)),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tỷ lệ thắng: ${(stats.winRate * 100).toStringAsFixed(1)}%',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatItem(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.w900)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

// ─── Find Match Button ────────────────────────────────────────────────────────

class _FindMatchButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;
  const _FindMatchButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFBE0B), Color(0xFFFF8C69)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFBE0B).withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            if (loading)
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 3),
              )
            else
              const Text('⚔️', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 8),
            Text(
              loading ? 'Đang tìm đối thủ...' : 'Tìm trận đấu',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900),
            ),
            const Text('Ghép ngẫu nhiên với người chơi khác',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─── Rules Card ───────────────────────────────────────────────────────────────

class _RulesCard extends StatelessWidget {
  const _RulesCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D44),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📋 Luật chơi',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 12),
          ...[
            '⚡ 10 câu hỏi từ vựng IELTS',
            '⏱️ 8 giây mỗi câu',
            '🎯 Trả lời đúng + nhanh = điểm cao hơn',
            '🏆 Ai nhiều điểm hơn thắng',
            '🪙 Thắng: +50 coins | Hòa: +20 coins',
          ].map((rule) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(rule.substring(0, 2),
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Text(rule.substring(2),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Rewards Card ─────────────────────────────────────────────────────────────

class _RewardsCard extends StatelessWidget {
  const _RewardsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.3),
            const Color(0xFF764ba2).withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF667eea).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎁 Phần thưởng',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _RewardItem('🏆 Thắng', '+50 🪙',
                      const Color(0xFFFFBE0B))),
              Expanded(
                  child: _RewardItem(
                      '🤝 Hòa', '+20 🪙', const Color(0xFF06D6A0))),
              Expanded(
                  child: _RewardItem(
                      '😢 Thua', '+0 🪙', Colors.white38)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardItem extends StatelessWidget {
  final String label;
  final String reward;
  final Color color;
  const _RewardItem(this.label, this.reward, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(reward,
            style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}
