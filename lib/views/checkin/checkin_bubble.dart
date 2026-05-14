import 'package:flutter/material.dart';
import '../../data/services/currency_service.dart';
import 'daily_checkin_screen.dart';

/// Floating button điểm danh hàng ngày
/// Hiển thị badge khi chưa điểm danh
class CheckinBubble extends StatefulWidget {
  const CheckinBubble({super.key});

  @override
  State<CheckinBubble> createState() => _CheckinBubbleState();
}

class _CheckinBubbleState extends State<CheckinBubble>
    with SingleTickerProviderStateMixin {
  double _top = 420;
  double _left = 16;

  bool _hasCheckedIn = false;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _checkStatus();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final checked = await CurrencyService.hasCheckedInToday();
    if (mounted) setState(() => _hasCheckedIn = checked);
  }

  void _openCheckin() async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const DailyCheckinScreen(),
    );
    // Refresh status sau khi đóng
    _checkStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _top,
      left: _left,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _left += details.delta.dx;
            _top += details.delta.dy;
          });
        },
        onTap: _openCheckin,
        child: ScaleTransition(
          scale: !_hasCheckedIn ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _hasCheckedIn
                        ? [Colors.grey.shade400, Colors.grey.shade500]
                        : [const Color(0xFFFFBE0B), const Color(0xFFFF9F1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (_hasCheckedIn
                              ? Colors.grey
                              : const Color(0xFFFFBE0B))
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _hasCheckedIn ? '✅' : '📅',
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              // Badge "NEW" khi chưa điểm danh
              if (!_hasCheckedIn)
                Positioned(
                  top: -4,
                  right: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'MỚI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
