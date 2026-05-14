import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/battle_service.dart';

/// 🏆 Battle Screen — 1v1 Realtime Vocabulary Battle
class BattleScreen extends StatefulWidget {
  final String roomId;
  const BattleScreen({super.key, required this.roomId});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen>
    with SingleTickerProviderStateMixin {
  final String _myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
  StreamSubscription<BattleRoom>? _roomSub;
  BattleRoom? _room;
  int _questionTimer = BattleService.questionTimeSeconds;
  Timer? _timer;
  int? _selectedIndex;
  bool _answered = false;
  int _localQuestionIndex = 0;
  DateTime? _questionStartTime;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _listenRoom();
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _timer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _listenRoom() {
    _roomSub = BattleService.roomStream(widget.roomId).listen((room) {
      if (!mounted) return;
      final prevStatus = _room?.status;
      setState(() => _room = room);

      if (room.status == 'countdown' && prevStatus == 'waiting') {
        _startCountdown();
      }
      if (room.status == 'finished') {
        _timer?.cancel();
        _showResult(room);
      }
    });
  }

  void _startCountdown() {
    int count = 3;
    Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (count <= 0) {
        t.cancel();
        _startQuestion();
      } else {
        count--;
      }
    });
  }

  void _startQuestion() {
    _timer?.cancel();
    setState(() {
      _selectedIndex = null;
      _answered = false;
      _questionTimer = BattleService.questionTimeSeconds;
      _questionStartTime = DateTime.now();
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _questionTimer--);
      if (_questionTimer <= 0) {
        t.cancel();
        if (!_answered) _autoAnswer();
      }
    });
  }

  Future<void> _autoAnswer() async {
    setState(() {
      _answered = true;
      _selectedIndex = -1;
    });
    await _submitAndNext(selectedIndex: -1, isCorrect: false);
  }

  Future<void> _onAnswer(int index) async {
    if (_answered || _room == null) return;
    final question = _room!.questions[_localQuestionIndex];
    final isCorrect = index == question.correctIndex;
    final timeMs = _questionStartTime != null
        ? DateTime.now().difference(_questionStartTime!).inMilliseconds
        : BattleService.questionTimeSeconds * 1000;

    _timer?.cancel();
    setState(() {
      _selectedIndex = index;
      _answered = true;
    });

    await BattleService.submitAnswer(
      roomId: widget.roomId,
      questionIndex: _localQuestionIndex,
      selectedIndex: index,
      isCorrect: isCorrect,
      timeMs: timeMs,
    );

    await Future.delayed(const Duration(milliseconds: 1200));
    await _submitAndNext(selectedIndex: index, isCorrect: isCorrect);
  }

  Future<void> _submitAndNext(
      {required int selectedIndex, required bool isCorrect}) async {
    if (_room == null) return;
    final nextIndex = _localQuestionIndex + 1;

    if (nextIndex >= _room!.totalQuestions) {
      await BattleService.finishBattle(widget.roomId);
    } else {
      setState(() => _localQuestionIndex = nextIndex);
      _startQuestion();
    }
  }

  void _showResult(BattleRoom room) {
    final myPlayer = room.myPlayer(_myUid);
    final opponent = room.opponentPlayer(_myUid);
    final isWinner = room.winner == _myUid;
    final isDraw = room.winner == 'draw';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _BattleResultDialog(
        isWinner: isWinner,
        isDraw: isDraw,
        myScore: myPlayer?.score ?? 0,
        opponentScore: opponent?.score ?? 0,
        myName: myPlayer?.name ?? 'Bạn',
        opponentName: opponent?.name ?? 'Đối thủ',
        myCorrect: myPlayer?.correctCount ?? 0,
        opponentCorrect: opponent?.correctCount ?? 0,
        totalQuestions: room.totalQuestions,
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_room == null) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFFFBE0B)),
              SizedBox(height: 16),
              Text('Đang kết nối...',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      );
    }

    final room = _room!;

    if (room.status == 'waiting') return _buildWaiting(room);
    if (room.status == 'finished') return _buildWaiting(room);

    return _buildBattle(room);
  }

  Widget _buildWaiting(BattleRoom room) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () async {
            await BattleService.leaveRoom(widget.roomId);
            if (mounted) Navigator.pop(context);
          },
        ),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏆', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            const Text('Đang tìm đối thủ...',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Phòng: ${widget.roomId.substring(0, 8)}...',
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 32),
            AnimatedBuilder(
              animation: _pulseCtrl,
              builder: (_, __) => Container(
                width: 60 + _pulseCtrl.value * 10,
                height: 60 + _pulseCtrl.value * 10,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFBE0B)
                      .withOpacity(0.3 + _pulseCtrl.value * 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFFFFBE0B), strokeWidth: 3),
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextButton(
              onPressed: () async {
                await BattleService.leaveRoom(widget.roomId);
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Hủy',
                  style: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBattle(BattleRoom room) {
    if (_localQuestionIndex >= room.questions.length) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A2E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFFBE0B)),
        ),
      );
    }

    final question = room.questions[_localQuestionIndex];
    final myPlayer = room.myPlayer(_myUid);
    final opponent = room.opponentPlayer(_myUid);
    final timerPct = _questionTimer / BattleService.questionTimeSeconds;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            // Header: scores
            _BattleHeader(
              myPlayer: myPlayer,
              opponent: opponent,
              questionIndex: _localQuestionIndex,
              totalQuestions: room.totalQuestions,
            ),

            // Timer bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Câu ${_localQuestionIndex + 1}/${room.totalQuestions}',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      Text('$_questionTimer giây',
                          style: TextStyle(
                              color: _questionTimer <= 3
                                  ? Colors.red
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: timerPct,
                      backgroundColor: Colors.white12,
                      valueColor: AlwaysStoppedAnimation(
                        timerPct > 0.5
                            ? const Color(0xFF06D6A0)
                            : timerPct > 0.25
                                ? const Color(0xFFFFBE0B)
                                : Colors.red,
                      ),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            ),

            // Question word
            Expanded(
              flex: 2,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(question.word,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                    if (question.phonetic.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(question.phonetic,
                          style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 16,
                              fontStyle: FontStyle.italic)),
                    ],
                    const SizedBox(height: 8),
                    const Text('Chọn nghĩa đúng',
                        style: TextStyle(
                            color: Colors.white38, fontSize: 13)),
                  ],
                ),
              ),
            ),

            // Options
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 2.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: List.generate(question.options.length, (i) {
                    Color btnColor;
                    if (!_answered) {
                      btnColor = const Color(0xFF2D2D44);
                    } else if (i == question.correctIndex) {
                      btnColor = const Color(0xFF06D6A0);
                    } else if (i == _selectedIndex) {
                      btnColor = const Color(0xFFFF4757);
                    } else {
                      btnColor = const Color(0xFF2D2D44);
                    }

                    return GestureDetector(
                      onTap: _answered ? null : () => _onAnswer(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: btnColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: !_answered
                                ? Colors.white12
                                : i == question.correctIndex
                                    ? const Color(0xFF06D6A0)
                                    : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Text(
                              question.options[i],
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ─── Battle Header ────────────────────────────────────────────────────────────

class _BattleHeader extends StatelessWidget {
  final BattlePlayer? myPlayer;
  final BattlePlayer? opponent;
  final int questionIndex;
  final int totalQuestions;
  const _BattleHeader({
    required this.myPlayer,
    required this.opponent,
    required this.questionIndex,
    required this.totalQuestions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          // My score
          Expanded(
            child: _PlayerScore(
              name: myPlayer?.name ?? 'Bạn',
              score: myPlayer?.score ?? 0,
              correct: myPlayer?.correctCount ?? 0,
              isMe: true,
            ),
          ),
          // VS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFBE0B).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('VS',
                style: TextStyle(
                    color: Color(0xFFFFBE0B),
                    fontWeight: FontWeight.w900,
                    fontSize: 16)),
          ),
          // Opponent score
          Expanded(
            child: _PlayerScore(
              name: opponent?.uid.isEmpty == true
                  ? 'Chờ...'
                  : (opponent?.name ?? 'Đối thủ'),
              score: opponent?.score ?? 0,
              correct: opponent?.correctCount ?? 0,
              isMe: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerScore extends StatelessWidget {
  final String name;
  final int score;
  final int correct;
  final bool isMe;
  const _PlayerScore({
    required this.name,
    required this.score,
    required this.correct,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(name,
            style: const TextStyle(
                color: Colors.white70, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text('$score',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w900)),
        Text('✅ $correct đúng',
            style: const TextStyle(
                color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

// ─── Result Dialog ────────────────────────────────────────────────────────────

class _BattleResultDialog extends StatelessWidget {
  final bool isWinner;
  final bool isDraw;
  final int myScore;
  final int opponentScore;
  final String myName;
  final String opponentName;
  final int myCorrect;
  final int opponentCorrect;
  final int totalQuestions;
  final VoidCallback onDone;

  const _BattleResultDialog({
    required this.isWinner,
    required this.isDraw,
    required this.myScore,
    required this.opponentScore,
    required this.myName,
    required this.opponentName,
    required this.myCorrect,
    required this.opponentCorrect,
    required this.totalQuestions,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final emoji = isDraw ? '🤝' : isWinner ? '🏆' : '😢';
    final title = isDraw ? 'Hòa!' : isWinner ? 'Chiến thắng!' : 'Thua rồi!';
    final reward = isDraw ? '+20 🪙' : isWinner ? '+50 🪙' : '+0 🪙';

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold)),
          Text(reward,
              style: const TextStyle(
                  color: Color(0xFFFFBE0B), fontSize: 16)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ScoreRow(myName, myScore, myCorrect, totalQuestions, true),
          const SizedBox(height: 8),
          _ScoreRow(
              opponentName, opponentScore, opponentCorrect, totalQuestions, false),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        ElevatedButton(
          onPressed: onDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFBE0B),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          ),
          child: const Text('Xong',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _ScoreRow extends StatelessWidget {
  final String name;
  final int score;
  final int correct;
  final int total;
  final bool isMe;
  const _ScoreRow(this.name, this.score, this.correct, this.total, this.isMe);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMe
            ? const Color(0xFF667eea).withOpacity(0.15)
            : Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(isMe ? '👤 ' : '🤖 ',
              style: const TextStyle(fontSize: 16)),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500)),
          ),
          Text('$correct/$total đúng',
              style: const TextStyle(
                  color: Colors.white54, fontSize: 12)),
          const SizedBox(width: 8),
          Text('$score',
              style: const TextStyle(
                  color: Color(0xFFFFBE0B),
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }
}
