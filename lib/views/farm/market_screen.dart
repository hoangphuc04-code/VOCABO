import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/market_service.dart';
import '../../data/services/farm_service.dart';
import '../../data/services/game_service.dart';

/// 🏪 Màn hình chợ
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF667eea);

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: _primary,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('🏪 Chợ',
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
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _CoinWidget(),
              ),
            ],
            bottom: TabBar(
              controller: _tabCtrl,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: const [
                Tab(text: 'Chợ chung'),
                Tab(text: 'Của tôi'),
                Tab(text: 'Lịch sử'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            _AllListingsTab(),
            _MyListingsTab(),
            _HistoryTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSellSheet(context),
        backgroundColor: _primary,
        icon: const Icon(Icons.sell_rounded, color: Colors.white),
        label: const Text('Đăng bán',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSellSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _SellSheet(),
    );
  }
}

// ─── All Listings Tab ─────────────────────────────────────────────────────────

class _AllListingsTab extends StatelessWidget {
  const _AllListingsTab();

  @override
  Widget build(BuildContext context) {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return StreamBuilder<List<MarketListing>>(
      stream: MarketService.activeListingsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final listings = snap.data ?? [];
        if (listings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🏪', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Chưa có sản phẩm nào',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: listings.length,
          itemBuilder: (context, i) => _ListingCard(
            listing: listings[i],
            isOwn: listings[i].sellerUid == myUid,
          ),
        );
      },
    );
  }
}

// ─── My Listings Tab ──────────────────────────────────────────────────────────

class _MyListingsTab extends StatelessWidget {
  const _MyListingsTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MarketListing>>(
      stream: MarketService.myListingsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final listings = snap.data ?? [];
        if (listings.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('📋', style: TextStyle(fontSize: 48)),
                SizedBox(height: 12),
                Text('Bạn chưa đăng bán gì',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: listings.length,
          itemBuilder: (context, i) => _ListingCard(
            listing: listings[i],
            isOwn: true,
            showCancel: listings[i].status == 'active',
          ),
        );
      },
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
  List<MarketTransaction> _txs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final txs = await MarketService.getTransactionHistory();
    if (mounted) setState(() {
      _txs = txs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_txs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📜', style: TextStyle(fontSize: 48)),
            SizedBox(height: 12),
            Text('Chưa có giao dịch nào',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _txs.length,
      itemBuilder: (context, i) {
        final tx = _txs[i];
        final isBuyer = tx.buyerUid == myUid;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
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
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isBuyer
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isBuyer ? Icons.shopping_cart : Icons.sell,
                    color: isBuyer ? Colors.red : Colors.green,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBuyer ? 'Đã mua ${tx.itemType}' : 'Đã bán ${tx.itemType}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'x${tx.quantity}  •  ${_formatDate(tx.createdAt)}',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              Text(
                isBuyer ? '-${tx.totalPrice} 🪙' : '+${tx.totalPrice} 🪙',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isBuyer ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ─── Listing Card ─────────────────────────────────────────────────────────────

class _ListingCard extends StatelessWidget {
  final MarketListing listing;
  final bool isOwn;
  final bool showCancel;

  const _ListingCard({
    required this.listing,
    required this.isOwn,
    this.showCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = listing.status == 'active'
        ? const Color(0xFF06D6A0)
        : listing.status == 'sold'
            ? Colors.grey
            : Colors.red;

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
          // Seller avatar
          CircleAvatar(
            radius: 20,
            backgroundImage: listing.sellerPhoto.isNotEmpty
                ? NetworkImage(listing.sellerPhoto)
                : null,
            backgroundColor: const Color(0xFF667eea).withOpacity(0.2),
            child: listing.sellerPhoto.isEmpty
                ? Text(
                    listing.sellerName.isNotEmpty
                        ? listing.sellerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                        color: Color(0xFF667eea),
                        fontWeight: FontWeight.bold),
                  )
                : null,
          ),
          const SizedBox(width: 10),
          // Item info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(listing.itemEmoji,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Text(listing.itemName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        listing.status == 'active'
                            ? 'Đang bán'
                            : listing.status == 'sold'
                                ? 'Đã bán'
                                : 'Đã huỷ',
                        style: TextStyle(
                            fontSize: 9,
                            color: statusColor,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${listing.sellerName}  •  x${listing.quantity}',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Price & action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 3),
                  Text(
                    '${listing.totalPrice}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFFFF9F1C)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (!isOwn && listing.status == 'active')
                GestureDetector(
                  onTap: () async {
                    final ok =
                        await MarketService.buyListing(listing.listingId);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Không đủ coin hoặc lỗi giao dịch')),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Mua',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ),
              if (showCancel && listing.status == 'active')
                GestureDetector(
                  onTap: () async {
                    await MarketService.cancelListing(listing.listingId);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Huỷ',
                        style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Sell Sheet ───────────────────────────────────────────────────────────────

class _SellSheet extends StatefulWidget {
  const _SellSheet();

  @override
  State<_SellSheet> createState() => _SellSheetState();
}

class _SellSheetState extends State<_SellSheet> {
  String? _selectedItem;
  int _quantity = 1;
  int _pricePerUnit = 5;
  Map<String, int> _warehouse = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWarehouse();
  }

  Future<void> _loadWarehouse() async {
    final w = await FarmService.getWarehouse();
    if (mounted) {
      setState(() {
        _warehouse = w;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Đăng bán sản phẩm',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  // Item selector
                  const Text('Chọn sản phẩm',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_warehouse.isEmpty)
                    const Text('Kho trống!',
                        style: TextStyle(color: Colors.grey))
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _warehouse.entries.map((e) {
                        final emoji = _emojiFor(e.key);
                        final isSelected = _selectedItem == e.key;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedItem = e.key;
                            _quantity = 1;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF667eea).withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF667eea)
                                    : Colors.grey.withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(emoji,
                                    style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                Text('${e.key} x${e.value}',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 16),
                  if (_selectedItem != null) ...[
                    // Quantity
                    Row(
                      children: [
                        const Text('Số lượng: ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        IconButton(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 20,
                        ),
                        Text('$_quantity',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          onPressed: _quantity <
                                  (_warehouse[_selectedItem] ?? 0)
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 20,
                        ),
                      ],
                    ),
                    // Price
                    Row(
                      children: [
                        const Text('Giá/cái: ',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        IconButton(
                          onPressed: _pricePerUnit > 1
                              ? () => setState(() => _pricePerUnit--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                          iconSize: 20,
                        ),
                        Text('$_pricePerUnit 🪙',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          onPressed: () =>
                              setState(() => _pricePerUnit++),
                          icon: const Icon(Icons.add_circle_outline),
                          iconSize: 20,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tổng: ${_quantity * _pricePerUnit} 🪙',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Color(0xFFFF9F1C)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (_selectedItem == null) return;
                          final ok = await MarketService.createListing(
                            itemType: _selectedItem!,
                            quantity: _quantity,
                            pricePerUnit: _pricePerUnit,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? '✅ Đã đăng bán!'
                                    : '❌ Không đủ hàng trong kho'),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Đăng bán',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  String _emojiFor(String itemType) {
    if (kCrops.containsKey(itemType)) return kCrops[itemType]!.emoji;
    if (kFish.containsKey(itemType)) return kFish[itemType]!.emoji;
    for (final a in kAnimals.values) {
      if (a.product == itemType) return a.productEmoji;
    }
    return '📦';
  }
}

// ─── Coin Widget ──────────────────────────────────────────────────────────────

class _CoinWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: GameService.coinsStream(),
      builder: (context, snap) {
        final coins = snap.data ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🪙', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text('$coins',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ],
          ),
        );
      },
    );
  }
}
