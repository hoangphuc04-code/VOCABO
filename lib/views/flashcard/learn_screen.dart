import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'flashcard_screen.dart';
import '../../data/services/currency_service.dart';
import '../../data/services/streak_service.dart';
import '../../data/services/meow_ai_service.dart';
import '../shop/heart_shop_screen.dart';
import '../pronunciation/waveform_pronunciation_screen.dart';
import '../../core/config/app_secrets.dart';

////////////////////////////////////////////////////////////
/// CONFIG — ảnh minh hoạ dùng Pixabay (miễn phí, không cần key)
/// Đăng ký tại https://pixabay.com/api/docs/ để lấy key riêng
/// Key được load từ .env — KHÔNG hardcode trong source code
////////////////////////////////////////////////////////////

// Key lấy từ AppSecrets, không hardcode
String get _kPixabayApiKey => AppSecrets.pixabayApiKey;

////////////////////////////////////////////////////////////
/// MODEL
////////////////////////////////////////////////////////////

class VocabWord {
  final String id;
  final String word;
  final String meaning;
  final String phonetic;
  final String example;
  final String exampleVi;
  String imageUrl; // mutable — điền sau khi fetch Unsplash

  VocabWord({
    required this.id,
    required this.word,
    required this.meaning,
    required this.phonetic,
    required this.example,
    required this.exampleVi,
    this.imageUrl = "",
  });

  factory VocabWord.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return VocabWord(
      id:        doc.id,
      word:      d["word"]      as String? ?? "",
      meaning:   d["meaning"]   as String? ?? "",
      phonetic:  d["phonetic"]  as String? ?? "",
      example:   d["example"]   as String? ?? "",
      exampleVi: d["exampleVi"] as String? ?? "",
      imageUrl:  d["imageUrl"]  as String? ?? "",
    );
  }
}

////////////////////////////////////////////////////////////
/// LEARN FLASHCARD SCREEN
////////////////////////////////////////////////////////////

class LearnFlashcardScreen extends StatefulWidget {
  final VocabTopic topic;
  const LearnFlashcardScreen({super.key, required this.topic});

  @override
  State<LearnFlashcardScreen> createState() =>
      _LearnFlashcardScreenState();
}

class _LearnFlashcardScreenState extends State<LearnFlashcardScreen>
    with SingleTickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────
  List<VocabWord> _words = [];
  int _currentIndex = 0;
  bool _loading = true;
  bool _flipped = false;
  bool _speaking = false;

  // ── Hearts ─────────────────────────────────────────────
  int _hearts = CurrencyService.maxHearts;

  // ── TTS ────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();

  // ── Accent: 'en-US' = Anh-Mỹ, 'en-GB' = Anh-Anh ──────
  static const _kAccentKey = 'tts_accent';
  String _accentLocale = 'en-US'; // default Anh-Mỹ

  // ── STT + Pronunciation ────────────────────────────────
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  bool _isAssessing = false;
  PronunciationResult? _pronResult; // kết quả đánh giá hiện tại

  // ── Animation ──────────────────────────────────────────
  late final AnimationController _flipCtrl;
  late final Animation<double> _flipAnim;

  @override
  void initState() {
    super.initState();

    _flipCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipCtrl, curve: Curves.easeInOut),
    );

    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.45);
    _tts.setPitch(1.0);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });

    _loadAccent();
    _loadWords();
    _loadHearts();
    _initStt();
  }

  Future<void> _loadHearts() async {
    final currency = await CurrencyService.getCurrency();
    if (mounted) {
      setState(() {
        _hearts = currency['hearts'] as int;
      });
    }
  }

  // ── Load / save accent preference ─────────────────────
  Future<void> _loadAccent() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kAccentKey) ?? 'en-US';
    if (mounted) {
      setState(() => _accentLocale = saved);
      await _tts.setLanguage(saved);
    }
  }

  Future<void> _toggleAccent() async {
    final next = _accentLocale == 'en-US' ? 'en-GB' : 'en-US';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccentKey, next);
    await _tts.setLanguage(next);
    if (mounted) setState(() => _accentLocale = next);

    // Feedback nhỏ
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(next == 'en-GB' ? '🇬🇧' : '🇺🇸',
                  style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                next == 'en-GB'
                    ? 'Đã chuyển sang giọng Anh-Anh'
                    : 'Đã chuyển sang giọng Anh-Mỹ',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          backgroundColor: const Color(0xFF667eea),
        ),
      );
    }
  }

  @override
  void dispose() {
    _flipCtrl.dispose();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  // ── STT init ───────────────────────────────────────────
  Future<void> _initStt() async {
    final available = await _stt.initialize(
      onStatus: (status) {
        // Reset khi STT tự dừng (timeout, done)
        if (status == 'notListening' || status == 'done') {
          if (mounted && _isListening) {
            setState(() => _isListening = false);
          }
        }
      },
      onError: (e) {
        if (mounted) setState(() => _isListening = false);
      },
      debugLogging: false,
    );
    if (mounted) setState(() => _sttAvailable = available);
  }

  // ── Bắt đầu nghe giọng người dùng ─────────────────────
  Future<void> _startListening() async {
    if (!_sttAvailable || _isListening || _isAssessing) return;
    final word = _words[_currentIndex];

    // Reset kết quả cũ
    setState(() {
      _pronResult = null;
      _isListening = true;
    });

    final started = await _stt.listen(
      localeId: _accentLocale == 'en-GB' ? 'en_GB' : 'en_US',
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      cancelOnError: true,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (result) async {
        if (!result.finalResult) return;
        final spoken = result.recognizedWords.trim();
        if (spoken.isEmpty) {
          if (mounted) setState(() => _isListening = false);
          return;
        }
        if (mounted) {
          setState(() {
            _isListening = false;
            _isAssessing = true;
          });
        }
        final assessment = await MeowAIService.assessPronunciation(
          spokenText: spoken,
          targetWord: word.word,
          phonetic: word.phonetic,
        );
        if (mounted) {
          setState(() {
            _pronResult = assessment;
            _isAssessing = false;
          });
        }
      },
    );

    // Nếu listen() không khởi động được → reset flag
    if (!started && mounted) {
      setState(() => _isListening = false);
    }
  }

  // ── Dừng nghe ──────────────────────────────────────────
  Future<void> _stopListening() async {
    await _stt.stop();
    if (mounted) setState(() => _isListening = false);
  }

  // ── Load từ vựng từ Firestore ──────────────────────────
  Future<void> _loadWords() async {
    final snap = await FirebaseFirestore.instance
        .collection("topics")
        .doc(widget.topic.id)
        .collection("words")
        .get();

    final words = snap.docs.map((d) => VocabWord.fromDoc(d)).toList();

    // Fetch Unsplash ảnh cho từng từ (chạy song song)
    await Future.wait(
      words.map((w) => _fetchImage(w)),
    );

    if (mounted) {
      setState(() {
        _words = words;
        _loading = false;
      });
    }
  }

  // ── Fetch ảnh minh hoạ ────────────────────────────────
  // Ưu tiên: Pixabay (nếu có key) → source.unsplash.com (không cần key)
  Future<void> _fetchImage(VocabWord word) async {
    if (word.imageUrl.isNotEmpty) return; // đã có URL thì bỏ qua

    try {
      if (_kPixabayApiKey.isNotEmpty) {
        // Pixabay API — miễn phí, đăng ký tại pixabay.com/api/docs/
        final uri = Uri.parse(
          "https://pixabay.com/api/"
              "?key=$_kPixabayApiKey"
              "&q=${Uri.encodeComponent(word.word)}"
              "&image_type=photo"
              "&orientation=horizontal"
              "&per_page=3"
              "&safesearch=true",
        );
        final res = await http.get(uri).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body) as Map<String, dynamic>;
          final hits = json["hits"] as List? ?? [];
          if (hits.isNotEmpty) {
            word.imageUrl =
                hits[0]["webformatURL"] as String? ?? "";
            return;
          }
        }
      }

      // Fallback: source.unsplash.com — không cần key, redirect đến ảnh ngẫu nhiên
      // Dùng width=400&height=280 để ảnh nhỏ gọn, tải nhanh
      word.imageUrl =
          "https://source.unsplash.com/400x280/?${Uri.encodeComponent(word.word)},${Uri.encodeComponent(word.word + ' object')}";
    } catch (_) {
      // Không có ảnh thì dùng placeholder
    }
  }

  // ── TTS phát âm ────────────────────────────────────────
  Future<void> _speak(String text) async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts.speak(text);
  }

  // ── Lật card ───────────────────────────────────────────
  void _flipCard() {
    if (_flipped) {
      _flipCtrl.reverse();
    } else {
      _flipCtrl.forward();
    }
    setState(() => _flipped = !_flipped);
  }

  // ── Chuyển sang từ tiếp theo ───────────────────────────
  void _nextWord() {
    if (_currentIndex >= _words.length - 1) return;
    _flipCtrl.reset();
    setState(() {
      _flipped = false;
      _currentIndex++;
      _speaking = false;
      _pronResult = null;
      _isListening = false;
      _isAssessing = false;
    });
    _tts.stop();
    _stt.stop();
  }

  // ── Quay lại từ trước ──────────────────────────────────
  void _prevWord() {
    if (_currentIndex <= 0) return;
    _flipCtrl.reset();
    setState(() {
      _flipped = false;
      _currentIndex--;
      _speaking = false;
      _pronResult = null;
      _isListening = false;
      _isAssessing = false;
    });
    _tts.stop();
    _stt.stop();
  }

  // ── Lưu tiến độ học vào Firestore ─────────────────────
  Future<void> _markLearned() async {
    // Kiểm tra hearts trước
    if (_hearts <= 0) {
      _showNoHeartsDialog();
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final word = _words[_currentIndex];
    final colorHex = "#${widget.topic.color.value.toRadixString(16).substring(2)}";

    // 1. Lưu vào learned_words
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .collection("learned_words")
        .doc("${widget.topic.id}_${word.id}")
        .set({
      "uid":        user.uid,
      "wordId":     word.id,
      "word":       word.word,
      "meaning":    word.meaning,
      "phonetic":   word.phonetic,
      "example":    word.example,
      "exampleVi":  word.exampleVi,
      "topicId":    widget.topic.id,
      "topicName":  widget.topic.name,
      "topicNameVi":widget.topic.nameVi,
      "topicEmoji": widget.topic.emoji,
      "topicColor": colorHex,
      "learnedAt":  FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 2. Cập nhật vocabulary_progress
    await FirebaseFirestore.instance
        .collection("vocabulary_progress")
        .doc("${user.uid}_${word.id}")
        .set({
      "uid":       user.uid,
      "wordId":    word.id,
      "topicId":   widget.topic.id,
      "strength":  1.0,
      "learnedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 3. Cập nhật study_sessions
    final today = DateTime.now();
    final dateKey =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";

    final sessionRef = FirebaseFirestore.instance
        .collection("study_sessions")
        .doc("${user.uid}_$dateKey");

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(sessionRef);
      if (snap.exists) {
        tx.update(sessionRef, {"wordsLearned": FieldValue.increment(1)});
      } else {
        tx.set(sessionRef, {
          "uid":          user.uid,
          "date":         Timestamp.fromDate(today),
          "wordsLearned": 1,
        });
      }
    });

    // 4. Cập nhật wordsLearned
    await FirebaseFirestore.instance
        .collection("users")
        .doc(user.uid)
        .update({"wordsLearned": FieldValue.increment(1)});

    // 5. Ghi nhận streak (Duolingo-style: học bài mới tăng streak)
    final streakResult = await StreakService.recordLessonCompleted();
    if (mounted && streakResult.increased) {
      // Hiện thông báo streak tăng
      if (streakResult.streak > 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Text('🔥 Streak: '),
                Text(
                  '${streakResult.streak} ngày!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (streakResult.isNewRecord)
                  const Text(' 🏆 Kỷ lục mới!'),
              ],
            ),
            backgroundColor: const Color(0xFFFF6B35),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Đã ghi nhớ "${word.word}"'),
          duration: const Duration(seconds: 1),
          backgroundColor: const Color(0xFF06D6A0),
        ),
      );
    }

    _nextWord();
  }

  // ── Tiêu hao heart khi bỏ qua / không nhớ ─────────────
  Future<void> _skipWord() async {
    if (_hearts <= 0) {
      _showNoHeartsDialog();
      return;
    }

    final remaining = await CurrencyService.loseHeart();
    if (mounted) {
      setState(() {
        _hearts = remaining < 0 ? 0 : remaining;
      });

      if (remaining == 0) {
        _showNoHeartsDialog();
        return;
      }

      // Hiện snack cảnh báo
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Text('💔 -1 Tim  '),
              ...List.generate(CurrencyService.maxHearts, (i) =>
                Text(i < remaining ? '❤️' : '🖤',
                    style: const TextStyle(fontSize: 14))),
            ],
          ),
          backgroundColor: const Color(0xFFFF4757),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }

    _nextWord();
  }

  // ── Dialog hết hearts ─────────────────────────────────
  void _showNoHeartsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _NoHeartsDialog(
        onBuyHearts: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HeartShopScreen()),
          ).then((_) => _loadHearts());
        },
        onQuit: () {
          Navigator.pop(context); // close dialog
          Navigator.pop(context); // close learn screen
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "${widget.topic.emoji} ${widget.topic.name}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          // Accent toggle button
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _AccentToggleBtn(
                locale: _accentLocale,
                onToggle: _toggleAccent,
              ),
            ),
          // Hearts display
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(CurrencyService.maxHearts, (i) =>
                  Text(
                    i < _hearts ? '❤️' : '🖤',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  "${_currentIndex + 1}/${_words.length}",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : _words.isEmpty
          ? _buildEmptyWords()
          : _buildContent(),
    );
  }

  // ── Màn hình trống (chưa có từ) ───────────────────────
  Widget _buildEmptyWords() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("📭", style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          const Text(
            "Chủ đề này chưa có từ vựng",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddWordSheet(),
            icon: const Icon(Icons.add),
            label: const Text("Thêm từ vựng"),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Nội dung chính ─────────────────────────────────────
  Widget _buildContent() {
    final word = _words[_currentIndex];

    return Column(
      children: [
        // Progress bar
        _ProgressBar(
          current: _currentIndex + 1,
          total: _words.length,
          color: widget.topic.color,
        ),

        Expanded(
          child: SingleChildScrollView(
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                // ── Flashcard (lật được) ───────────────
                GestureDetector(
                  onTap: _flipCard,
                  child: AnimatedBuilder(
                    animation: _flipAnim,
                    builder: (_, __) {
                      final angle = _flipAnim.value * 3.14159;
                      final showFront = _flipAnim.value < 0.5;

                      return Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        child: showFront
                            ? _CardFront(
                          word: word,
                          color: widget.topic.color,
                          speaking: _speaking,
                          onSpeak: () => _speak(word.word),
                        )
                            : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..rotateY(3.14159),
                          child: _CardBack(word: word),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Gợi ý lật
                if (!_flipped)
                  Text(
                    "Nhấn vào card để xem nghĩa",
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),

                const SizedBox(height: 20),

                // ── Ví dụ câu ─────────────────────────
                _ExampleCard(word: word, color: widget.topic.color),

                const SizedBox(height: 16),

                // ── Pronunciation panel ────────────────
                _PronunciationPanel(
                  word: word,
                  isListening: _isListening,
                  isAssessing: _isAssessing,
                  result: _pronResult,
                  sttAvailable: _sttAvailable,
                  onStart: _startListening,
                  onStop: _stopListening,
                  accentLocale: _accentLocale,
                ),

                const SizedBox(height: 12),

                // ── Nút luyện phát âm nâng cao ─────────
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WaveformPronunciationScreen(
                        word: word.word,
                        phonetic: word.phonetic,
                        meaning: word.meaning,
                      ),
                    ),
                  ),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF667eea).withOpacity(0.3)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('🎤', style: TextStyle(fontSize: 18)),
                        SizedBox(width: 8),
                        Text(
                          'Luyện phát âm nâng cao',
                          style: TextStyle(
                            color: Color(0xFF667eea),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 12, color: Color(0xFF667eea)),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // ── Bottom controls ─────────────────────────────
        _BottomControls(
          onPrev:         _currentIndex > 0 ? _prevWord : null,
          onNext:         _currentIndex < _words.length - 1 ? _nextWord : null,
          onLearned:      _markLearned,
          onSkip:         _skipWord,
          onAddWord:      _showAddWordSheet,
          isLastCard:     _currentIndex == _words.length - 1,
          topicColor:     widget.topic.color,
          hearts:         _hearts,
        ),
      ],
    );
  }

  // ── Sheet thêm từ vựng ─────────────────────────────────
  void _showAddWordSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddWordSheet(
        topicId: widget.topic.id,
        topicColor: widget.topic.color,
        onAdded: _loadWords,
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// CARD FRONT — tiếng Anh + phiên âm + ảnh + loa
////////////////////////////////////////////////////////////

class _CardFront extends StatelessWidget {
  final VocabWord word;
  final Color color;
  final bool speaking;
  final VoidCallback onSpeak;
  const _CardFront({
    required this.word,
    required this.color,
    required this.speaking,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Ảnh từ vựng
          ClipRRect(
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
            child: word.imageUrl.isNotEmpty
                ? Image.network(
              word.imageUrl,
              height: 180,
              width: double.infinity,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return Container(
                  height: 180,
                  width: double.infinity,
                  color: color.withOpacity(0.08),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: progress.expectedTotalBytes != null
                          ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                          : null,
                      color: color,
                      strokeWidth: 2.5,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => _imagePlaceholder(color),
            )
                : _imagePlaceholder(color),
          ),

          // Từ + phiên âm + loa
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        word.word,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF222222),
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Nút loa
                    GestureDetector(
                      onTap: onSpeak,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: speaking
                              ? color
                              : color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          speaking
                              ? Icons.volume_up_rounded
                              : Icons.volume_up_outlined,
                          color: speaking ? Colors.white : color,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
                if (word.phonetic.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    word.phonetic,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(Color color) {
    return Container(
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.12),
            color.withOpacity(0.06),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_search_rounded,
              size: 48, color: color.withOpacity(0.35)),
          const SizedBox(height: 8),
          Text(
            word.word,
            style: TextStyle(
              fontSize: 13,
              color: color.withOpacity(0.5),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// CARD BACK — nghĩa tiếng Việt
////////////////////////////////////////////////////////////

class _CardBack extends StatelessWidget {
  final VocabWord word;
  const _CardBack({required this.word});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 280),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            "Nghĩa tiếng Việt",
            style: TextStyle(
              color: Colors.white60,
              fontSize: 14,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              word.meaning,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// EXAMPLE CARD
////////////////////////////////////////////////////////////

class _ExampleCard extends StatefulWidget {
  final VocabWord word;
  final Color color;
  const _ExampleCard({required this.word, required this.color});

  @override
  State<_ExampleCard> createState() => _ExampleCardState();
}

class _ExampleCardState extends State<_ExampleCard> {
  bool _generating = false;
  String? _generatedEn;
  String? _generatedVi;

  // Dùng example từ Firestore nếu có, ngược lại dùng generated
  String get _displayEn =>
      widget.word.example.isNotEmpty ? widget.word.example : (_generatedEn ?? '');
  String get _displayVi =>
      widget.word.exampleVi.isNotEmpty ? widget.word.exampleVi : (_generatedVi ?? '');

  bool get _hasExample => _displayEn.isNotEmpty;

  Future<void> _generate() async {
    if (_generating) return;
    setState(() => _generating = true);

    final result = await MeowAIService.generateExample(
      word: widget.word.word,
      meaning: widget.word.meaning,
      phonetic: widget.word.phonetic,
    );

    if (mounted) {
      setState(() {
        _generating = false;
        if (result != null) {
          _generatedEn = result.en;
          _generatedVi = result.vi;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Không có example và chưa generate → hiện nút tạo
    if (!_hasExample && !_generating) {
      return _buildGeneratePrompt();
    }

    // Đang generate → hiện skeleton loading
    if (_generating) {
      return _buildLoading();
    }

    // Có example → hiện card bình thường
    return _buildCard();
  }

  Widget _buildGeneratePrompt() {
    return GestureDetector(
      onTap: _generate,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: widget.color.withOpacity(0.25),
            style: BorderStyle.solid,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('✨', style: const TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tạo câu ví dụ bằng AI',
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Nhấn để tạo ví dụ cho từ này',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: widget.color.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: widget.color,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            'Meow đang tạo câu ví dụ... 🐱',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final isGenerated = widget.word.example.isEmpty && _generatedEn != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: widget.color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "Ví dụ",
                  style: TextStyle(
                    color: widget.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isGenerated) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF667eea).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✨', style: TextStyle(fontSize: 10)),
                      SizedBox(width: 3),
                      Text(
                        'AI tạo',
                        style: TextStyle(
                          color: Color(0xFF667eea),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              // Nút tạo lại (chỉ hiện khi là AI-generated)
              if (isGenerated)
                GestureDetector(
                  onTap: _generate,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.refresh_rounded,
                        size: 16, color: Colors.grey.shade500),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Highlight từ vựng trong câu ví dụ
          _HighlightedText(
            text: _displayEn,
            keyword: widget.word.word,
            highlightColor: widget.color,
          ),

          if (_displayVi.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              _displayVi,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// HIGHLIGHTED TEXT — tô đậm từ khoá trong câu ví dụ
////////////////////////////////////////////////////////////

class _HighlightedText extends StatelessWidget {
  final String text;
  final String keyword;
  final Color highlightColor;
  const _HighlightedText({
    required this.text,
    required this.keyword,
    required this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final lower = text.toLowerCase();
    final kLower = keyword.toLowerCase();
    final idx = lower.indexOf(kLower);

    if (idx == -1) {
      return Text(text,
          style: const TextStyle(
              fontSize: 16, color: Color(0xFF333333), height: 1.5));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
            fontSize: 16, color: Color(0xFF333333), height: 1.5),
        children: [
          TextSpan(text: text.substring(0, idx)),
          TextSpan(
            text: text.substring(idx, idx + keyword.length),
            style: TextStyle(
              color: highlightColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(text: text.substring(idx + keyword.length)),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// PROGRESS BAR
////////////////////////////////////////////////////////////

class _ProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final Color color;
  const _ProgressBar({
    required this.current,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 4,
      color: Colors.grey.shade200,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: total == 0 ? 0 : current / total,
        child: Container(color: color),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// BOTTOM CONTROLS
////////////////////////////////////////////////////////////

class _BottomControls extends StatelessWidget {
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onLearned;
  final VoidCallback onSkip;
  final VoidCallback onAddWord;
  final bool isLastCard;
  final Color topicColor;
  final int hearts;
  const _BottomControls({
    required this.onPrev,
    required this.onNext,
    required this.onLearned,
    required this.onSkip,
    required this.onAddWord,
    required this.isLastCard,
    required this.topicColor,
    required this.hearts,
  });

  @override
  Widget build(BuildContext context) {
    final noHearts = hearts <= 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // Nút trước
              _CircleBtn(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: onPrev,
                enabled: onPrev != null,
                color: topicColor,
              ),
              const SizedBox(width: 8),

              // Nút không nhớ (tiêu hao heart)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: noHearts ? null : onSkip,
                  icon: const Text('💔', style: TextStyle(fontSize: 14)),
                  label: const Text('Không nhớ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFFF4757),
                    side: const BorderSide(color: Color(0xFFFF4757)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút đã nhớ
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: noHearts ? null : onLearned,
                  icon: Icon(
                    isLastCard
                        ? Icons.emoji_events_rounded
                        : Icons.check_rounded,
                    size: 20,
                  ),
                  label: Text(isLastCard ? "Hoàn thành!" : "Đã nhớ ✓"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: noHearts
                        ? Colors.grey.shade300
                        : topicColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Nút tiếp
              _CircleBtn(
                icon: Icons.arrow_forward_ios_rounded,
                onTap: onNext,
                enabled: onNext != null,
                color: topicColor,
              ),
              const SizedBox(width: 4),

              // Nút thêm từ
              _CircleBtn(
                icon: Icons.add,
                onTap: onAddWord,
                enabled: true,
                color: Colors.grey.shade700,
              ),
            ],
          ),
          // Cảnh báo hết hearts
          if (noHearts) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4757).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('💔', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'Hết tim! Mua thêm để tiếp tục học',
                    style: TextStyle(
                      color: Color(0xFFFF4757),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final Color color;
  const _CircleBtn({
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.1) : Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? color : Colors.grey.shade400,
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// ADD WORD BOTTOM SHEET
////////////////////////////////////////////////////////////

class _AddWordSheet extends StatefulWidget {
  final String topicId;
  final Color topicColor;
  final VoidCallback onAdded;
  const _AddWordSheet({
    required this.topicId,
    required this.topicColor,
    required this.onAdded,
  });

  @override
  State<_AddWordSheet> createState() => _AddWordSheetState();
}

class _AddWordSheetState extends State<_AddWordSheet> {
  final _word      = TextEditingController();
  final _meaning   = TextEditingController();
  final _phonetic  = TextEditingController();
  final _example   = TextEditingController();
  final _exampleVi = TextEditingController();
  bool _loading = false;

  Future<void> _save() async {
    if (_word.text.trim().isEmpty || _meaning.text.trim().isEmpty) return;
    setState(() => _loading = true);

    final ref = FirebaseFirestore.instance
        .collection("topics")
        .doc(widget.topicId);

    await ref.collection("words").add({
      "word":      _word.text.trim(),
      "meaning":   _meaning.text.trim(),
      "phonetic":  _phonetic.text.trim(),
      "example":   _example.text.trim(),
      "exampleVi": _exampleVi.text.trim(),
      "imageUrl":  "",
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Tăng wordCount
    await ref.update({"wordCount": FieldValue.increment(1)});

    if (mounted) {
      Navigator.pop(context);
      widget.onAdded();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Thêm từ vựng mới",
                style:
                TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              _field(_word,      "Từ tiếng Anh *",    "elephant"),
              const SizedBox(height: 10),
              _field(_meaning,   "Nghĩa tiếng Việt *", "con voi"),
              const SizedBox(height: 10),
              _field(_phonetic,  "Phiên âm",           "/ˈelɪfənt/"),
              const SizedBox(height: 10),
              _field(_example,   "Câu ví dụ (EN)",
                  "The elephant walked slowly."),
              const SizedBox(height: 10),
              _field(_exampleVi, "Câu ví dụ (VI)",     "Con voi đi chậm chạp."),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.topicColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text("Thêm từ",
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
      TextEditingController ctrl, String label, String hint) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: widget.topicColor, width: 1.5),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _word.dispose();
    _meaning.dispose();
    _phonetic.dispose();
    _example.dispose();
    _exampleVi.dispose();
    super.dispose();
  }
}

////////////////////////////////////////////////////////////
/// NO HEARTS DIALOG
////////////////////////////////////////////////////////////

class _NoHeartsDialog extends StatelessWidget {
  final VoidCallback onBuyHearts;
  final VoidCallback onQuit;
  const _NoHeartsDialog({
    required this.onBuyHearts,
    required this.onQuit,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFF4757).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('💔', style: TextStyle(fontSize: 40)),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Hết Tim rồi!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Bạn đã dùng hết tim.\nMua thêm bằng 💎 Diamond hoặc chờ hồi phục tự động.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '⏰ 1 tim hồi phục sau ${CurrencyService.heartRecoverMinutes} phút',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 24),
            // Buy button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: onBuyHearts,
                icon: const Text('💎', style: TextStyle(fontSize: 16)),
                label: const Text(
                  'Mua Tim bằng Diamond',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Quit button
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: onQuit,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Thoát và chờ hồi phục',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// ACCENT TOGGLE BUTTON — Anh-Mỹ 🇺🇸 / Anh-Anh 🇬🇧
////////////////////////////////////////////////////////////

class _AccentToggleBtn extends StatefulWidget {
  final String locale;
  final VoidCallback onToggle;

  const _AccentToggleBtn({
    required this.locale,
    required this.onToggle,
  });

  @override
  State<_AccentToggleBtn> createState() => _AccentToggleBtnState();
}

class _AccentToggleBtnState extends State<_AccentToggleBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scale = Tween(begin: 1.0, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _isUS => widget.locale == 'en-US';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onToggle();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flag
                Text(
                  _isUS ? '🇺🇸' : '🇬🇧',
                  style: const TextStyle(fontSize: 15),
                ),
                const SizedBox(width: 4),
                // Label
                Text(
                  _isUS ? 'US' : 'UK',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 3),
                // Swap icon
                const Icon(
                  Icons.swap_horiz_rounded,
                  color: Colors.white70,
                  size: 13,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// PRONUNCIATION PANEL — STT + đánh giá phát âm
////////////////////////////////////////////////////////////

class _PronunciationPanel extends StatelessWidget {
  final VocabWord word;
  final bool isListening;
  final bool isAssessing;
  final PronunciationResult? result;
  final bool sttAvailable;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final String accentLocale;

  const _PronunciationPanel({
    required this.word,
    required this.isListening,
    required this.isAssessing,
    required this.result,
    required this.sttAvailable,
    required this.onStart,
    required this.onStop,
    required this.accentLocale,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  "Luyện phát âm",
                  style: TextStyle(
                    color: Color(0xFF667eea),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // Mic button
              GestureDetector(
                onTap: isListening ? onStop : onStart,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isListening
                        ? const Color(0xFFFF4757)
                        : isAssessing
                            ? const Color(0xFFFFB347)
                            : const Color(0xFF667eea).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isListening
                        ? Icons.stop_rounded
                        : isAssessing
                            ? Icons.hourglass_top_rounded
                            : Icons.mic_rounded,
                    color: isListening || isAssessing
                        ? Colors.white
                        : const Color(0xFF667eea),
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          if (isListening) ...[
            const SizedBox(height: 10),
            const Text(
              "🎤 Đang nghe... Hãy phát âm từ trên",
              style: TextStyle(color: Color(0xFFFF4757), fontSize: 13),
            ),
          ],
          if (isAssessing) ...[
            const SizedBox(height: 10),
            const Text(
              "⏳ Meow đang đánh giá...",
              style: TextStyle(color: Color(0xFFFFB347), fontSize: 13),
            ),
          ],
          if (result != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: result!.scoreColor, width: 2.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${result!.score}",
                        style: TextStyle(
                          color: result!.scoreColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result!.comment,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      if (result!.tip.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          "💡 ${result!.tip}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (!isListening && !isAssessing && result == null) ...[
            const SizedBox(height: 8),
            Text(
              sttAvailable
                  ? "Nhấn 🎤 để luyện phát âm"
                  : "Thiết bị không hỗ trợ nhận diện giọng nói",
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
