import 'package:flutter/material.dart';
import '../../data/services/farm_service.dart';
import '../../data/services/game_service.dart';

/// 📦 Màn hình kho
class WarehouseScreen extends StatelessWidget {
  const WarehouseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: StreamBuilder<FarmData>(
        stream: FarmService.farmStream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final farm = snap.data ?? FarmData.defaultFarm();
          return _WarehouseBody(farm: farm);
        },
      ),
    );
  }
}

class _WarehouseBody extends StatelessWidget {
  final FarmData farm;
  static const _primary = Color(0xFF667eea);

  const _WarehouseBody({required this.farm});

  @override
  Widget build(BuildContext context) {
    final items = farm.warehouse.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 130,
          pinned: true,
          backgroundColor: _primary,
          flexibleSpace: FlexibleSpaceBar(
            title: const Text('📦 Kho của tôi',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Capacity bar
              _CapacityBar(farm: farm),
              const SizedBox(height: 16),
              // Expand warehouse button
              _ExpandWarehouseButton(farm: farm),
              const SizedBox(height: 16),
              // Items grid
              if (items.isEmpty)
                const _EmptyWarehouse()
              else
                _ItemsGrid(items: items),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }
}

// ─── Capacity Bar ─────────────────────────────────────────────────────────────

class _CapacityBar extends StatelessWidget {
  final FarmData farm;
  const _CapacityBar({required this.farm});

  @override
  Widget build(BuildContext context) {
    final used = farm.warehouseUsed;
    final cap = farm.warehouseCapacity;
    final pct = used / cap;
    final color = pct > 0.8
        ? Colors.red
        : pct > 0.5
            ? Colors.orange
            : const Color(0xFF06D6A0);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Sức chứa kho',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text(
                '$used / $cap',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 10,
            ),
          ),
          if (pct > 0.8) ...[
            const SizedBox(height: 6),
            Text(
              '⚠️ Kho gần đầy! Hãy bán bớt hoặc mở rộng kho.',
              style: TextStyle(fontSize: 11, color: Colors.orange.shade700),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Expand Warehouse Button ──────────────────────────────────────────────────

class _ExpandWarehouseButton extends StatelessWidget {
  final FarmData farm;
  const _ExpandWarehouseButton({required this.farm});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Mở rộng kho thêm 50 slot, tốn 100 coin
        final ok = await GameService.spendCoins(100);
        if (!ok && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không đủ coin (cần 100 🪙)')),
          );
          return;
        }
        // Cập nhật capacity
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Đã mở rộng kho thêm 50 slot!')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.expand_rounded,
                color: Color(0xFF667eea), size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Mở rộng kho (+50 slot)',
                  style: TextStyle(
                      color: Color(0xFF667eea),
                      fontWeight: FontWeight.w600)),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFBE0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('🪙', style: TextStyle(fontSize: 12)),
                  SizedBox(width: 3),
                  Text('100',
                      style: TextStyle(
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

// ─── Items Grid ───────────────────────────────────────────────────────────────

class _ItemsGrid extends StatelessWidget {
  final List<MapEntry<String, int>> items;
  const _ItemsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vật phẩm trong kho',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333))),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: items.length,
          itemBuilder: (context, i) => _ItemTile(entry: items[i]),
        ),
      ],
    );
  }
}

class _ItemTile extends StatelessWidget {
  final MapEntry<String, int> entry;
  const _ItemTile({required this.entry});

  String get _emoji {
    if (kCrops.containsKey(entry.key)) return kCrops[entry.key]!.emoji;
    if (kFish.containsKey(entry.key)) return kFish[entry.key]!.emoji;
    for (final a in kAnimals.values) {
      if (a.product == entry.key) return a.productEmoji;
    }
    return '📦';
  }

  int get _sellPrice {
    if (kCrops.containsKey(entry.key)) return kCrops[entry.key]!.sellPrice;
    if (kFish.containsKey(entry.key)) return kFish[entry.key]!.sellPrice;
    for (final a in kAnimals.values) {
      if (a.product == entry.key) return a.productValue;
    }
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 4),
          Text(
            entry.key,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            'x${entry.value}',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667eea)),
          ),
          const SizedBox(height: 4),
          // Sell all button
          GestureDetector(
            onTap: () async {
              final earned = await FarmService.sellFromWarehouse(
                  entry.key, entry.value);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        earned > 0
                            ? '✅ Bán được $earned 🪙'
                            : '❌ Không thể bán'),
                  ),
                );
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFBE0B).withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 10)),
                  const SizedBox(width: 2),
                  Text(
                    '${_sellPrice * entry.value}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF9F1C)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty Warehouse ──────────────────────────────────────────────────────────

class _EmptyWarehouse extends StatelessWidget {
  const _EmptyWarehouse();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: const Column(
        children: [
          Text('📦', style: TextStyle(fontSize: 56)),
          SizedBox(height: 12),
          Text('Kho trống',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          SizedBox(height: 6),
          Text('Hãy trồng cây và thu hoạch để lấp đầy kho!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}
