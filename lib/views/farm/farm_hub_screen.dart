import 'package:flutter/material.dart';
import '../../data/services/farm_service.dart';
import '../../data/services/game_service.dart';
import '../../data/services/mission_service.dart';
import 'garden_screen.dart';
import 'farm_screen.dart';
import 'market_screen.dart';
import 'warehouse_screen.dart';
import 'mission_screen.dart';

/// 🌿 Farm Hub — màn hình trung tâm của farm
class FarmHubScreen extends StatefulWidget {
  const FarmHubScreen({super.key});

  @override
  State<FarmHubScreen> createState() => _FarmHubScreenState();
}

class _FarmHubScreenState extends State<FarmHubScreen> {
  @override
  void initState() {
    super.initState();
    FarmService.initFarmIfNeeded();
    MissionService.generateDailyMissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7F0),
      body: StreamBuilder<FarmData>(
        stream: FarmService.farmStream(),
        builder: (context, farmSnap) {
          final farm = farmSnap.data ?? FarmData.defaultFarm();
          return StreamBuilder<List<MissionData>>(
            stream: MissionService.missionsStream(),
            builder: (context, missionSnap) {
              final missions = missionSnap.data ?? [];
              final pendingMissions =
                  missions.where((m) => !m.isCompleted && !m.isExpired).length;
              return _HubBody(
                farm: farm,
                pendingMissions: pendingMissions,
              );
            },
          );
        },
      ),
    );
  }
}

class _HubBody extends StatelessWidget {
  final FarmData farm;
  final int pendingMissions;

  static const _primary = Color(0xFF667eea);

  const _HubBody({required this.farm, required this.pendingMissions});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(child: _HubHeader(farm: farm)),
        // Main nav buttons
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 16),
              // 4 main buttons
              Row(
                children: [
                  Expanded(
                    child: _HubNavButton(
                      emoji: '🌱',
                      label: 'Vườn',
                      subtitle: '${farm.readyCrops} sẵn thu',
                      color: const Color(0xFF06D6A0),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const GardenScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HubNavButton(
                      emoji: '🐄',
                      label: 'Chuồng trại',
                      subtitle: '${farm.readyAnimals} sản phẩm',
                      color: const Color(0xFFFF6B35),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const FarmScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _HubNavButton(
                      emoji: '🏪',
                      label: 'Chợ',
                      subtitle: 'Mua & bán',
                      color: _primary,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MarketScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _HubNavButton(
                      emoji: '📦',
                      label: 'Kho',
                      subtitle:
                          '${farm.warehouseUsed}/${farm.warehouseCapacity}',
                      color: const Color(0xFF764ba2),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const WarehouseScreen()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Mission button (full width)
              _MissionNavButton(
                pendingMissions: pendingMissions,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const MissionScreen()),
                ),
              ),
              const SizedBox(height: 20),
              // Preview sections
              _QuickPreview(farm: farm),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Hub Header ───────────────────────────────────────────────────────────────

class _HubHeader extends StatelessWidget {
  final FarmData farm;

  const _HubHeader({required this.farm});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF06D6A0), Color(0xFF667eea)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '🌿 Nông trại của tôi',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Coin display
                  StreamBuilder<int>(
                    stream: GameService.coinsStream(),
                    builder: (context, snap) {
                      final coins = snap.data ?? 0;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🪙',
                                style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              '$coins',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Stats row
              Row(
                children: [
                  _HeaderStat(
                    icon: '🌱',
                    label: 'Ô đất',
                    value: '${farm.unlockedPlots}',
                  ),
                  const SizedBox(width: 12),
                  _HeaderStat(
                    icon: '🐄',
                    label: 'Động vật',
                    value: '${farm.animals.length}',
                  ),
                  const SizedBox(width: 12),
                  _HeaderStat(
                    icon: '📦',
                    label: 'Kho',
                    value:
                        '${farm.warehouseUsed}/${farm.warehouseCapacity}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _HeaderStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.8), fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

// ─── Hub Nav Button ───────────────────────────────────────────────────────────

class _HubNavButton extends StatefulWidget {
  final String emoji;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HubNavButton({
    required this.emoji,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  State<_HubNavButton> createState() => _HubNavButtonState();
}

class _HubNavButtonState extends State<_HubNavButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.95),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(widget.emoji,
                      style: const TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(height: 10),
              Text(widget.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 2),
              Text(widget.subtitle,
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Mission Nav Button ───────────────────────────────────────────────────────

class _MissionNavButton extends StatelessWidget {
  final int pendingMissions;
  final VoidCallback onTap;

  const _MissionNavButton({
    required this.pendingMissions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFBE0B), Color(0xFFFF9F1C)],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFBE0B).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('📋', style: TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nhiệm vụ hàng ngày',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  Text('Hoàn thành để nhận thưởng',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            if (pendingMissions > 0)
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$pendingMissions',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

// ─── Quick Preview ────────────────────────────────────────────────────────────

class _QuickPreview extends StatelessWidget {
  final FarmData farm;
  const _QuickPreview({required this.farm});

  @override
  Widget build(BuildContext context) {
    final readyPlots = farm.plots.where((p) => p.isReady).toList();
    final readyAnimals =
        farm.animals.where((a) => a.isProductReady).toList();

    if (readyPlots.isEmpty && readyAnimals.isEmpty) {
      return const SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('⚡ Sẵn sàng thu hoạch',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333))),
        const SizedBox(height: 10),
        if (readyPlots.isNotEmpty) ...[
          const Text('🌱 Cây trồng',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: readyPlots.map((p) {
              final info = kCrops[p.cropType!];
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF06D6A0).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF06D6A0).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(info?.emoji ?? '🌿',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(p.cropType ?? '',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF06D6A0))),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
        ],
        if (readyAnimals.isNotEmpty) ...[
          const Text('🐄 Động vật',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: readyAnimals.map((a) {
              final info = kAnimals[a.type];
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF6B35).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(info?.productEmoji ?? '🥚',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(a.name,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF6B35))),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
