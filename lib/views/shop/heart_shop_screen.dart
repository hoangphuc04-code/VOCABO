import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/services/currency_service.dart';
import '../../data/services/streak_service.dart';

/// Màn hình cửa hàng mua Heart bằng Diamond
class HeartShopScreen extends StatefulWidget {
  const HeartShopScreen({super.key});

  @override
  State<HeartShopScreen> createState() => _HeartShopScreenState();
}

class _HeartShopScreenState extends State<HeartShopScreen>
    with SingleTickerProviderStateMixin {
  static const _primary = Color(0xFF667eea);
  static const _heartColor = Color(0xFFFF4757);

  late AnimationController _shimmerCtrl;
  bool _buying = false;

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    // Kiểm tra hồi phục heart khi mở shop
    CurrencyService.checkHeartRecovery();
  }

  @override
  void dispose() {
    _shimmerCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '🛒 Cửa hàng',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: false,
      ),
      body: uid == null
          ? const Center(child: Text('Vui lòng đăng nhập'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snap) {
                final data =
                    snap.data?.data() as Map<String, dynamic>? ?? {};
                final hearts =
                    (data['hearts'] ?? CurrencyService.maxHearts).toInt();
                final diamonds = (data['diamonds'] ?? 0).toInt();

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Tài sản hiện tại ──────────────
                      _WalletCard(hearts: hearts, diamonds: diamonds),
                      const SizedBox(height: 24),

                      // ── Hồi phục heart ────────────────
                      const _SectionTitle(
                          icon: '❤️', title: 'Hồi phục Tim'),
                      const SizedBox(height: 12),
                      _ShopItem(
                        icon: '❤️',
                        title: '+1 Tim',
                        subtitle: 'Hồi phục 1 tim ngay lập tức',
                        cost: CurrencyService.heartRefillCost,
                        costIcon: '💎',
                        color: _heartColor,
                        canAfford:
                            diamonds >= CurrencyService.heartRefillCost &&
                                hearts < CurrencyService.maxHearts,
                        isDisabled: hearts >= CurrencyService.maxHearts,
                        disabledText: hearts >= CurrencyService.maxHearts
                            ? 'Tim đã đầy!'
                            : null,
                        onBuy: _buying
                            ? null
                            : () => _buyHeart(context),
                      ),
                      const SizedBox(height: 12),
                      _ShopItem(
                        icon: '❤️❤️❤️❤️❤️',
                        title: 'Đầy Tim',
                        subtitle:
                            'Hồi phục tất cả ${CurrencyService.maxHearts} tim',
                        cost: CurrencyService.fullRefillCost,
                        costIcon: '💎',
                        color: _heartColor,
                        canAfford:
                            diamonds >= CurrencyService.fullRefillCost &&
                                hearts < CurrencyService.maxHearts,
                        isDisabled: hearts >= CurrencyService.maxHearts,
                        disabledText: hearts >= CurrencyService.maxHearts
                            ? 'Tim đã đầy!'
                            : null,
                        onBuy: _buying
                            ? null
                            : () => _buyFullHearts(context),
                        isBestValue: true,
                      ),

                      const SizedBox(height: 28),

                      // ── Streak Freeze ─────────────────
                      const _SectionTitle(
                          icon: '🧊', title: 'Streak Freeze'),
                      const SizedBox(height: 6),
                      Text(
                        'Bảo vệ streak khi bỏ lỡ 1 ngày học',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 12),
                      _ShopItem(
                        icon: '🧊',
                        title: 'Streak Freeze',
                        subtitle: 'Bảo vệ streak nếu bỏ lỡ 1 ngày (tối đa 2)',
                        cost: StreakService.streakFreezeCost,
                        costIcon: '💎',
                        color: const Color(0xFF74B9FF),
                        canAfford: diamonds >= StreakService.streakFreezeCost,
                        onBuy: _buying ? null : () => _buyStreakFreeze(context),
                      ),

                      const SizedBox(height: 28),

                      // ── Thông tin hồi phục ────────────
                      _RecoveryInfo(hearts: hearts),

                      const SizedBox(height: 28),

                      // ── Cách kiếm Diamond ─────────────
                      const _SectionTitle(
                          icon: '💎', title: 'Cách kiếm Diamond'),
                      const SizedBox(height: 12),
                      _EarnCard(
                        icon: '📅',
                        title: 'Điểm danh hàng ngày',
                        desc: 'Nhận 5-20💎 mỗi ngày, streak điểm danh càng cao càng nhiều',
                        color: _primary,
                      ),
                      const SizedBox(height: 8),
                      _EarnCard(
                        icon: '🔥',
                        title: 'Streak học bài (Duolingo-style)',
                        desc: 'Học ít nhất 1 từ mỗi ngày để duy trì streak. Bỏ 1 ngày → streak về 0!',
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 8),
                      _EarnCard(
                        icon: '🧊',
                        title: 'Streak Freeze',
                        desc: 'Mua để bảo vệ streak khi lỡ bỏ 1 ngày học (10💎/lần)',
                        color: const Color(0xFF74B9FF),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Future<void> _buyStreakFreeze(BuildContext context) async {
    setState(() => _buying = true);
    final result = await StreakService.buyStreakFreeze();
    setState(() => _buying = false);
    if (mounted) _showResultSnack(context, result.message, result.success);
  }

  Future<void> _buyHeart(BuildContext context) async {    setState(() => _buying = true);
    final result = await CurrencyService.buyHeart();
    setState(() => _buying = false);

    if (mounted) {
      _showResultSnack(context, result.message, result.success);
    }
  }

  Future<void> _buyFullHearts(BuildContext context) async {
    setState(() => _buying = true);
    final result = await CurrencyService.buyFullHearts();
    setState(() => _buying = false);

    if (mounted) {
      _showResultSnack(context, result.message, result.success);
    }
  }

  void _showResultSnack(BuildContext context, String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF06D6A0) : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _WalletCard extends StatelessWidget {
  final int hearts;
  final int diamonds;
  const _WalletCard({required this.hearts, required this.diamonds});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tài sản của bạn',
            style: TextStyle(
                color: Colors.white70, fontSize: 13, letterSpacing: 0.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _WalletItem(
                  icon: '❤️',
                  value: '$hearts/${CurrencyService.maxHearts}',
                  label: 'Tim',
                  color: const Color(0xFFFF4757),
                ),
              ),
              Container(
                  width: 1, height: 50, color: Colors.white24),
              Expanded(
                child: _WalletItem(
                  icon: '💎',
                  value: '$diamonds',
                  label: 'Diamond',
                  color: const Color(0xFF74B9FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Hearts bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(CurrencyService.maxHearts, (i) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      i < hearts ? '❤️' : '🖤',
                      style: const TextStyle(fontSize: 22),
                    ),
                  );
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletItem extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;
  const _WalletItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold),
        ),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
        ),
      ],
    );
  }
}

class _ShopItem extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final int cost;
  final String costIcon;
  final Color color;
  final bool canAfford;
  final bool isDisabled;
  final String? disabledText;
  final VoidCallback? onBuy;
  final bool isBestValue;

  const _ShopItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.cost,
    required this.costIcon,
    required this.color,
    required this.canAfford,
    this.isDisabled = false,
    this.disabledText,
    this.onBuy,
    this.isBestValue = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDisabled
                  ? Colors.grey.shade200
                  : color.withValues(alpha: 0.2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDisabled
                      ? Colors.grey.shade100
                      : color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(icon,
                      style: TextStyle(
                          fontSize: icon.length > 2 ? 12 : 24)),
                ),
              ),
              const SizedBox(width: 14),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isDisabled ? Colors.grey : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Buy button
              isDisabled
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        disabledText ?? 'Đã đủ',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500),
                      ),
                    )
                  : GestureDetector(
                      onTap: canAfford ? onBuy : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: canAfford
                              ? color
                              : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: canAfford
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(costIcon,
                                style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              '$cost',
                              style: TextStyle(
                                color: canAfford
                                    ? Colors.white
                                    : Colors.grey.shade500,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
        // Best value badge
        if (isBestValue)
          Positioned(
            top: -1,
            right: 12,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Tốt nhất',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class _RecoveryInfo extends StatefulWidget {
  final int hearts;
  const _RecoveryInfo({required this.hearts});

  @override
  State<_RecoveryInfo> createState() => _RecoveryInfoState();
}

class _RecoveryInfoState extends State<_RecoveryInfo> {
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _loadRecovery();
  }

  Future<void> _loadRecovery() async {
    final d = await CurrencyService.nextHeartRecoveryIn();
    if (mounted) setState(() => _remaining = d);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.hearts >= CurrencyService.maxHearts) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF06D6A0).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: const Color(0xFF06D6A0).withValues(alpha: 0.3)),
        ),
        child: const Row(
          children: [
            Text('✅', style: TextStyle(fontSize: 18)),
            SizedBox(width: 10),
            Text(
              'Tim đã đầy! Sẵn sàng học rồi 🎉',
              style: TextStyle(
                  color: Color(0xFF06D6A0), fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Text('⏰', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hồi phục tự động',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange,
                      fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  _remaining == null
                      ? 'Đang tính...'
                      : _remaining!.inSeconds <= 0
                          ? 'Sắp hồi phục!'
                          : 'Tim tiếp theo sau: ${_formatDuration(_remaining!)}',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                Text(
                  '1 tim mỗi ${CurrencyService.heartRecoverMinutes} phút',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m}p ${s}s';
  }
}

class _EarnCard extends StatelessWidget {
  final String icon;
  final String title;
  final String desc;
  final Color color;
  const _EarnCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 3),
                Text(desc,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
