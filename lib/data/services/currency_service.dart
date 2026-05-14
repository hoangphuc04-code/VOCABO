import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// CurrencyService — quản lý Diamond 💎 và Heart ❤️
///
/// TÁCH BIỆT với StreakService:
/// - Streak = học bài mỗi ngày (StreakService)
/// - Checkin = điểm danh để nhận Diamond (CurrencyService)
/// - Diamond = tiền tệ, dùng mua Heart / Streak Freeze
class CurrencyService {
  static const int maxHearts = 5;
  static const int heartRefillCost = 5;   // 5💎 = 1❤️
  static const int fullRefillCost = 20;   // 20💎 = 5❤️
  static const int heartRecoverMinutes = 30;

  // ── Stream currency realtime ──────────────────────────
  static Stream<Map<String, dynamic>> currencyStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(_defaultCurrency());

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => _parseCurrency(doc.data() ?? {}));
  }

  static Map<String, dynamic> _defaultCurrency() => {
        'hearts': maxHearts,
        'diamonds': 0,
        'lastHeartLostAt': null,
        'lastCheckinDate': null,
        'checkinStreak': 0,
      };

  static Map<String, dynamic> _parseCurrency(Map<String, dynamic> data) => {
        'hearts': (data['hearts'] ?? maxHearts).toInt(),
        'diamonds': (data['diamonds'] ?? 0).toInt(),
        'lastHeartLostAt': data['lastHeartLostAt'],
        'lastCheckinDate': data['lastCheckinDate'],
        'checkinStreak': (data['checkinStreak'] ?? 0).toInt(),
      };

  // ── Lấy currency một lần ─────────────────────────────
  static Future<Map<String, dynamic>> getCurrency() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _defaultCurrency();
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return _parseCurrency(doc.data() ?? {});
  }

  // ── Tiêu hao 1 heart ─────────────────────────────────
  static Future<int> loseHeart() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return -1;

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    int remaining = -1;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final current = (snap.data()?['hearts'] ?? maxHearts).toInt();
      if (current <= 0) { remaining = 0; return; }
      remaining = current - 1;
      tx.update(ref, {
        'hearts': remaining,
        'lastHeartLostAt': FieldValue.serverTimestamp(),
      });
    });

    return remaining;
  }

  // ── Hồi phục heart theo thời gian ────────────────────
  static Future<void> checkHeartRecovery() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};
    final hearts = (data['hearts'] ?? maxHearts).toInt();
    if (hearts >= maxHearts) return;

    final lastLostAt = data['lastHeartLostAt'] as Timestamp?;
    if (lastLostAt == null) return;

    final elapsed = DateTime.now().difference(lastLostAt.toDate());
    final toRecover =
        (elapsed.inMinutes ~/ heartRecoverMinutes).clamp(0, maxHearts - hearts);

    if (toRecover > 0) {
      await ref.update({'hearts': (hearts + toRecover).clamp(0, maxHearts)});
    }
  }

  // ── Mua 1 heart ──────────────────────────────────────
  static Future<({bool success, String message})> buyHeart() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return (success: false, message: 'Chưa đăng nhập');

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    bool success = false;
    String message = '';

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final data = (await tx.get(ref)).data() ?? {};
      final hearts = (data['hearts'] ?? maxHearts).toInt();
      final diamonds = (data['diamonds'] ?? 0).toInt();

      if (hearts >= maxHearts) { message = 'Tim đã đầy rồi! ❤️'; return; }
      if (diamonds < heartRefillCost) {
        message = 'Không đủ 💎 (cần $heartRefillCost, có $diamonds)';
        return;
      }
      tx.update(ref, {
        'hearts': hearts + 1,
        'diamonds': diamonds - heartRefillCost,
      });
      success = true;
      message = '✅ Đã mua 1 ❤️ (-${heartRefillCost}💎)';
    });

    return (success: success, message: message);
  }

  // ── Mua full hearts ───────────────────────────────────
  static Future<({bool success, String message})> buyFullHearts() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return (success: false, message: 'Chưa đăng nhập');

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    bool success = false;
    String message = '';

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final data = (await tx.get(ref)).data() ?? {};
      final hearts = (data['hearts'] ?? maxHearts).toInt();
      final diamonds = (data['diamonds'] ?? 0).toInt();

      if (hearts >= maxHearts) { message = 'Tim đã đầy rồi! ❤️'; return; }
      if (diamonds < fullRefillCost) {
        message = 'Không đủ 💎 (cần $fullRefillCost, có $diamonds)';
        return;
      }
      tx.update(ref, {
        'hearts': maxHearts,
        'diamonds': diamonds - fullRefillCost,
      });
      success = true;
      message = '✅ Đã hồi phục đầy ❤️ (-${fullRefillCost}💎)';
    });

    return (success: success, message: message);
  }

  // ── Điểm danh hàng ngày (chỉ tặng Diamond) ───────────
  /// Streak KHÔNG tăng ở đây — streak tăng khi học bài (StreakService)
  static Future<CheckinResult> dailyCheckin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return CheckinResult(success: false, diamonds: 0, message: 'Chưa đăng nhập', checkinStreak: 0);
    }

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final now = DateTime.now();
    final todayKey = _dayKey(now);

    CheckinResult result = CheckinResult(success: false, diamonds: 0, message: '', checkinStreak: 0);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final data = (await tx.get(ref)).data() ?? {};

      final lastCheckinDate = data['lastCheckinDate'] as String? ?? '';
      final checkinStreak = (data['checkinStreak'] ?? 0).toInt();
      final diamonds = (data['diamonds'] ?? 0).toInt();

      // Đã điểm danh hôm nay
      if (lastCheckinDate == todayKey) {
        result = CheckinResult(
          success: false,
          diamonds: 0,
          message: 'Bạn đã điểm danh hôm nay rồi! 😺',
          checkinStreak: checkinStreak,
          alreadyCheckedIn: true,
        );
        return;
      }

      // Tính checkin streak (riêng biệt với study streak)
      final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
      final newCheckinStreak =
          lastCheckinDate == yesterday ? checkinStreak + 1 : 1;

      // Diamond theo checkin streak
      final diamondsEarned = _calcDiamonds(newCheckinStreak);

      tx.update(ref, {
        'lastCheckinDate': todayKey,
        'checkinStreak': newCheckinStreak,
        'diamonds': diamonds + diamondsEarned,
        'lastCheckinAt': FieldValue.serverTimestamp(),
      });

      result = CheckinResult(
        success: true,
        diamonds: diamondsEarned,
        message: '🎉 Điểm danh thành công! +${diamondsEarned}💎',
        checkinStreak: newCheckinStreak,
      );
    });

    return result;
  }

  static int _calcDiamonds(int checkinStreak) {
    if (checkinStreak >= 30) return 20;
    if (checkinStreak >= 14) return 15;
    if (checkinStreak >= 7)  return 12;
    if (checkinStreak >= 3)  return 8;
    return 5;
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Kiểm tra đã điểm danh hôm nay chưa ───────────────
  static Future<bool> hasCheckedInToday() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final lastCheckinDate = doc.data()?['lastCheckinDate'] as String? ?? '';
    return lastCheckinDate == _dayKey(DateTime.now());
  }

  // ── Khởi tạo currency cho user mới ───────────────────
  static Future<void> initCurrencyIfNeeded() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};

    final updates = <String, dynamic>{};
    if (!data.containsKey('hearts'))          updates['hearts'] = maxHearts;
    if (!data.containsKey('diamonds'))        updates['diamonds'] = 10;
    if (!data.containsKey('streak'))          updates['streak'] = 0;
    if (!data.containsKey('longestStreak'))   updates['longestStreak'] = 0;
    if (!data.containsKey('streakFreezeCount')) updates['streakFreezeCount'] = 0;
    if (!data.containsKey('checkinStreak'))   updates['checkinStreak'] = 0;

    if (updates.isNotEmpty) {
      await ref.set(updates, SetOptions(merge: true));
    }
  }

  // ── Thời gian hồi phục heart tiếp theo ───────────────
  static Future<Duration?> nextHeartRecoveryIn() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data() ?? {};
    final hearts = (data['hearts'] ?? maxHearts).toInt();
    if (hearts >= maxHearts) return null;

    final lastLostAt = data['lastHeartLostAt'] as Timestamp?;
    if (lastLostAt == null) return null;

    final next = lastLostAt.toDate().add(Duration(minutes: heartRecoverMinutes));
    final remaining = next.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

// ─── Result classes ───────────────────────────────────────────────────────────

class CheckinResult {
  final bool success;
  final int diamonds;
  final String message;
  final int checkinStreak;
  final bool alreadyCheckedIn;

  const CheckinResult({
    required this.success,
    required this.diamonds,
    required this.message,
    required this.checkinStreak,
    this.alreadyCheckedIn = false,
  });
}
