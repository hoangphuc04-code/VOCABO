import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// GameService — quản lý Gold Coin 🪙, tiến độ game, leaderboard
///
/// Firestore:
/// users/{uid}.coins          — số coin hiện tại
/// users/{uid}.totalCoinsEarned — tổng coin đã kiếm
/// game_progress/{uid}/levels/{gameType_level} — tiến độ từng màn
/// game_scores/{docId}        — leaderboard
class GameService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── Coin rewards theo màn ─────────────────────────────
  static int coinReward(int level, int stars) {
    final base = 10 + (level - 1) * 5; // màn 1=10, màn 2=15, ...
    return (base * stars / 3).round();  // 1★=33%, 2★=67%, 3★=100%
  }

  // ── Thêm coin ─────────────────────────────────────────
  static Future<void> addCoins(int amount) async {
    if (_uid.isEmpty || amount <= 0) return;
    await _db.collection('users').doc(_uid).update({
      'coins': FieldValue.increment(amount),
      'totalCoinsEarned': FieldValue.increment(amount),
    });
  }

  // ── Tiêu coin ─────────────────────────────────────────
  static Future<bool> spendCoins(int amount) async {
    if (_uid.isEmpty) return false;
    final ref = _db.collection('users').doc(_uid);
    bool ok = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final coins = (snap.data()?['coins'] ?? 0).toInt();
      if (coins < amount) return;
      tx.update(ref, {'coins': coins - amount});
      ok = true;
    });
    return ok;
  }

  // ── Stream coin realtime ──────────────────────────────
  static Stream<int> coinsStream() {
    if (_uid.isEmpty) return Stream.value(0);
    return _db
        .collection('users')
        .doc(_uid)
        .snapshots()
        .map((d) => (d.data()?['coins'] ?? 0).toInt());
  }

  // ── Lưu kết quả màn chơi ─────────────────────────────
  static Future<void> saveLevel({
    required String gameType,
    required int level,
    required int stars,      // 1-3
    required int score,
    required int timeSeconds,
  }) async {
    if (_uid.isEmpty) return;

    final docId = '${_uid}_${gameType}_$level';
    final ref = _db.collection('game_progress').doc(docId);
    final snap = await ref.get();
    final prev = snap.data();

    // Chỉ lưu nếu tốt hơn lần trước
    final prevStars = (prev?['stars'] ?? 0).toInt();
    final prevScore = (prev?['score'] ?? 0).toInt();

    if (stars > prevStars || (stars == prevStars && score > prevScore)) {
      await ref.set({
        'uid': _uid,
        'gameType': gameType,
        'level': level,
        'stars': stars,
        'score': score,
        'timeSeconds': timeSeconds,
        'completedAt': FieldValue.serverTimestamp(),
      });
    }

    // Lưu leaderboard
    await _db.collection('game_scores').doc(docId).set({
      'uid': _uid,
      'gameType': gameType,
      'level': level,
      'score': score,
      'stars': stars,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ── Lấy tiến độ tất cả màn của 1 game ────────────────
  static Future<Map<int, LevelProgress>> getLevelProgress(
      String gameType) async {
    if (_uid.isEmpty) return {};
    final snap = await _db
        .collection('game_progress')
        .where('uid', isEqualTo: _uid)
        .where('gameType', isEqualTo: gameType)
        .get();

    final map = <int, LevelProgress>{};
    for (final doc in snap.docs) {
      final d = doc.data();
      final level = (d['level'] as int);
      map[level] = LevelProgress(
        level: level,
        stars: (d['stars'] ?? 0).toInt(),
        score: (d['score'] ?? 0).toInt(),
        timeSeconds: (d['timeSeconds'] ?? 0).toInt(),
      );
    }
    return map;
  }

  // ── Leaderboard của 1 game ────────────────────────────
  static Future<List<LeaderboardEntry>> getLeaderboard(
      String gameType, int level) async {
    final snap = await _db
        .collection('game_scores')
        .where('gameType', isEqualTo: gameType)
        .where('level', isEqualTo: level)
        .orderBy('score', descending: true)
        .limit(20)
        .get();

    final entries = <LeaderboardEntry>[];
    for (final doc in snap.docs) {
      final d = doc.data();
      final uid = d['uid'] as String;
      // Lấy thông tin user
      final userDoc = await _db.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? {};
      entries.add(LeaderboardEntry(
        uid: uid,
        name: userData['displayName'] ?? 'Người chơi',
        photoURL: userData['photoURL'] ?? '',
        score: (d['score'] ?? 0).toInt(),
        stars: (d['stars'] ?? 0).toInt(),
      ));
    }
    return entries;
  }

  // ── Thêm kim cương ────────────────────────────────────
  static Future<void> addDiamonds(int amount) async {
    if (_uid.isEmpty || amount <= 0) return;
    await _db.collection('users').doc(_uid).update({
      'diamonds': FieldValue.increment(amount),
    });
  }

  // ── Tiêu kim cương ────────────────────────────────────
  static Future<bool> spendDiamonds(int amount) async {
    if (_uid.isEmpty) return false;
    final ref = _db.collection('users').doc(_uid);
    bool ok = false;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final diamonds = (snap.data()?['diamonds'] ?? 0).toInt();
      if (diamonds < amount) return;
      tx.update(ref, {'diamonds': diamonds - amount});
      ok = true;
    });
    return ok;
  }

  // ── Khởi tạo coins cho user mới ──────────────────────
  static Future<void> initCoinsIfNeeded() async {
    if (_uid.isEmpty) return;
    final ref = _db.collection('users').doc(_uid);
    final snap = await ref.get();
    if (!(snap.data()?.containsKey('coins') ?? false)) {
      await ref.set({'coins': 50, 'totalCoinsEarned': 50, 'diamonds': 10},
          SetOptions(merge: true));
    } else if (!(snap.data()?.containsKey('diamonds') ?? false)) {
      await ref.set({'diamonds': 10}, SetOptions(merge: true));
    }
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class LevelProgress {
  final int level;
  final int stars;
  final int score;
  final int timeSeconds;
  const LevelProgress({
    required this.level,
    required this.stars,
    required this.score,
    required this.timeSeconds,
  });
  bool get isCompleted => stars > 0;
}

class LeaderboardEntry {
  final String uid;
  final String name;
  final String photoURL;
  final int score;
  final int stars;
  const LeaderboardEntry({
    required this.uid,
    required this.name,
    required this.photoURL,
    required this.score,
    required this.stars,
  });
}
