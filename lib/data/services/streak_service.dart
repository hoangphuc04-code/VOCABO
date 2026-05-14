import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// StreakService — cơ chế streak giống Duolingo
///
/// Duolingo streak rules:
/// 1. Streak tăng khi hoàn thành ít nhất 1 bài học trong ngày
/// 2. Streak bị reset về 0 nếu bỏ qua 1 ngày (không học)
/// 3. Streak KHÔNG tăng khi điểm danh — phải học thật sự
/// 4. Có "Streak Freeze" (bảo vệ streak 1 ngày) — mua bằng Diamond
/// 5. Lịch sử lưu từng ngày thực tế (không ước tính)
class StreakService {
  static const int streakFreezeCost = 10; // 10💎 để mua 1 streak freeze

  // ── Key format ngày ───────────────────────────────────
  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String get _todayKey => _dayKey(DateTime.now());

  // ── Ghi nhận hoàn thành bài học hôm nay ──────────────
  /// Gọi sau khi user hoàn thành ít nhất 1 từ/bài học
  /// Returns: StreakResult với streak mới và có tăng không
  static Future<StreakResult> recordLessonCompleted() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return StreakResult(streak: 0, increased: false, isNewRecord: false);
    }

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    StreakResult result = StreakResult(streak: 0, increased: false, isNewRecord: false);

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};

      final today = _todayKey;
      final lastStudyDate = data['lastStudyDate'] as String? ?? '';
      final currentStreak = (data['streak'] ?? 0).toInt();
      final longestStreak = (data['longestStreak'] ?? 0).toInt();
      final hasStreakFreeze = (data['streakFreezeCount'] ?? 0).toInt() > 0;

      // Đã học hôm nay rồi → không tăng streak nữa
      if (lastStudyDate == today) {
        result = StreakResult(
          streak: currentStreak,
          increased: false,
          isNewRecord: false,
          alreadyStudiedToday: true,
        );
        return;
      }

      final now = DateTime.now();
      final yesterday = _dayKey(now.subtract(const Duration(days: 1)));

      int newStreak;

      if (lastStudyDate == yesterday) {
        // Học liên tiếp → tăng streak
        newStreak = currentStreak + 1;
      } else if (lastStudyDate.isEmpty) {
        // Lần đầu học
        newStreak = 1;
      } else {
        // Bỏ qua ít nhất 1 ngày
        // Kiểm tra streak freeze
        if (hasStreakFreeze && _wasYesterdayMissed(lastStudyDate, now)) {
          // Dùng streak freeze để bảo vệ
          newStreak = currentStreak + 1;
          tx.update(ref, {
            'streakFreezeCount': FieldValue.increment(-1),
            'streakFreezeUsedAt': today,
          });
        } else {
          // Reset streak
          newStreak = 1;
        }
      }

      final newLongest = newStreak > longestStreak ? newStreak : longestStreak;
      final isNewRecord = newStreak > longestStreak;

      // Lưu ngày học vào lịch sử
      final historyRef = ref.collection('study_history').doc(today);

      tx.update(ref, {
        'streak': newStreak,
        'longestStreak': newLongest,
        'lastStudyDate': today,
        'lastStudyAt': FieldValue.serverTimestamp(),
      });

      // Lưu vào study_history sub-collection
      tx.set(historyRef, {
        'date': today,
        'studiedAt': FieldValue.serverTimestamp(),
        'streakOnThisDay': newStreak,
      });

      result = StreakResult(
        streak: newStreak,
        increased: true,
        isNewRecord: isNewRecord,
        longestStreak: newLongest,
      );
    });

    return result;
  }

  // ── Kiểm tra hôm qua có bị bỏ qua không ─────────────
  static bool _wasYesterdayMissed(String lastStudyDate, DateTime now) {
    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));
    // Nếu lastStudyDate không phải hôm qua → đã bỏ qua hôm qua
    return lastStudyDate != yesterday;
  }

  // ── Kiểm tra streak có bị gãy không ──────────────────
  /// Gọi khi mở app để kiểm tra và reset streak nếu cần
  static Future<StreakCheckResult> checkAndUpdateStreak() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return StreakCheckResult(streak: 0, wasBroken: false);

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    final snap = await ref.get();
    final data = snap.data() ?? {};

    final lastStudyDate = data['lastStudyDate'] as String? ?? '';
    final currentStreak = (data['streak'] ?? 0).toInt();
    final hasStreakFreeze = (data['streakFreezeCount'] ?? 0).toInt() > 0;

    if (lastStudyDate.isEmpty || currentStreak == 0) {
      return StreakCheckResult(streak: 0, wasBroken: false);
    }

    final now = DateTime.now();
    final today = _todayKey;
    final yesterday = _dayKey(now.subtract(const Duration(days: 1)));

    // Đã học hôm nay hoặc hôm qua → streak còn nguyên
    if (lastStudyDate == today || lastStudyDate == yesterday) {
      return StreakCheckResult(streak: currentStreak, wasBroken: false);
    }

    // Bỏ qua hơn 1 ngày
    if (hasStreakFreeze) {
      // Dùng streak freeze tự động
      await ref.update({
        'streakFreezeCount': FieldValue.increment(-1),
        'streakFreezeUsedAt': today,
        'lastStudyDate': yesterday, // giả lập đã học hôm qua
      });
      return StreakCheckResult(
        streak: currentStreak,
        wasBroken: false,
        usedStreakFreeze: true,
      );
    }

    // Reset streak
    await ref.update({'streak': 0});
    return StreakCheckResult(
      streak: 0,
      wasBroken: true,
      previousStreak: currentStreak,
    );
  }

  // ── Lấy lịch sử học 7 ngày thực tế ──────────────────
  static Future<List<DayStatus>> getStudyHistory7Days() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _emptyHistory();

    final now = DateTime.now();

    // Lấy 7 ngày gần nhất từ sub-collection
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('study_history')
        .orderBy('date', descending: true)
        .limit(7)
        .get();

    final studiedDays = <String>{};
    for (final doc in snap.docs) {
      studiedDays.add(doc.id); // doc.id = date key (YYYY-MM-DD)
    }

    // Lấy thêm thông tin streak freeze
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final freezeUsedAt = userDoc.data()?['streakFreezeUsedAt'] as String? ?? '';

    final result = <DayStatus>[];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key = _dayKey(day);
      final isToday = i == 0;

      DayStatusType type;
      if (studiedDays.contains(key)) {
        type = DayStatusType.studied;
      } else if (key == freezeUsedAt) {
        type = DayStatusType.freezeUsed;
      } else if (isToday) {
        type = DayStatusType.today;
      } else {
        type = DayStatusType.missed;
      }

      result.add(DayStatus(date: day, type: type));
    }

    return result;
  }

  static List<DayStatus> _emptyHistory() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final day = now.subtract(Duration(days: 6 - i));
      return DayStatus(
        date: day,
        type: i == 6 ? DayStatusType.today : DayStatusType.missed,
      );
    });
  }

  // ── Mua Streak Freeze ─────────────────────────────────
  static Future<({bool success, String message})> buyStreakFreeze() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return (success: false, message: 'Chưa đăng nhập');

    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    bool success = false;
    String message = '';

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final data = snap.data() ?? {};
      final diamonds = (data['diamonds'] ?? 0).toInt();
      final freezeCount = (data['streakFreezeCount'] ?? 0).toInt();

      if (freezeCount >= 2) {
        message = 'Bạn đã có đủ Streak Freeze rồi!';
        return;
      }
      if (diamonds < streakFreezeCost) {
        message = 'Không đủ 💎 (cần $streakFreezeCost, có $diamonds)';
        return;
      }

      tx.update(ref, {
        'diamonds': diamonds - streakFreezeCost,
        'streakFreezeCount': freezeCount + 1,
      });
      success = true;
      message = '✅ Đã mua Streak Freeze! (-${streakFreezeCost}💎)';
    });

    return (success: success, message: message);
  }

  // ── Lấy thông tin streak hiện tại ────────────────────
  static Future<StreakInfo> getStreakInfo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const StreakInfo(streak: 0, longestStreak: 0, freezeCount: 0, hasStudiedToday: false);

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final data = doc.data() ?? {};

    final lastStudyDate = data['lastStudyDate'] as String? ?? '';
    final hasStudiedToday = lastStudyDate == _todayKey;

    return StreakInfo(
      streak: (data['streak'] ?? 0).toInt(),
      longestStreak: (data['longestStreak'] ?? 0).toInt(),
      freezeCount: (data['streakFreezeCount'] ?? 0).toInt(),
      hasStudiedToday: hasStudiedToday,
      lastStudyDate: lastStudyDate,
    );
  }

  // ── Stream streak realtime ────────────────────────────
  static Stream<StreakInfo> streakStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value(
          const StreakInfo(streak: 0, longestStreak: 0, freezeCount: 0, hasStudiedToday: false));
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
      final data = doc.data() ?? {};
      final lastStudyDate = data['lastStudyDate'] as String? ?? '';
      return StreakInfo(
        streak: (data['streak'] ?? 0).toInt(),
        longestStreak: (data['longestStreak'] ?? 0).toInt(),
        freezeCount: (data['streakFreezeCount'] ?? 0).toInt(),
        hasStudiedToday: lastStudyDate == _todayKey,
        lastStudyDate: lastStudyDate,
      );
    });
  }
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class StreakResult {
  final int streak;
  final bool increased;
  final bool isNewRecord;
  final int longestStreak;
  final bool alreadyStudiedToday;

  const StreakResult({
    required this.streak,
    required this.increased,
    required this.isNewRecord,
    this.longestStreak = 0,
    this.alreadyStudiedToday = false,
  });
}

class StreakCheckResult {
  final int streak;
  final bool wasBroken;
  final int previousStreak;
  final bool usedStreakFreeze;

  const StreakCheckResult({
    required this.streak,
    required this.wasBroken,
    this.previousStreak = 0,
    this.usedStreakFreeze = false,
  });
}

class StreakInfo {
  final int streak;
  final int longestStreak;
  final int freezeCount;
  final bool hasStudiedToday;
  final String lastStudyDate;

  const StreakInfo({
    required this.streak,
    required this.longestStreak,
    required this.freezeCount,
    required this.hasStudiedToday,
    this.lastStudyDate = '',
  });
}

enum DayStatusType {
  studied,    // ✅ Đã học
  missed,     // ❌ Bỏ qua
  today,      // 📅 Hôm nay (chưa học)
  freezeUsed, // 🧊 Dùng streak freeze
}

class DayStatus {
  final DateTime date;
  final DayStatusType type;
  const DayStatus({required this.date, required this.type});
}
