import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// BattleService — Battle Mode 1v1 Realtime
///
/// Firestore:
/// battle_rooms/{roomId}
///   - player1: {uid, name, photo, score, ready}
///   - player2: {uid, name, photo, score, ready}
///   - status: 'waiting' | 'countdown' | 'playing' | 'finished'
///   - currentQuestion: {word, options, correctIndex, startedAt}
///   - questionIndex: int
///   - totalQuestions: int
///   - winner: uid | 'draw'
///   - createdAt: Timestamp
///
/// battle_matchmaking/{uid}
///   - uid, name, photo, level, joinedAt
class BattleService {
  static final _db = FirebaseFirestore.instance;
  static String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  static const int totalQuestions = 10;
  static const int questionTimeSeconds = 8;

  // ── Tìm phòng hoặc tạo phòng mới ─────────────────────
  static Future<String> findOrCreateRoom() async {
    if (_uid.isEmpty) throw Exception('Chưa đăng nhập');

    final userDoc = await _db.collection('users').doc(_uid).get();
    final userData = userDoc.data() ?? {};
    final myName = userData['displayName'] ?? 'Player';
    final myPhoto = userData['photoURL'] ?? '';

    // Tìm phòng đang chờ
    final waiting = await _db
        .collection('battle_rooms')
        .where('status', isEqualTo: 'waiting')
        .where('player2.uid', isEqualTo: '')
        .orderBy('createdAt')
        .limit(5)
        .get();

    // Lọc phòng không phải của mình
    final available = waiting.docs
        .where((d) => (d.data()['player1'] as Map)['uid'] != _uid)
        .toList();

    if (available.isNotEmpty) {
      // Join phòng có sẵn
      final room = available.first;
      await room.reference.update({
        'player2': {
          'uid': _uid,
          'name': myName,
          'photo': myPhoto,
          'score': 0,
          'ready': true,
          'answers': [],
        },
        'status': 'countdown',
      });
      return room.id;
    }

    // Tạo phòng mới
    final questions = await _generateQuestions();
    final roomRef = _db.collection('battle_rooms').doc();
    await roomRef.set({
      'player1': {
        'uid': _uid,
        'name': myName,
        'photo': myPhoto,
        'score': 0,
        'ready': true,
        'answers': [],
      },
      'player2': {
        'uid': '',
        'name': '',
        'photo': '',
        'score': 0,
        'ready': false,
        'answers': [],
      },
      'status': 'waiting',
      'questions': questions,
      'currentQuestionIndex': 0,
      'totalQuestions': totalQuestions,
      'winner': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return roomRef.id;
  }

  // ── Stream trạng thái phòng ───────────────────────────
  static Stream<BattleRoom> roomStream(String roomId) {
    return _db
        .collection('battle_rooms')
        .doc(roomId)
        .snapshots()
        .map((snap) => BattleRoom.fromMap(snap.data() ?? {}, id: snap.id));
  }

  // ── Trả lời câu hỏi ──────────────────────────────────
  static Future<void> submitAnswer({
    required String roomId,
    required int questionIndex,
    required int selectedIndex,
    required bool isCorrect,
    required int timeMs, // thời gian trả lời (ms)
  }) async {
    if (_uid.isEmpty) return;
    final room = await _db.collection('battle_rooms').doc(roomId).get();
    final data = room.data() ?? {};

    final isPlayer1 = (data['player1'] as Map)['uid'] == _uid;
    final playerKey = isPlayer1 ? 'player1' : 'player2';
    final player = Map<String, dynamic>.from(data[playerKey] as Map);

    // Tính điểm: đúng + nhanh = điểm cao hơn
    int points = 0;
    if (isCorrect) {
      final timeBonus = ((questionTimeSeconds * 1000 - timeMs) / 1000).clamp(0, questionTimeSeconds);
      points = (100 + timeBonus * 10).round();
    }

    final answers = List<Map<String, dynamic>>.from(player['answers'] ?? []);
    answers.add({
      'questionIndex': questionIndex,
      'selectedIndex': selectedIndex,
      'isCorrect': isCorrect,
      'timeMs': timeMs,
      'points': points,
    });

    await _db.collection('battle_rooms').doc(roomId).update({
      '$playerKey.score': FieldValue.increment(points),
      '$playerKey.answers': answers,
    });
  }

  // ── Kết thúc trận đấu ────────────────────────────────
  static Future<void> finishBattle(String roomId) async {
    final room = await _db.collection('battle_rooms').doc(roomId).get();
    final data = room.data() ?? {};
    final p1 = data['player1'] as Map;
    final p2 = data['player2'] as Map;
    final p1Score = (p1['score'] ?? 0).toInt();
    final p2Score = (p2['score'] ?? 0).toInt();

    String winner;
    if (p1Score > p2Score) {
      winner = p1['uid'] as String;
    } else if (p2Score > p1Score) {
      winner = p2['uid'] as String;
    } else {
      winner = 'draw';
    }

    await _db.collection('battle_rooms').doc(roomId).update({
      'status': 'finished',
      'winner': winner,
    });

    // Cập nhật stats
    await _updateBattleStats(
      roomId: roomId,
      winner: winner,
      p1Uid: p1['uid'] as String,
      p2Uid: p2['uid'] as String,
    );
  }

  static Future<void> _updateBattleStats({
    required String roomId,
    required String winner,
    required String p1Uid,
    required String p2Uid,
  }) async {
    for (final uid in [p1Uid, p2Uid]) {
      if (uid.isEmpty) continue;
      final isWinner = winner == uid;
      final isDraw = winner == 'draw';
      await _db.collection('users').doc(uid).update({
        'battlePlayed': FieldValue.increment(1),
        if (isWinner) 'battleWon': FieldValue.increment(1),
        if (isDraw) 'battleDraw': FieldValue.increment(1),
        if (isWinner) 'coins': FieldValue.increment(50),
        if (isDraw) 'coins': FieldValue.increment(20),
      });
    }
  }

  // ── Rời phòng ─────────────────────────────────────────
  static Future<void> leaveRoom(String roomId) async {
    if (_uid.isEmpty) return;
    final room = await _db.collection('battle_rooms').doc(roomId).get();
    final data = room.data() ?? {};
    final status = data['status'] as String? ?? '';

    if (status == 'waiting') {
      await _db.collection('battle_rooms').doc(roomId).delete();
    } else if (status != 'finished') {
      // Đánh dấu người kia thắng
      final isPlayer1 = (data['player1'] as Map)['uid'] == _uid;
      final winner = isPlayer1
          ? (data['player2'] as Map)['uid']
          : (data['player1'] as Map)['uid'];
      await _db.collection('battle_rooms').doc(roomId).update({
        'status': 'finished',
        'winner': winner ?? '',
      });
    }
  }

  // ── Tạo câu hỏi từ IELTS words ───────────────────────
  static Future<List<Map<String, dynamic>>> _generateQuestions() async {
    final snap = await _db
        .collection('ielts_questions')
        .limit(100)
        .get();

    if (snap.docs.isEmpty) {
      return _generateFallbackQuestions();
    }

    final allWords = snap.docs.map((d) => d.data()).toList()..shuffle(Random());
    final selected = allWords.take(totalQuestions).toList();

    return selected.map((word) {
      // Tạo 3 đáp án sai từ các từ khác
      final others = allWords
          .where((w) => w['word'] != word['word'])
          .take(50)
          .toList()
        ..shuffle(Random());
      final wrongOptions = others
          .take(3)
          .map((w) => w['meaning'] as String? ?? '')
          .toList();

      final correctIndex = Random().nextInt(4);
      final options = List<String>.from(wrongOptions);
      options.insert(correctIndex, word['meaning'] as String? ?? '');

      return {
        'word': word['word'] ?? '',
        'phonetic': word['phonetic'] ?? '',
        'options': options,
        'correctIndex': correctIndex,
      };
    }).toList();
  }

  static List<Map<String, dynamic>> _generateFallbackQuestions() {
    final words = [
      {'word': 'abandon', 'meaning': 'từ bỏ'},
      {'word': 'benefit', 'meaning': 'lợi ích'},
      {'word': 'concept', 'meaning': 'khái niệm'},
      {'word': 'derive', 'meaning': 'bắt nguồn từ'},
      {'word': 'establish', 'meaning': 'thành lập'},
      {'word': 'factor', 'meaning': 'yếu tố'},
      {'word': 'generate', 'meaning': 'tạo ra'},
      {'word': 'hypothesis', 'meaning': 'giả thuyết'},
      {'word': 'indicate', 'meaning': 'chỉ ra'},
      {'word': 'justify', 'meaning': 'biện minh'},
    ];
    return words.map((w) {
      final others = words.where((x) => x['word'] != w['word']).toList()
        ..shuffle(Random());
      final wrongOptions = others.take(3).map((x) => x['meaning']!).toList();
      final correctIndex = Random().nextInt(4);
      final options = List<String>.from(wrongOptions);
      options.insert(correctIndex, w['meaning']!);
      return {
        'word': w['word'],
        'phonetic': '',
        'options': options,
        'correctIndex': correctIndex,
      };
    }).toList();
  }

  // ── Lấy battle stats ──────────────────────────────────
  static Future<BattleStats> getBattleStats() async {
    if (_uid.isEmpty) return const BattleStats();
    final doc = await _db.collection('users').doc(_uid).get();
    final d = doc.data() ?? {};
    return BattleStats(
      played: (d['battlePlayed'] ?? 0).toInt(),
      won: (d['battleWon'] ?? 0).toInt(),
      draw: (d['battleDraw'] ?? 0).toInt(),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class BattleRoom {
  final String id;
  final BattlePlayer player1;
  final BattlePlayer player2;
  final String status; // waiting | countdown | playing | finished
  final List<BattleQuestion> questions;
  final int currentQuestionIndex;
  final int totalQuestions;
  final String winner;

  const BattleRoom({
    required this.id,
    required this.player1,
    required this.player2,
    required this.status,
    required this.questions,
    required this.currentQuestionIndex,
    required this.totalQuestions,
    required this.winner,
  });

  factory BattleRoom.fromMap(Map<String, dynamic> d, {required String id}) {
    final p1 = d['player1'] as Map<String, dynamic>? ?? {};
    final p2 = d['player2'] as Map<String, dynamic>? ?? {};
    final questionsList = (d['questions'] as List? ?? [])
        .map((q) => BattleQuestion.fromMap(Map<String, dynamic>.from(q)))
        .toList();
    return BattleRoom(
      id: id,
      player1: BattlePlayer.fromMap(p1),
      player2: BattlePlayer.fromMap(p2),
      status: d['status'] as String? ?? 'waiting',
      questions: questionsList,
      currentQuestionIndex: (d['currentQuestionIndex'] ?? 0).toInt(),
      totalQuestions: (d['totalQuestions'] ?? 10).toInt(),
      winner: d['winner'] as String? ?? '',
    );
  }

  BattlePlayer? myPlayer(String uid) {
    if (player1.uid == uid) return player1;
    if (player2.uid == uid) return player2;
    return null;
  }

  BattlePlayer? opponentPlayer(String uid) {
    if (player1.uid == uid) return player2;
    if (player2.uid == uid) return player1;
    return null;
  }

  bool get hasOpponent => player2.uid.isNotEmpty;
}

class BattlePlayer {
  final String uid;
  final String name;
  final String photo;
  final int score;
  final bool ready;
  final List<Map<String, dynamic>> answers;

  const BattlePlayer({
    required this.uid,
    required this.name,
    required this.photo,
    required this.score,
    required this.ready,
    required this.answers,
  });

  factory BattlePlayer.fromMap(Map<String, dynamic> d) => BattlePlayer(
        uid: d['uid'] as String? ?? '',
        name: d['name'] as String? ?? 'Player',
        photo: d['photo'] as String? ?? '',
        score: (d['score'] ?? 0).toInt(),
        ready: d['ready'] as bool? ?? false,
        answers: List<Map<String, dynamic>>.from(d['answers'] ?? []),
      );

  int get correctCount => answers.where((a) => a['isCorrect'] == true).length;
}

class BattleQuestion {
  final String word;
  final String phonetic;
  final List<String> options;
  final int correctIndex;

  const BattleQuestion({
    required this.word,
    required this.phonetic,
    required this.options,
    required this.correctIndex,
  });

  factory BattleQuestion.fromMap(Map<String, dynamic> d) => BattleQuestion(
        word: d['word'] as String? ?? '',
        phonetic: d['phonetic'] as String? ?? '',
        options: List<String>.from(d['options'] ?? []),
        correctIndex: (d['correctIndex'] ?? 0).toInt(),
      );
}

class BattleStats {
  final int played;
  final int won;
  final int draw;
  const BattleStats({this.played = 0, this.won = 0, this.draw = 0});
  int get lost => played - won - draw;
  double get winRate => played == 0 ? 0 : won / played;
}
