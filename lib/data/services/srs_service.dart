import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// SRS Service — Spaced Repetition System (SM-2 Algorithm)
///
/// Firestore: vocabulary_progress/{uid_wordId}
///   - ease_factor: double (2.5 default)
///   - interval: int (days)
///   - repetitions: int
///   - next_review: Timestamp
///   - last_review: Timestamp
///   - strength: double (0.0 - 1.0)
class SrsService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  // ── SM-2 Algorithm ────────────────────────────────────
  // quality: 0-5 (0=blackout, 3=correct with difficulty, 5=perfect)
  static SrsCard computeNextReview(SrsCard card, int quality) {
    double ef = card.easeFactor;
    int interval = card.interval;
    int reps = card.repetitions;

    if (quality >= 3) {
      // Correct response
      if (reps == 0) {
        interval = 1;
      } else if (reps == 1) {
        interval = 6;
      } else {
        interval = (interval * ef).round();
      }
      reps++;
    } else {
      // Incorrect — reset
      reps = 0;
      interval = 1;
    }

    // Update ease factor
    ef = ef + (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02));
    if (ef < 1.3) ef = 1.3;

    final nextReview = DateTime.now().add(Duration(days: interval));
    final strength = (quality / 5.0).clamp(0.0, 1.0);

    return SrsCard(
      wordId: card.wordId,
      topicId: card.topicId,
      word: card.word,
      meaning: card.meaning,
      phonetic: card.phonetic,
      example: card.example,
      exampleVi: card.exampleVi,
      imageUrl: card.imageUrl,
      easeFactor: ef,
      interval: interval,
      repetitions: reps,
      nextReview: nextReview,
      lastReview: DateTime.now(),
      strength: strength,
    );
  }

  // ── Lưu kết quả ôn tập ───────────────────────────────
  static Future<void> recordReview({
    required String wordId,
    required String topicId,
    required int quality, // 0-5
  }) async {
    if (_uid.isEmpty) return;
    final docId = '${_uid}_$wordId';
    final ref = _db.collection('vocabulary_progress').doc(docId);
    final snap = await ref.get();

    SrsCard card;
    if (snap.exists) {
      card = SrsCard.fromMap(snap.data()!, wordId: wordId, topicId: topicId);
    } else {
      // Lấy thông tin từ learned_words
      final wordSnap = await _db
          .collection('users')
          .doc(_uid)
          .collection('learned_words')
          .where('wordId', isEqualTo: wordId)
          .limit(1)
          .get();
      final wordData = wordSnap.docs.isNotEmpty
          ? wordSnap.docs.first.data()
          : <String, dynamic>{};
      card = SrsCard.newCard(
        wordId: wordId,
        topicId: topicId,
        word: wordData['word'] ?? '',
        meaning: wordData['meaning'] ?? '',
        phonetic: wordData['phonetic'] ?? '',
        example: wordData['example'] ?? '',
        exampleVi: wordData['exampleVi'] ?? '',
        imageUrl: wordData['imageUrl'] ?? '',
      );
    }

    final updated = computeNextReview(card, quality);
    await ref.set({
      'uid': _uid,
      'wordId': wordId,
      'topicId': topicId,
      'word': updated.word,
      'meaning': updated.meaning,
      'phonetic': updated.phonetic,
      'example': updated.example,
      'exampleVi': updated.exampleVi,
      'imageUrl': updated.imageUrl,
      'easeFactor': updated.easeFactor,
      'interval': updated.interval,
      'repetitions': updated.repetitions,
      'nextReview': Timestamp.fromDate(updated.nextReview),
      'lastReview': Timestamp.fromDate(updated.lastReview),
      'strength': updated.strength,
    }, SetOptions(merge: true));
  }

  // ── Lấy từ cần ôn hôm nay ────────────────────────────
  static Future<List<SrsCard>> getDueCards({int limit = 20}) async {
    if (_uid.isEmpty) return [];
    final now = Timestamp.fromDate(DateTime.now());
    final snap = await _db
        .collection('vocabulary_progress')
        .where('uid', isEqualTo: _uid)
        .where('nextReview', isLessThanOrEqualTo: now)
        .orderBy('nextReview')
        .limit(limit)
        .get();

    return snap.docs.map((doc) {
      final d = doc.data();
      return SrsCard.fromMap(d, wordId: d['wordId'] ?? '', topicId: d['topicId'] ?? '');
    }).toList();
  }

  // ── Đếm từ cần ôn hôm nay ────────────────────────────
  static Future<int> getDueCount() async {
    if (_uid.isEmpty) return 0;
    final now = Timestamp.fromDate(DateTime.now());
    final snap = await _db
        .collection('vocabulary_progress')
        .where('uid', isEqualTo: _uid)
        .where('nextReview', isLessThanOrEqualTo: now)
        .count()
        .get();
    return snap.count ?? 0;
  }

  // ── Stream đếm realtime ───────────────────────────────
  static Stream<int> dueCountStream() {
    if (_uid.isEmpty) return Stream.value(0);
    final now = Timestamp.fromDate(DateTime.now());
    return _db
        .collection('vocabulary_progress')
        .where('uid', isEqualTo: _uid)
        .where('nextReview', isLessThanOrEqualTo: now)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ── Lấy tất cả cards của user ─────────────────────────
  static Future<List<SrsCard>> getAllCards() async {
    if (_uid.isEmpty) return [];
    final snap = await _db
        .collection('vocabulary_progress')
        .where('uid', isEqualTo: _uid)
        .orderBy('nextReview')
        .get();
    return snap.docs.map((doc) {
      final d = doc.data();
      return SrsCard.fromMap(d, wordId: d['wordId'] ?? '', topicId: d['topicId'] ?? '');
    }).toList();
  }

  // ── Khởi tạo SRS cho từ đã học (migrate) ─────────────
  static Future<void> initSrsForLearnedWords() async {
    if (_uid.isEmpty) return;
    final learnedSnap = await _db
        .collection('users')
        .doc(_uid)
        .collection('learned_words')
        .get();

    final batch = _db.batch();
    for (final doc in learnedSnap.docs) {
      final d = doc.data();
      final wordId = d['wordId'] as String? ?? '';
      if (wordId.isEmpty) continue;
      final docId = '${_uid}_$wordId';
      final ref = _db.collection('vocabulary_progress').doc(docId);
      final existing = await ref.get();
      if (!existing.exists || !(existing.data()?.containsKey('easeFactor') ?? false)) {
        batch.set(ref, {
          'uid': _uid,
          'wordId': wordId,
          'topicId': d['topicId'] ?? '',
          'word': d['word'] ?? '',
          'meaning': d['meaning'] ?? '',
          'phonetic': d['phonetic'] ?? '',
          'example': d['example'] ?? '',
          'exampleVi': d['exampleVi'] ?? '',
          'imageUrl': d['imageUrl'] ?? '',
          'easeFactor': 2.5,
          'interval': 1,
          'repetitions': 0,
          'nextReview': Timestamp.fromDate(DateTime.now()),
          'lastReview': Timestamp.fromDate(DateTime.now()),
          'strength': 0.5,
        }, SetOptions(merge: true));
      }
    }
    await batch.commit();
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class SrsCard {
  final String wordId;
  final String topicId;
  final String word;
  final String meaning;
  final String phonetic;
  final String example;
  final String exampleVi;
  final String imageUrl;
  final double easeFactor;
  final int interval;
  final int repetitions;
  final DateTime nextReview;
  final DateTime lastReview;
  final double strength;

  const SrsCard({
    required this.wordId,
    required this.topicId,
    required this.word,
    required this.meaning,
    required this.phonetic,
    required this.example,
    required this.exampleVi,
    required this.imageUrl,
    required this.easeFactor,
    required this.interval,
    required this.repetitions,
    required this.nextReview,
    required this.lastReview,
    required this.strength,
  });

  factory SrsCard.newCard({
    required String wordId,
    required String topicId,
    required String word,
    required String meaning,
    required String phonetic,
    required String example,
    required String exampleVi,
    required String imageUrl,
  }) =>
      SrsCard(
        wordId: wordId,
        topicId: topicId,
        word: word,
        meaning: meaning,
        phonetic: phonetic,
        example: example,
        exampleVi: exampleVi,
        imageUrl: imageUrl,
        easeFactor: 2.5,
        interval: 1,
        repetitions: 0,
        nextReview: DateTime.now(),
        lastReview: DateTime.now(),
        strength: 0.5,
      );

  factory SrsCard.fromMap(Map<String, dynamic> d,
      {required String wordId, required String topicId}) =>
      SrsCard(
        wordId: wordId,
        topicId: topicId,
        word: d['word'] ?? '',
        meaning: d['meaning'] ?? '',
        phonetic: d['phonetic'] ?? '',
        example: d['example'] ?? '',
        exampleVi: d['exampleVi'] ?? '',
        imageUrl: d['imageUrl'] ?? '',
        easeFactor: (d['easeFactor'] ?? 2.5).toDouble(),
        interval: (d['interval'] ?? 1).toInt(),
        repetitions: (d['repetitions'] ?? 0).toInt(),
        nextReview: d['nextReview'] != null
            ? (d['nextReview'] as Timestamp).toDate()
            : DateTime.now(),
        lastReview: d['lastReview'] != null
            ? (d['lastReview'] as Timestamp).toDate()
            : DateTime.now(),
        strength: (d['strength'] ?? 0.5).toDouble(),
      );

  bool get isDue => DateTime.now().isAfter(nextReview);

  String get strengthLabel {
    if (strength >= 0.9) return 'Thuộc lòng ⭐';
    if (strength >= 0.7) return 'Nhớ tốt 💪';
    if (strength >= 0.5) return 'Đang học 📖';
    if (strength >= 0.3) return 'Cần ôn 🔄';
    return 'Mới học 🌱';
  }

  String get nextReviewLabel {
    final diff = nextReview.difference(DateTime.now());
    if (diff.isNegative) return 'Cần ôn ngay!';
    if (diff.inMinutes < 60) return 'Sau ${diff.inMinutes} phút';
    if (diff.inHours < 24) return 'Sau ${diff.inHours} giờ';
    return 'Sau ${diff.inDays} ngày';
  }
}
