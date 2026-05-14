import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

/// 🏆 Tính năng 5: Daily Challenge với Leaderboard
/// Mỗi ngày có 1 thử thách đặc biệt: speed round, fill-in-blank, unscramble
class DailyChallengeScreen extends StatefulWidget {
  const DailyChallengeScreen({super.key});

  @override
  State<DailyChallengeScreen> createState() => _DailyChallengeScreenState();
}

class _DailyChallengeScreenState extends State<DailyChallengeScreen>
    with TickerProviderStateMixin {
  ChallengeType _type = ChallengeType.speedRound;
  List<ChallengeQuestion> _questions = [];
  int _currentIndex = 0;
  int _score = 0;
  bool _loading = true;
  bool _finished = false;
  bool _answered = false;
  int? _selectedAnswer;
  String _fillAnswer = '';
  List<String> _scrambledLetters = [];
  List<String> _userArranged = [];
  late AnimationController _timerCtrl;
  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  final _fillCtrl = TextEditingController();
  int _timeLeft = 60;
  bool _timerRunning = false;

  @override
  void initState() {
    super.initState();
    _timerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _pickChallengeType();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timerCtrl.dispose();
    _shakeCtrl.dispose();
    _fillCtrl.dispose();
    super.dispose();
  }

  void _pickChallengeType() {
    final today = DateTime.now().day % 3;
    _type = ChallengeType.values[today];
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      // Lấy từ đã học
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learned_words')
          .limit(40)
          .get();
      final words = snap.docs.map((d) => d.data()).toList();
      if (words.length < 4) {
        setState(() => _loading = false);
        return;
      }
      words.shuffle();
      final questions = <ChallengeQuestion>[];
      for (int i = 0; i < 10 && i < words.length; i++) {
        final w = words[i];
        final distractors = words
            .where((x) => x['word'] != w['word'])
            .take(3)
            .map((x) => x['meaning'] as String? ?? '')
            .toList();
        final options = [w['meaning'] as String? ?? '', ...distractors]
          ..shuffle();
        questions.add(ChallengeQuestion(
          word: w['word'] as String? ?? '',
          meaning: w['meaning'] as String? ?? '',
          phonetic: w['phonetic'] as String? ?? '',
          options: options,
          correctIndex: options.indexOf(w['meaning'] as String? ?? ''),
        ));
      }
      if (mounted) {
        setState(() {
          _questions = questions;
          _loading = false;
        });
        if (_type == ChallengeType.speedRound) _startTimer();
        if (_questions.isNotEmpty && _type == ChallengeType.unscramble) {
          _buildScramble(_questions[0].word);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startTimer() {
    _timeLeft = 60;
    _timerRunning = true;
    _timerCtrl.forward(from: 0);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || !_timerRunning) return false;
      setState(() => _timeLeft--);
      if (_timeLeft <= 0) {
        _timerRunning = false;
        _finishChallenge();
        return false;
      }
      return true;
    });
  }

  void _buildScramble(String word) {
    final letters = word.toUpperCase().split('')..shuffle();
    setState(() {
      _scrambledLetters = letters;
      _userArranged = [];
    });
  }

  void _answerMCQ(int idx) {
    if (_answered) return;
    final correct = idx == _questions[_currentIndex].correctIndex;
    setState(() {
      _answered = true;
      _selectedAnswer = idx;
      if (correct) _score += _type == ChallengeType.speedRound ? 15 : 10;
    });
    if (!correct) _shakeCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 900), _nextQuestion);
  }

  void _submitFill() {
    if (_answered) return;
    final answer = _fillCtrl.text.trim().toLowerCase();
    final correct =
        answer == _questions[_currentIndex].word.toLowerCase();
    setState(() {
      _answered = true;
      _fillAnswer = answer;
      if (correct) _score += 12;
    });
    if (!correct) _shakeCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1200), _nextQuestion);
  }

  void _submitUnscramble() {
    if (_answered) return;
    final arranged = _userArranged.join('').toLowerCase();
    final correct =
        arranged == _questions[_currentIndex].word.toLowerCase();
    setState(() {
      _answered = true;
      if (correct) _score += 12;
    });
    if (!correct) _shakeCtrl.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 1200), _nextQuestion);
  }

  void _nextQuestion() {
    if (_currentIndex >= _questions.length - 1) {
      _finishChallenge();
      return;
    }
    setState(() {
      _currentIndex++;
      _answered = false;
      _selectedAnswer = null;
      _fillAnswer = '';
      _fillCtrl.clear();
    });
    if (_type == ChallengeType.unscramble) {
      _buildScramble(_questions[_currentIndex].word);
    }
  }

  Future<void> _finishChallenge() async {
    _timerRunning = false;
    setState(() => _finished = true);
    await _saveScore();
  }

  Future<void> _saveScore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final user = FirebaseAuth.instance.currentUser!;
      final today = DateTime.now();
      final dateKey =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
      await FirebaseFirestore.instance
          .collection('daily_challenge_scores')
          .doc('${uid}_$dateKey')
          .set({
        'uid': uid,
        'displayName': user.displayName ?? 'User',
        'photoURL': user.photoURL ?? '',
        'score': _score,
        'type': _type.name,
        'date': dateKey,
        'completedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        title: Text(
          _type == ChallengeType.speedRound
              ? '⚡ Speed Round'
              : _type == ChallengeType.fillBlank
                  ? '✏️ Fill in the Blank'
                  : '🔀 Unscramble',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_type == ChallengeType.speedRound && !_finished && !_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '⏱ $_timeLeft s',
                  style: TextStyle(
                    color: _timeLeft <= 10 ? Colors.red.shade200 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : _questions.isEmpty
              ? _buildEmpty()
              : _finished
                  ? _buildResult()
                  : _buildChallenge(),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📚', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text(
            'Học ít nhất 4 từ để tham gia thử thách!',
            style: TextStyle(fontSize: 15, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChallenge() {
    final q = _questions[_currentIndex];
    return Column(
      children: [
        // Progress
        LinearProgressIndicator(
          value: (_currentIndex + 1) / _questions.length,
          backgroundColor: Colors.grey.shade200,
          valueColor:
              const AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
          minHeight: 4,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_currentIndex + 1}/${_questions.length}',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🏆 $_score điểm',
                  style: const TextStyle(
                      color: Color(0xFF667eea),
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(
                    _shakeAnim.value * 8 * ((_shakeCtrl.value * 10).round() % 2 == 0 ? 1 : -1),
                    0),
                child: child,
              ),
              child: _type == ChallengeType.speedRound ||
                      _type == ChallengeType.fillBlank
                  ? _buildMCQOrFill(q)
                  : _buildUnscramble(q),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMCQOrFill(ChallengeQuestion q) {
    return Column(
      children: [
        // Question card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                _type == ChallengeType.speedRound
                    ? 'Nghĩa của từ này là gì?'
                    : 'Điền từ tiếng Anh có nghĩa:',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                _type == ChallengeType.speedRound ? q.word : q.meaning,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              if (q.phonetic.isNotEmpty && _type == ChallengeType.speedRound)
                Text(
                  q.phonetic,
                  style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_type == ChallengeType.speedRound)
          ...q.options.asMap().entries.map((e) {
            final idx = e.key;
            final opt = e.value;
            Color? bg;
            if (_answered) {
              if (idx == q.correctIndex) bg = const Color(0xFF06D6A0);
              if (idx == _selectedAnswer && idx != q.correctIndex)
                bg = const Color(0xFFFF4757);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => _answerMCQ(idx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: bg ?? Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: bg != null
                          ? bg
                          : Colors.grey.shade200,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: bg != null ? Colors.white : const Color(0xFF333333),
                    ),
                  ),
                ),
              ),
            );
          })
        else ...[
          TextField(
            controller: _fillCtrl,
            enabled: !_answered,
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(
              hintText: 'Nhập từ tiếng Anh...',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF667eea)),
                onPressed: _submitFill,
              ),
            ),
            onSubmitted: (_) => _submitFill(),
          ),
          if (_answered) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _fillAnswer == q.word.toLowerCase()
                    ? const Color(0xFF06D6A0).withOpacity(0.1)
                    : const Color(0xFFFF4757).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _fillAnswer == q.word.toLowerCase()
                    ? '✅ Chính xác!'
                    : '❌ Đáp án đúng: ${q.word}',
                style: TextStyle(
                  color: _fillAnswer == q.word.toLowerCase()
                      ? const Color(0xFF06D6A0)
                      : const Color(0xFFFF4757),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildUnscramble(ChallengeQuestion q) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Text('Sắp xếp các chữ cái thành từ có nghĩa:',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                q.meaning,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // User arranged
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
          ),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _userArranged.asMap().entries.map((e) {
              return GestureDetector(
                onTap: () {
                  if (_answered) return;
                  setState(() {
                    _scrambledLetters.add(_userArranged.removeAt(e.key));
                  });
                },
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      e.value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        // Scrambled letters
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _scrambledLetters.asMap().entries.map((e) {
            return GestureDetector(
              onTap: () {
                if (_answered) return;
                setState(() {
                  _userArranged.add(_scrambledLetters.removeAt(e.key));
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF667eea).withOpacity(0.4)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2)),
                  ],
                ),
                child: Center(
                  child: Text(
                    e.value,
                    style: const TextStyle(
                        color: Color(0xFF667eea),
                        fontWeight: FontWeight.bold,
                        fontSize: 16),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        if (!_answered)
          ElevatedButton(
            onPressed: _userArranged.isNotEmpty ? _submitUnscramble : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
            child: const Text('Kiểm tra',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        if (_answered) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _userArranged.join('').toLowerCase() ==
                      q.word.toLowerCase()
                  ? const Color(0xFF06D6A0).withOpacity(0.1)
                  : const Color(0xFFFF4757).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _userArranged.join('').toLowerCase() == q.word.toLowerCase()
                  ? '✅ Chính xác!'
                  : '❌ Đáp án đúng: ${q.word}',
              style: TextStyle(
                color: _userArranged.join('').toLowerCase() ==
                        q.word.toLowerCase()
                    ? const Color(0xFF06D6A0)
                    : const Color(0xFFFF4757),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResult() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(
            _score >= 80 ? '🏆' : _score >= 50 ? '🎉' : '💪',
            style: const TextStyle(fontSize: 72),
          ),
          const SizedBox(height: 16),
          Text(
            '$_score điểm',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: Color(0xFF667eea),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _score >= 80
                ? 'Xuất sắc! Bạn thật tuyệt vời!'
                : _score >= 50
                    ? 'Tốt lắm! Tiếp tục cố gắng!'
                    : 'Cần luyện thêm, đừng nản nhé!',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          // Leaderboard
          _LeaderboardWidget(),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Về trang chủ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding:
                  const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Leaderboard Widget ───────────────────────────────────────────────────────

class _LeaderboardWidget extends StatelessWidget {
  const _LeaderboardWidget();

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Row(
              children: [
                Text('🏆', style: TextStyle(fontSize: 20)),
                SizedBox(width: 8),
                Text(
                  'Bảng xếp hạng hôm nay',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15),
                ),
              ],
            ),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('daily_challenge_scores')
                .where('date', isEqualTo: dateKey)
                .orderBy('score', descending: true)
                .limit(10)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(
                      color: Color(0xFF667eea), strokeWidth: 2),
                );
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Chưa có ai tham gia hôm nay!',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 16, endIndent: 16),
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final medals = ['🥇', '🥈', '🥉'];
                  final rank = i < 3 ? medals[i] : '${i + 1}';
                  final isMe = d['uid'] ==
                      FirebaseAuth.instance.currentUser?.uid;
                  return ListTile(
                    leading: Text(rank,
                        style: const TextStyle(fontSize: 18)),
                    title: Text(
                      d['displayName'] as String? ?? 'User',
                      style: TextStyle(
                        fontWeight: isMe
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isMe
                            ? const Color(0xFF667eea)
                            : null,
                      ),
                    ),
                    trailing: Text(
                      '${d['score']} điểm',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isMe
                            ? const Color(0xFF667eea)
                            : Colors.grey,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

enum ChallengeType { speedRound, fillBlank, unscramble }

class ChallengeQuestion {
  final String word, meaning, phonetic;
  final List<String> options;
  final int correctIndex;

  const ChallengeQuestion({
    required this.word,
    required this.meaning,
    required this.phonetic,
    required this.options,
    required this.correctIndex,
  });
}

