 import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/services/house_service.dart';

/// 🛒 Cửa hàng trang trí nhà — nâng cấp đầy đủ
/// - Preview item trước khi mua
/// - Filter: Tất cả / Chưa có / Đã có
/// - Đổi pet
/// - Realtime coin update
/// - Confirm dialog trước khi mua
class HouseShopScreen extends StatefulWidget {
  const HouseShopScreen({super.key});

  @override
  State<HouseShopScreen> createState() => _HouseShopScreenState();
}

class _HouseShopScreenState extends State<HouseShopScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  HouseData? _house;
  bool _loading = true;
  bool _buying = false;
  HouseItem? _previewItem;

  // Filter state per tab
  final List<String> _filters = ['all', 'all', 'all', 'all', 'all'];

  static const _categories = [
    ('🎨', 'Tường'),
    ('🪟', 'Sàn'),
    ('🛋️', 'Nội thất'),
    ('🌸', 'Trang trí'),
    ('🐾', 'Pet'),
  ];
  static const _catIds = ['wallpaper', 'floor', 'furniture', 'decoration', 'pet'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: _categories.length, vsync: this);
    _loadHouse();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _loadHouse() async {
    final h = await HouseService.getHouse();
    if (mounted) setState(() { _house = h; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFBE0B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('🛒 Cửa hàng',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          // Coin realtime
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snap) {
              final coins = (snap.data?.data() as Map<String, dynamic>?)?['coins'] ?? 0;
              return Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Text('🪙', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 5),
                    Text('$coins',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _categories.map((c) => Tab(text: '${c.$1} ${c.$2}')).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFBE0B)))
          : Stack(
              children: [
                TabBarView(
                  controller: _tab,
                  children: List.generate(_categories.length, (i) {
                    return _ShopTab(
                      catId: _catIds[i],
                      house: _house!,
                      filter: _filters[i],
                      onFilterChange: (f) => setState(() => _filters[i] = f),
                      onPreview: (item) => setState(() => _previewItem = item),
                      onBuy: _buying ? null : _confirmBuy,
                      onApply: _apply,
                      onPlace: _place,
                      onChangePet: _changePet,
                    );
                  }),
                ),
                // Preview overlay
                if (_previewItem != null)
                  _PreviewOverlay(
                    item: _previewItem!,
                    isOwned: _house!.ownedItems.contains(_previewItem!.id),
                    onClose: () => setState(() => _previewItem = null),
                    onBuy: _buying ? null : () => _confirmBuy(_previewItem!),
                    onApply: () { _apply(_previewItem!); setState(() => _previewItem = null); },
                    onPlace: () { _place(_previewItem!); setState(() => _previewItem = null); },
                  ),
              ],
            ),
    );
  }

  // ── Confirm mua ───────────────────────────────────────
  void _confirmBuy(HouseItem item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(item.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 10),
            Expanded(child: Text(item.name, style: const TextStyle(fontSize: 17))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFBE0B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFBE0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Text('${item.price} Gold Coin',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFFFF9F1C))),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Huỷ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _doBuy(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFBE0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Mua ngay!', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _doBuy(HouseItem item) async {
    setState(() => _buying = true);
    final result = await HouseService.buyItem(item);
    setState(() => _buying = false);

    if (mounted) {
      _showSnack(result.message, result.success);
      if (result.success) {
        await _loadHouse(); // refresh
        setState(() => _previewItem = null);
      }
    }
  }

  Future<void> _apply(HouseItem item) async {
    if (item.category == 'wallpaper') {
      await HouseService.setWallpaper(item.id);
    } else if (item.category == 'floor') {
      await HouseService.setFloor(item.id);
    }
    await _loadHouse();
    if (mounted) _showSnack('✅ Đã áp dụng ${item.name}!', true);
  }

  Future<void> _place(HouseItem item) async {
    final rng = Random();
    final placed = PlacedItem(
      instanceId: '${item.id}_${DateTime.now().millisecondsSinceEpoch}',
      itemId: item.id,
      gridX: rng.nextInt(6) + 1,
      gridY: rng.nextInt(4) + 1,
    );
    await HouseService.placeItem(placed);
    if (mounted) _showSnack('✅ Đã đặt ${item.name} vào phòng!', true);
  }

  Future<void> _changePet(HouseItem item) async {
    // Đổi loại pet
    final petType = item.id.replaceFirst('pet_', '');
    await HouseService.changePetType(petType);
    await _loadHouse();
    if (mounted) _showSnack('🐾 Đã đổi sang ${item.name}!', true);
  }

  void _showSnack(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF06D6A0) : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }
}

// ─── Shop Tab ─────────────────────────────────────────────────────────────────

class _ShopTab extends StatelessWidget {
  final String catId;
  final HouseData house;
  final String filter; // 'all', 'owned', 'new'
  final void Function(String) onFilterChange;
  final void Function(HouseItem) onPreview;
  final void Function(HouseItem)? onBuy;
  final void Function(HouseItem) onApply;
  final void Function(HouseItem) onPlace;
  final void Function(HouseItem) onChangePet;

  const _ShopTab({
    required this.catId,
    required this.house,
    required this.filter,
    required this.onFilterChange,
    required this.onPreview,
    required this.onBuy,
    required this.onApply,
    required this.onPlace,
    required this.onChangePet,
  });

  @override
  Widget build(BuildContext context) {
    var items = HouseItemCatalogue.byCategory(catId);

    // Apply filter
    if (filter == 'owned') {
      items = items.where((i) => house.ownedItems.contains(i.id)).toList();
    } else if (filter == 'new') {
      items = items.where((i) => !house.ownedItems.contains(i.id)).toList();
    }

    return Column(
      children: [
        // Filter chips
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              _FilterChip(label: 'Tất cả', value: 'all', current: filter, onTap: onFilterChange),
              const SizedBox(width: 8),
              _FilterChip(label: '✅ Đã có', value: 'owned', current: filter, onTap: onFilterChange),
              const SizedBox(width: 8),
              _FilterChip(label: '🆕 Chưa có', value: 'new', current: filter, onTap: onFilterChange),
            ],
          ),
        ),

        // Items grid
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🛒', style: TextStyle(fontSize: 48)),
                      const SizedBox(height: 12),
                      Text(
                        filter == 'owned' ? 'Chưa có vật phẩm nào' : 'Đã mua hết rồi!',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final item = items[i];
                    final isOwned = house.ownedItems.contains(item.id);
                    final isActive = item.id == house.wallpaper || item.id == house.floorType;
                    final isCurrentPet = catId == 'pet' && house.pet.type == item.id.replaceFirst('pet_', '');

                    return _ShopItemCard(
                      item: item,
                      isOwned: isOwned,
                      isActive: isActive || isCurrentPet,
                      catId: catId,
                      onTap: () => onPreview(item),
                      onBuy: onBuy != null ? () => onBuy!(item) : null,
                      onApply: () => onApply(item),
                      onPlace: () => onPlace(item),
                      onChangePet: () => onChangePet(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Filter Chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final String current;
  final void Function(String) onTap;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFBE0B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFBE0B) : Colors.grey.shade300,
          ),
          boxShadow: isSelected
              ? [BoxShadow(
                  color: const Color(0xFFFFBE0B).withValues(alpha: 0.3),
                  blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

// ─── Shop Item Card ───────────────────────────────────────────────────────────

class _ShopItemCard extends StatelessWidget {
  final HouseItem item;
  final bool isOwned;
  final bool isActive;
  final String catId;
  final VoidCallback onTap;
  final VoidCallback? onBuy;
  final VoidCallback onApply;
  final VoidCallback onPlace;
  final VoidCallback onChangePet;

  const _ShopItemCard({
    required this.item,
    required this.isOwned,
    required this.isActive,
    required this.catId,
    required this.onTap,
    required this.onBuy,
    required this.onApply,
    required this.onPlace,
    required this.onChangePet,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: isActive
              ? Border.all(color: const Color(0xFF06D6A0), width: 2.5)
              : isOwned
                  ? Border.all(color: const Color(0xFF667eea).withValues(alpha: 0.4), width: 1.5)
                  : Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: isActive
                  ? const Color(0xFF06D6A0).withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: isActive ? 12 : 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: emoji + badges
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.emoji, style: const TextStyle(fontSize: 38)),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isActive)
                        _Badge(label: '✓ Đang dùng', color: const Color(0xFF06D6A0)),
                      if (isOwned && !isActive)
                        _Badge(label: '✓ Đã có', color: const Color(0xFF667eea)),
                      if (!isOwned && item.isDefault)
                        _Badge(label: 'Miễn phí', color: Colors.green),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Name
              Text(item.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1A1A2E))),
              const SizedBox(height: 2),
              Text(item.description,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  maxLines: 2, overflow: TextOverflow.ellipsis),

              const Spacer(),

              // Action button
              SizedBox(width: double.infinity, child: _buildBtn()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBtn() {
    if (isOwned) {
      if (catId == 'wallpaper' || catId == 'floor') {
        return _ActionBtn(
          label: isActive ? '✓ Đang dùng' : 'Áp dụng',
          color: isActive ? Colors.grey.shade300 : const Color(0xFF06D6A0),
          textColor: isActive ? Colors.grey : Colors.white,
          onTap: isActive ? null : onApply,
        );
      }
      if (catId == 'furniture' || catId == 'decoration') {
        return _ActionBtn(
          label: '+ Đặt vào phòng',
          color: const Color(0xFF667eea),
          textColor: Colors.white,
          onTap: onPlace,
        );
      }
      if (catId == 'pet') {
        return _ActionBtn(
          label: isActive ? '✓ Pet hiện tại' : 'Đổi sang pet này',
          color: isActive ? Colors.grey.shade300 : const Color(0xFFFF6B35),
          textColor: isActive ? Colors.grey : Colors.white,
          onTap: isActive ? null : onChangePet,
        );
      }
      return const SizedBox.shrink();
    }

    // Chưa sở hữu
    if (item.isDefault) {
      return _ActionBtn(
        label: '✓ Mặc định',
        color: Colors.grey.shade200,
        textColor: Colors.grey,
        onTap: null,
      );
    }

    return _ActionBtn(
      label: '🪙 ${item.price}',
      color: const Color(0xFFFFBE0B),
      textColor: Colors.white,
      onTap: onBuy,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label,
          style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: onTap != null
              ? [BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2))]
              : null,
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: textColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

// ─── Preview Overlay ──────────────────────────────────────────────────────────

class _PreviewOverlay extends StatelessWidget {
  final HouseItem item;
  final bool isOwned;
  final VoidCallback onClose;
  final VoidCallback? onBuy;
  final VoidCallback onApply;
  final VoidCallback onPlace;

  const _PreviewOverlay({
    required this.item,
    required this.isOwned,
    required this.onClose,
    required this.onBuy,
    required this.onApply,
    required this.onPlace,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        child: Center(
          child: GestureDetector(
            onTap: () {}, // prevent close on card tap
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Close
                  Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: onClose,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 16, color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Big emoji
                  Text(item.emoji, style: const TextStyle(fontSize: 72)),
                  const SizedBox(height: 12),

                  // Name
                  Text(item.name,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 6),
                  Text(item.description,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      textAlign: TextAlign.center),

                  const SizedBox(height: 16),

                  // Price
                  if (!isOwned && !item.isDefault)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFBE0B).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFFBE0B).withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🪙', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 8),
                          Text('${item.price} Gold Coin',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Color(0xFFFF9F1C))),
                        ],
                      ),
                    ),

                  if (isOwned)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06D6A0).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('✅', style: TextStyle(fontSize: 16)),
                          SizedBox(width: 6),
                          Text('Bạn đã sở hữu vật phẩm này',
                              style: TextStyle(
                                  color: Color(0xFF06D6A0),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),

                  const SizedBox(height: 20),

                  // Action buttons
                  if (!isOwned && !item.isDefault)
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onBuy,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFBE0B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Mua ngay!',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                  if (isOwned && (item.category == 'wallpaper' || item.category == 'floor'))
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onApply,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF06D6A0),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Áp dụng ngay',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),

                  if (isOwned && (item.category == 'furniture' || item.category == 'decoration'))
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onPlace,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text('Đặt vào phòng',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
