import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../../data/services/currency_service.dart';
import '../../data/services/streak_service.dart';

/// Màn hình điểm danh hàng ngày
/// - Điểm danh → nhận Diamond
/// - Streak hiển thị từ StreakService (học bài mới tăng streak)
class DailyCheckinScreen extends StatefulWidget {
  const DailyCheckinScreen({super.key});

  @override
  State<DailyCheckinScreen> createState() => _DailyCheckinScreenState();
}

class _DailyCheckinScreenState extends State<DailyCheckinScreen>
    with SingleTickerProviderStateMixin {
  late final ConfettiController _confettiCtrl;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  bool _loading = false;
  bool _checkedIn = false;
  CheckinResult? _result;
  List<DayStatus> _history = [];
  StreakInfo _streakInfo = const StreakInfo(
    streak: 0, longestStreak: 0, freezeCount: 0, hasStudiedToday: false,
  );

  @override
  void initState() {
    super.initState();
    _confettiCtrl = ConfettiController(duration: const Duration(seconds: 3));
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();
    _loadData();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _scaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      StreakService.getStudyHistory7Days(),
      StreakService.getStreakInfo(),
      CurrencyService.hasCheckedInToday(),
    ]);

    if (mounted) {
      setState(() {
        _history = results[0] as List<DayStatus>;
        _streakInfo = results[1] as StreakInfo;
        _checkedIn = results[2] as bool;
      });
    }
  }

  Future<void> _checkin() async {
    setState(() => _loading = true);
    final result = await CurrencyService.dailyCheckin();
    if (mounted) {
      setState(() {
        _loading = false;
        _result = result;
        _checkedIn = result.success || result.alreadyCheckedIn;
      });
      if (result.success) {
        _confettiCtrl.play();
        await _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Confetti
            ConfettiWidget(
              confettiController: _confettiCtrl,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.1,
              shouldLoop: false,
              colors: const [
                Color(0xFF667eea), Color(0xFFFF4757),
                Color(0xFF5352ED), Color(0xFF06D6A0), Color(0xFFFFBE0B),
              ],
            ),

            // Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header ──────────────────────
                      _buildHeader(),
                      const SizedBox(height: 20),

                      // ── Streak banner ────────────────
                      _StreakBanner(info: _streakInfo),
                      const SizedBox(height: 20),

                      // ── Lịch 7 ngày ─────────────────
                      _WeekCalendar(history: _history),
                      const SizedBox(height: 8),

                      // ── Ghi chú streak ───────────────
                      _StreakNote(info: _streakInfo),
                      const SizedBox(height: 20),

                      // ── Kết quả điểm danh ────────────
                      if (_result != null) ...[
                        _CheckinResultCard(result: _result!),
                        const SizedBox(height: 16),
                      ],

                      // ── Nút điểm danh ────────────────
                      _buildCheckinButton(),

                      const SizedBox(height: 12),

                      // ── Tip ──────────────────────────
                      _buildTip(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFBE0B), Color(0xFFFF9F1C)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFBE0B).withValues(alpha: 0.4),
                blurRadius: 10, offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(child: Text('📅', style: TextStyle(fontSize: 24))),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Điểm danh hàng ngày',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E)),
              ),
              Text(
                _checkedIn ? '✅ Đã điểm danh hôm nay' : 'Nhận Diamond miễn phí!',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
            child: const Icon(Icons.close, size: 16, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckinButton() {
    if (_checkedIn && _result == null) {
      // Đã điểm danh từ trước (load lúc init)
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: Colors.grey.shade300),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Đóng', style: TextStyle(color: Colors.grey, fontSize: 15)),
        ),
      );
    }

    if (_checkedIn && _result != null) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF06D6A0),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text('Tuyệt vời! 🎉', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _loading ? null : _checkin,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667eea),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : const Text('Điểm danh nhận 💎', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTip() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('💡', style: TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _streakInfo.hasStudiedToday
                  ? 'Bạn đã học hôm nay! Streak đang được duy trì 🔥'
                  : 'Học ít nhất 1 từ hôm nay để duy trì streak nhé!',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Streak Banner ────────────────────────────────────────────────────────────

class _StreakBanner extends StatelessWidget {
  final StreakInfo info;
  const _StreakBanner({required this.info});

  @override
  Widget build(BuildContext context) {
    final isActive = info.streak > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [const Color(0xFFFF6B35), const Color(0xFFFF4757)]
              : [Colors.grey.shade300, Colors.grey.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isActive ? const Color(0xFFFF4757) : Colors.grey)
                .withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Flame icon
          Text(
            isActive ? '🔥' : '💤',
            style: const TextStyle(fontSize: 36),
          ),
          const SizedBox(width: 14),
          // Streak info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${info.streak}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        'ngày streak',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  isActive
                      ? (info.hasStudiedToday
                          ? '✅ Đã học hôm nay — streak an toàn!'
                          : '⚠️ Chưa học hôm nay — streak sắp gãy!')
                      : 'Học bài để bắt đầu streak mới!',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Longest streak
          if (info.longestStreak > 0)
            Column(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 18)),
                Text(
                  '${info.longestStreak}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'kỷ lục',
                  style: TextStyle(color: Colors.white60, fontSize: 9),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Week Calendar ────────────────────────────────────────────────────────────

class _WeekCalendar extends StatelessWidget {
  final List<DayStatus> history;
  const _WeekCalendar({required this.history});

  static const _dayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: history.map((day) {
        final label = _dayLabels[day.date.weekday - 1];
        return _DayCell(status: day, label: label);
      }).toList(),
    );
  }
}

class _DayCell extends StatelessWidget {
  final DayStatus status;
  final String label;
  const _DayCell({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final isToday = status.type == DayStatusType.today;
    final isStudied = status.type == DayStatusType.studied;
    final isFreeze = status.type == DayStatusType.freezeUsed;

    Color bgColor;
    Color borderColor;
    Widget icon;

    if (isStudied) {
      bgColor = const Color(0xFF06D6A0);
      borderColor = const Color(0xFF06D6A0);
      icon = const Text('🔥', style: TextStyle(fontSize: 16));
    } else if (isFreeze) {
      bgColor = const Color(0xFF74B9FF);
      borderColor = const Color(0xFF74B9FF);
      icon = const Text('🧊', style: TextStyle(fontSize: 14));
    } else if (isToday) {
      bgColor = Colors.white;
      borderColor = const Color(0xFF667eea);
      icon = Text(
        '${status.date.day}',
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF667eea),
        ),
      );
    } else {
      // missed
      bgColor = Colors.grey.shade100;
      borderColor = Colors.grey.shade200;
      icon = Text(
        '${status.date.day}',
        style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
      );
    }

    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isToday ? const Color(0xFF667eea) : Colors.grey.shade500,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 5),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: isToday ? 2 : 1.5),
            boxShadow: isStudied
                ? [BoxShadow(
                    color: const Color(0xFF06D6A0).withValues(alpha: 0.3),
                    blurRadius: 6, offset: const Offset(0, 2),
                  )]
                : null,
          ),
          child: Center(child: icon),
        ),
        const SizedBox(height: 4),
        // Dot indicator
        Container(
          width: 4, height: 4,
          decoration: BoxDecoration(
            color: isStudied
                ? const Color(0xFF06D6A0)
                : isToday
                    ? const Color(0xFF667eea)
                    : Colors.transparent,
            shape: BoxShape.circle,
          ),
        ),
      ],
    );
  }
}

// ─── Streak Note ──────────────────────────────────────────────────────────────

class _StreakNote extends StatelessWidget {
  final StreakInfo info;
  const _StreakNote({required this.info});

  @override
  Widget build(BuildContext context) {
    if (info.freezeCount > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF74B9FF).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF74B9FF).withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧊', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              'Streak Freeze: ${info.freezeCount} lần',
              style: const TextStyle(
                fontSize: 11, color: Color(0xFF74B9FF), fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🔥', style: TextStyle(fontSize: 12)),
        const SizedBox(width: 4),
        Text(
          'Học bài mỗi ngày để tăng streak',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}

// ─── Checkin Result Card ──────────────────────────────────────────────────────

class _CheckinResultCard extends StatelessWidget {
  final CheckinResult result;
  const _CheckinResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result.alreadyCheckedIn) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Text('😺', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Đã điểm danh rồi!',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                  Text('Quay lại vào ngày mai nhé~',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withValues(alpha: 0.3),
            blurRadius: 10, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('💎', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '+${result.diamonds} Diamond',
                style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white,
                ),
              ),
              Text(
                'Điểm danh ${result.checkinStreak} ngày liên tiếp',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
