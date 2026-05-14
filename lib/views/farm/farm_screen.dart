import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/farm_service.dart';

/// 🐄 Màn hình chuồng trại + hồ cá
class FarmScreen extends StatefulWidget {
  const FarmScreen({super.key});

  @override
  State<FarmScreen> createState() => _FarmScreenState();
}

class _FarmScreenState extends State<FarmScreen>
    with SingleTickerProviderStateMixin {

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return const Scaffold(body: Center(child: Text('Chưa đăng nhập')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      body: StreamBuilder<FarmData>(
        stream: FarmService.farmStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final farm = snap.data ?? FarmData.defaultFarm();
          return _FarmBody(farm: farm, tabCtrl: _tabCtrl);
        },
      ),
    );
  }
}

class _FarmBody extends StatelessWidget {
  final FarmData farm;
  final TabController tabCtrl;

  const _FarmBody({required this.farm, required this.tabCtrl});

  @override
  Widget build(BuildContext context) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverAppBar(
          expandedHeight: 120,
          pinned: true,
          backgroundColor: const Color(0xFFFF6B35),
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('🐄 Chuồng trại & Hồ cá',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFFBE0B)],
                ),
              ),
            ),
          ),
          bottom: TabBar(
            controller: tabCtrl,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: '🐔 Chuồng trại'),
              Tab(text: '🐟 Hồ cá'),
            ],
          ),
        ),
      ],
      body: TabBarView(
        controller: tabCtrl,
        children: [
          _AnimalSection(farm: farm),
          _FishSection(farm: farm),
        ],
      ),
    );
  }
}

// ─── Animal Section ───────────────────────────────────────────────────────────

class _AnimalSection extends StatelessWidget {
  final FarmData farm;
  const _AnimalSection({required this.farm});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Slots
        ...List.generate(farm.unlockedAnimalSlots, (i) {
          if (i < farm.animals.length) {
            return _AnimalCard(animal: farm.animals[i]);
          }
          return _EmptyAnimalSlot(onAdd: () => _showAddAnimalSheet(context));
        }),
        const SizedBox(height: 12),
        // Unlock slot button
        _UnlockSlotButton(
          label: 'Mở thêm chuồng',
          cost: 80,
          onTap: () async {
            final ok = await FarmService.unlockAnimalSlot();
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không đủ coin (cần 80 🪙)')),
              );
            }
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  void _showAddAnimalSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddAnimalSheet(),
    );
  }
}

class _AnimalCard extends StatelessWidget {
  final AnimalData animal;
  const _AnimalCard({required this.animal});

  @override
  Widget build(BuildContext context) {
    final info = kAnimals[animal.type];
    if (info == null) return const SizedBox();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Animal emoji
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(info.emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(animal.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Lv.${animal.level}',
                          style: const TextStyle(
                              fontSize: 10, color: Color(0xFF667eea))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(info.productEmoji,
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: LinearProgressIndicator(
                        value: animal.productionProgress,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          animal.isProductReady
                              ? const Color(0xFF06D6A0)
                              : const Color(0xFF667eea),
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  animal.isProductReady
                      ? '✅ Sẵn sàng thu hoạch!'
                      : '⏱ ${_formatDuration(animal.timeUntilProduct)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: animal.isProductReady
                        ? const Color(0xFF06D6A0)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Action buttons
          Column(
            children: [
              _ActionBtn(
                icon: '🍖',
                label: 'Cho ăn',
                color: const Color(0xFFFF6B35),
                onTap: () async {
                  final ok = await FarmService.feedAnimal(animal.animalId);
                  if (!ok && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Không đủ coin (cần ${info.feedCost} 🪙)')),
                    );
                  }
                },
              ),
              const SizedBox(height: 6),
              if (animal.isProductReady)
                _ActionBtn(
                  icon: info.productEmoji,
                  label: 'Thu',
                  color: const Color(0xFF06D6A0),
                  onTap: () async {
                    await FarmService.collectAnimalProduct(animal.animalId);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    return '${d.inMinutes}m';
  }
}

class _EmptyAnimalSlot extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyAnimalSlot({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              style: BorderStyle.solid),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline,
                color: Colors.grey.shade400, size: 24),
            const SizedBox(width: 8),
            Text('Thêm động vật',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class _AddAnimalSheet extends StatelessWidget {
  const _AddAnimalSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Chọn động vật',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...kAnimals.values.map((info) => _AnimalOption(
                info: info,
                onTap: () async {
                  Navigator.pop(context);
                  await FarmService.addAnimal(info.type, info.emoji);
                },
              )),
        ],
      ),
    );
  }
}

class _AnimalOption extends StatelessWidget {
  final AnimalInfo info;
  final VoidCallback onTap;

  const _AnimalOption({required this.info, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final h = info.productionTime.inHours;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(info.emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info.type,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                      '${info.productEmoji} ${info.product} mỗi ${h}h  •  💰 ${info.productValue} coin',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Fish Section ─────────────────────────────────────────────────────────────

class _FishSection extends StatelessWidget {
  final FarmData farm;
  const _FishSection({required this.farm});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Fish grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: farm.unlockedFishSlots,
          itemBuilder: (context, i) {
            if (i < farm.fishPond.length) {
              return _FishTile(fish: farm.fishPond[i]);
            }
            return _EmptyFishSlot(
              onAdd: () => _showAddFishSheet(context),
            );
          },
        ),
        const SizedBox(height: 12),
        _UnlockSlotButton(
          label: 'Mở thêm hồ',
          cost: 60,
          onTap: () async {
            final ok = await FarmService.unlockFishSlot();
            if (!ok && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Không đủ coin (cần 60 🪙)')),
              );
            }
          },
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  void _showAddFishSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _AddFishSheet(),
    );
  }
}

class _FishTile extends StatelessWidget {
  final FishData fish;
  const _FishTile({required this.fish});

  @override
  Widget build(BuildContext context) {
    final info = kFish[fish.type];
    if (info == null) return const SizedBox();
    final computed = fish.withComputedReady();

    return GestureDetector(
      onTap: computed.isReady
          ? () async {
              await FarmService.collectFish(fish.fishId);
            }
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: computed.isReady
              ? const Color(0xFF06D6A0).withOpacity(0.1)
              : Colors.blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: computed.isReady
                ? const Color(0xFF06D6A0)
                : Colors.blue.withOpacity(0.2),
            width: computed.isReady ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(info.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: LinearProgressIndicator(
                value: computed.growthProgress,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                  computed.isReady
                      ? const Color(0xFF06D6A0)
                      : Colors.blue,
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              computed.isReady ? '🎣 Thu!' : info.type,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: computed.isReady
                    ? const Color(0xFF06D6A0)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFishSlot extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyFishSlot({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onAdd,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.blue.withOpacity(0.15)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add, color: Colors.blue.shade200, size: 24),
            const SizedBox(height: 4),
            Text('Thêm cá',
                style: TextStyle(
                    fontSize: 10, color: Colors.blue.shade300)),
          ],
        ),
      ),
    );
  }
}

class _AddFishSheet extends StatelessWidget {
  const _AddFishSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Chọn loại cá',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...kFish.values.map((info) => GestureDetector(
                onTap: () async {
                  Navigator.pop(context);
                  await FarmService.addFish(info.type);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(info.emoji,
                          style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(info.type,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                                '⏱ ${info.growTime.inHours}h  •  💰 ${info.sellPrice} coin',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _UnlockSlotButton extends StatelessWidget {
  final String label;
  final int cost;
  final VoidCallback onTap;

  const _UnlockSlotButton({
    required this.label,
    required this.cost,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_open_rounded,
                color: Color(0xFF667eea), size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: const TextStyle(
                    color: Color(0xFF667eea),
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFBE0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 3),
                  Text('$cost',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF9F1C))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
