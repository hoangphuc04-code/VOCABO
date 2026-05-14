import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/services/currency_service.dart';
import '../shop/heart_shop_screen.dart';

/// Widget hiển thị Hearts ❤️ và Diamonds 💎 trên AppBar
class CurrencyBar extends StatelessWidget {
  const CurrencyBar({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final hearts = (data['hearts'] ?? CurrencyService.maxHearts).toInt();
        final diamonds = (data['diamonds'] ?? 0).toInt();

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hearts
            GestureDetector(
              onTap: () => _openShop(context),
              child: _CurrencyChip(
                icon: '❤️',
                value: hearts,
                color: const Color(0xFFFF4757),
                isEmpty: hearts == 0,
              ),
            ),
            const SizedBox(width: 8),
            // Diamonds
            _CurrencyChip(
              icon: '💎',
              value: diamonds,
              color: const Color(0xFF5352ED),
            ),
          ],
        );
      },
    );
  }

  void _openShop(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HeartShopScreen()),
    );
  }
}

class _CurrencyChip extends StatelessWidget {
  final String icon;
  final int value;
  final Color color;
  final bool isEmpty;

  const _CurrencyChip({
    required this.icon,
    required this.value,
    required this.color,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isEmpty
            ? Colors.grey.shade200
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEmpty ? Colors.grey.shade300 : color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isEmpty ? '🖤' : icon,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isEmpty ? Colors.grey : color,
            ),
          ),
        ],
      ),
    );
  }
}
