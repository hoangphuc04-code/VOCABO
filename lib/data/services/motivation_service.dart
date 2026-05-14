import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service gửi tin nhắn động viên, thúc giục người dùng học tập
class MotivationService {
  static const _lastMotivationKey = 'last_motivation_sent';

  // ── Tin nhắn động viên theo phong cách ────────────────
  static const _funMessages = [
    '😺 Meow~ Hôm nay bạn đã học chưa? Mèo đang chờ đấy!',
    '🐱 Purrr~ Chỉ 10 phút thôi là bạn giỏi hơn hôm qua rồi!',
    '😸 Meow meow! Streak của bạn đang chờ được duy trì nè~',
    '🐾 Bước nhỏ mỗi ngày = Tiến bộ lớn mỗi tháng! Học thôi nào!',
    '😺 Mèo nhắc: Từ vựng mới đang chờ bạn khám phá đó~',
    '🌟 Bạn đã học {{streak}} ngày liên tiếp rồi! Đừng để streak bị gãy nhé!',
    '📚 Chỉ cần {{goal}} phút hôm nay là đủ rồi! Bắt đầu nào~',
    '🎯 Mục tiêu {{target}} đang đến gần! Cố lên bạn ơi!',
  ];

  static const _gentleMessages = [
    '🌸 Chào bạn, hôm nay bạn có muốn học một chút không?',
    '💙 Nhớ dành thời gian cho bản thân nhé, kể cả việc học tiếng Anh~',
    '🌿 Mỗi ngày một chút, bạn sẽ tiến bộ rất nhiều đấy.',
    '☀️ Buổi sáng tốt lành! Học vài từ mới để khởi động ngày mới nhé?',
    '🌙 Trước khi ngủ, ôn lại vài từ hôm nay học nhé~',
  ];

  static const _strictMessages = [
    '⚡ Bạn chưa học hôm nay! Đừng để streak bị gãy!',
    '🔥 {{streak}} ngày streak — đừng phá vỡ nó hôm nay!',
    '💪 Không có lý do gì để không học {{goal}} phút hôm nay!',
    '🎯 Mục tiêu {{target}} không tự đến đâu! Học ngay đi!',
    '⏰ Đã {{hours}} giờ trôi qua mà bạn chưa học gì cả!',
  ];

  // ── Lấy tin nhắn động viên phù hợp ───────────────────
  static Future<String> getMotivationMessage() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return _funMessages[0];

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final userData = userDoc.data() ?? {};

      final style = userData['motivationStyle'] as String? ?? 'fun';
      final streak = userData['streak'] as int? ?? 0;
      final dailyGoal = userData['dailyGoalMinutes'] as int? ?? 30;
      final targetLevel = userData['targetLevel'] as String? ?? 'B2';

      List<String> pool;
      switch (style) {
        case 'gentle':
          pool = _gentleMessages;
          break;
        case 'strict':
          pool = _strictMessages;
          break;
        default:
          pool = _funMessages;
      }

      final msg = pool[Random().nextInt(pool.length)];
      return msg
          .replaceAll('{{streak}}', streak.toString())
          .replaceAll('{{goal}}', dailyGoal.toString())
          .replaceAll('{{target}}', targetLevel)
          .replaceAll('{{hours}}', DateTime.now().hour.toString());
    } catch (_) {
      return _funMessages[0];
    }
  }

  // ── Lưu notification vào Firestore (để hiển thị trong app) ──
  static Future<void> sendInAppMotivation() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      // Kiểm tra đã gửi trong 4 giờ qua chưa
      final prefs = await SharedPreferences.getInstance();
      final lastSent = prefs.getInt(_lastMotivationKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastSent < 4 * 60 * 60 * 1000) return; // 4 giờ

      final message = await getMotivationMessage();

      await FirebaseFirestore.instance.collection('user_notifications').add({
        'uid': uid,
        'title': '😺 Meow nhắc bạn!',
        'body': message,
        'type': 'motivation',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await prefs.setInt(_lastMotivationKey, now);
    } catch (_) {}
  }

  // ── Kiểm tra và gửi nhắc nhở học tập ─────────────────
  static Future<void> checkAndSendStudyReminder() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Kiểm tra xem hôm nay đã học chưa
      final sessions = await FirebaseFirestore.instance
          .collection('study_sessions')
          .where('uid', isEqualTo: uid)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      if (sessions.docs.isEmpty) {
        // Chưa học hôm nay → gửi nhắc nhở
        await _sendReminder(uid, 'study_reminder');
      }
    } catch (_) {}
  }

  static Future<void> _sendReminder(String uid, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'last_reminder_$type';
    final lastSent = prefs.getInt(key) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - lastSent < 6 * 60 * 60 * 1000) return; // 6 giờ

    final messages = {
      'study_reminder': '📚 Bạn chưa học hôm nay! Chỉ cần 10 phút thôi là đủ rồi~',
      'streak_warning': '🔥 Streak của bạn sắp bị gãy! Học ngay để giữ streak nhé!',
      'goal_reminder': '🎯 Hôm nay bạn đã đạt mục tiêu học tập chưa?',
    };

    await FirebaseFirestore.instance.collection('user_notifications').add({
      'uid': uid,
      'title': '😺 Meow nhắc bạn!',
      'body': messages[type] ?? messages['study_reminder'],
      'type': type,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await prefs.setInt(key, now);
  }

  // ── Lấy danh sách notifications chưa đọc ─────────────
  static Stream<List<Map<String, dynamic>>> getUnreadNotifications() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return FirebaseFirestore.instance
        .collection('user_notifications')
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {...d.data(), 'id': d.id})
            .toList());
  }

  // ── Đánh dấu đã đọc ───────────────────────────────────
  static Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance
        .collection('user_notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  static Future<void> markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snap = await FirebaseFirestore.instance
        .collection('user_notifications')
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
