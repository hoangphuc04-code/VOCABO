import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../data/services/meow_ai_service.dart';

/// 🎙️ Tính năng 7: Shadowing Mode
/// Phát audio câu ví dụ → người dùng đọc theo ngay lập tức
/// AI chấm điểm cả câu, không chỉ từng từ
class ShadowingScreen extends StatefulWidget {
  final List<ShadowingSentence> sentences;
  final String topicName;

  const ShadowingScreen({
    super.key,
    required this.sentences,
    required this.topicName,
  });

  @override
  State<ShadowingScreen> createState() => _ShadowingScreenState();
}

class _ShadowingScreenState extends State<ShadowingScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttAvailable = false;
  bool _speaking = false;
  bool _isListening = false;
  bool _isAssessing = false;
  ShadowingResult? _result;
  int _totalScore = 0;
  int _completedCount = 0;
  late AnimationController _pulseCtrl;
  late AnimationController _progressCtrl;
  late Animation<double> _progressAnim;
  ShadowingPhase _phase = ShadowingPhase.ready;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnim = CurvedAnimation(
        parent: _progressCtrl, curve: Curves.easeOut);
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.38);
    _tts.setCompletionHandler(() {
      if (mounted) {
        setState(() {
          _speaking = false;
          _phase = ShadowingPhase.listening;
        });
        _startListening();
      }
    });
    _initStt();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _progressCtrl.dispose();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted && _isListening) {
            _pulseCtrl.stop();
            setState(() => _isListening = false);
          }
        }
      },
      onError: (e) {
        _pulseCtrl.stop();
        if (mounted) setState(() => _isListening = false);
      },
      debugLogging: false,
    );
    if (mounted) setState(() => _sttAvailable = ok);
  }

  Future<void> _playSentence() async {
    if (_speaking) return;
    final sentence = widget.sentences[_currentIndex];
    setState(() {
      _speaking = true;
      _phase = ShadowingPhase.playing;
      _result = null;
    });
    _pulseCtrl.repeat(reverse: true);
    await _tts.speak(sentence.text);
  }

  Future<void> _startListening() async {
    if (!_sttAvailable || _isListening) return;
    setState(() {
      _isListening = true;
      _phase = ShadowingPhase.listening;
    });
    _pulseCtrl.repeat(reverse: true);

    final started = await _stt.listen(
      localeId: 'en_US',
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      cancelOnError: true,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult r) async {
        if (!r.finalResult) return;
        final spoken = r.recognizedWords.trim();
        _pulseCtrl.stop();
        if (spoken.isEmpty) {
          if (mounted) setState(() => _isListening = false);
          return;
        }
        if (mounted) {
          setState(() {
            _isListening = false;
            _isAssessing = true;
            _phase = ShadowingPhase.assessing;
          });
        }
        // Đánh giá cả câu
        final result = await _assessSentence(
          spoken: spoken,
          target: widget.sentences[_currentIndex].text,
        );
        if (mounted) {
          setState(() {
            _result = result;
            _isAssessing = false;
            _phase = ShadowingPhase.result;
            _totalScore += result.score;
            _completedCount++;
          });
          _progressCtrl.forward(from: 0);
        }
      },
    );

    if (!started && mounted) {
      _pulseCtrl.stop();
      setState(() {
        _isListening = false;
        _phase = ShadowingPhase.ready;
      });
    }
  }

  Future<ShadowingResult> _assessSentence({
    required String spoken,
    required String target,
  }) async {
    // Dùng MeowAI để đánh giá câu
    final assessment = await MeowAIService.assessPronunciation(
      spokenText: spoken,
      targetWord: target,
      phonetic: '',
    );

    // Tính word-level matching
    final targetWords = target.toLowerCase().split(RegExp(r'\s+'));
    final spokenWords = spoken.toLowerCase().split(RegExp(r'\s+'));
    final wordResults = <WordResult>[];

    for (final tw in targetWords) {
      final clean = tw.replaceAll(RegExp(r'[^a-z]'), '');
      if (clean.isEmpty) continue;
      final matched = spokenWords.any((sw) =>
          sw.replaceAll(RegExp(r'[^a-z]'), '') == clean ||
          _similarity(sw.replaceAll(RegExp(r'[^a-z]'), ''), clean) > 0.7);
      wordResults.add(WordResult(word: clean, correct: matched));
    }

    return ShadowingResult(
      score: assessment.score,
      comment: assessment.comment,
      tip: assessment.tip,
      spokenText: spoken,
      wordResults: wordResults,
    );
  }

  double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;
    final maxLen = a.length > b.length ? a.length : b.length;
    int dist = 0;
    for (int i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) dist++;
    }
    dist += (a.length - b.length).abs();
    return 1.0 - dist / maxLen;
  }

  void _nextSentence() {
    if (_currentIndex >= widget.sentences.length - 1) {
      _showFinalResult();
      return;
    }
    setState(() {
      _currentIndex++;
      _result = null;
      _phase = ShadowingPhase.ready;
    });
    _progressCtrl.reset();
  }

  void _showFinalResult() {
    final avg = _completedCount > 0 ? _totalScore ~/ _completedCount : 0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 Hoàn thành!',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Điểm trung bình: $avg/100',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF667eea)),
            ),
            const SizedBox(height: 8),
            Text(
              avg >= 80
                  ? '�� Phát âm xuất sắc!'
                  : avg >= 60
                      ? '👍 Tiến bộ tốt!'
                      : '💪 Cần luyện thêm!',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Xong'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sentence = widget.sentences[_currentIndex];
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '🎙️ Shadowing — ${widget.topicName}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_currentIndex + 1}/${widget.sentences.length}',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_currentIndex + 1) / widget.sentences.length,
              backgroundColor: Colors.white12,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
              minHeight: 3,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 24),

            // Phase indicator
            _PhaseIndicator(phase: _phase),
            const SizedBox(height: 24),

            // Sentence card
            _SentenceCard(
              sentence: sentence,
              result: _result,
              phase: _phase,
            ),
            const SizedBox(height: 28),

            // Controls
            _ShadowingControls(
              phase: _phase,
              sttAvailable: _sttAvailable,
              onPlay: _playSentence,
              onListen: _startListening,
              onNext: _nextSentence,
              pulseCtrl: _pulseCtrl,
            ),

            // Result panel
            if (_result != null) ...[
              const SizedBox(height: 24),
              _ShadowingResultPanel(result: _result!),
            ],

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Phase Indicator ──────────────────────────────────────────────────────────

class _PhaseIndicator extends StatelessWidget {
  final ShadowingPhase phase;
  const _PhaseIndicator({required this.phase});

  @override
  Widget build(BuildContext context) {
    final (emoji, label, color) = switch (phase) {
      ShadowingPhase.ready => ('👂', 'Nhấn Play để nghe câu mẫu', Colors.white54),
      ShadowingPhase.playing => ('🔊', 'Đang phát... Lắng nghe kỹ!', const Color(0xFF667eea)),
      ShadowingPhase.listening => ('🎤', 'Đọc theo ngay bây giờ!', const Color(0xFFFF6B35)),
      ShadowingPhase.assessing => ('⏳', 'Meow đang chấm điểm...', const Color(0xFFFFB347)),
      ShadowingPhase.result => ('✅', 'Xem kết quả bên dưới', const Color(0xFF06D6A0)),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// ─── Sentence Card ────────────────────────────────────────────────────────────

class _SentenceCard extends StatelessWidget {
  final ShadowingSentence sentence;
  final ShadowingResult? result;
  final ShadowingPhase phase;

  const _SentenceCard({
    required this.sentence,
    required this.result,
    required this.phase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: phase == ShadowingPhase.listening
              ? const Color(0xFFFF6B35).withOpacity(0.5)
              : const Color(0xFF667eea).withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sentence with word highlighting if result available
          result != null
              ? _HighlightedSentence(
                  sentence: sentence.text,
                  wordResults: result!.wordResults,
                )
              : Text(
                  sentence.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.6,
                  ),
                ),
          if (sentence.translation.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              sentence.translation,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          ],
          if (result != null && result!.spokenText.isNotEmpty) ...[
            const Divider(color: Colors.white12, height: 20),
            Row(
              children: [
                const Text('🎤 Bạn nói: ',
                    style: TextStyle(color: Colors.white38, fontSize: 12)),
                Expanded(
                  child: Text(
                    '"${result!.spokenText}"',
                    style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HighlightedSentence extends StatelessWidget {
  final String sentence;
  final List<WordResult> wordResults;

  const _HighlightedSentence({
    required this.sentence,
    required this.wordResults,
  });

  @override
  Widget build(BuildContext context) {
    final words = sentence.split(' ');
    final resultMap = {for (final r in wordResults) r.word: r.correct};

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: words.map((w) {
        final clean = w.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
        final correct = resultMap[clean];
        Color color;
        if (correct == null) {
          color = Colors.white;
        } else if (correct) {
          color = const Color(0xFF06D6A0);
        } else {
          color = const Color(0xFFFF4757);
        }
        return Text(
          '$w ',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.6,
          ),
        );
      }).toList(),
    );
  }
}

// ─── Controls ─────────────────────────────────────────────────────────────────

class _ShadowingControls extends StatelessWidget {
  final ShadowingPhase phase;
  final bool sttAvailable;
  final VoidCallback onPlay, onListen, onNext;
  final AnimationController pulseCtrl;

  const _ShadowingControls({
    required this.phase,
    required this.sttAvailable,
    required this.onPlay,
    required this.onListen,
    required this.onNext,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Play button
        _ControlBtn(
          emoji: '▶️',
          label: 'Nghe',
          color: const Color(0xFF667eea),
          enabled: phase == ShadowingPhase.ready || phase == ShadowingPhase.result,
          onTap: onPlay,
        ),
        const SizedBox(width: 16),
        // Mic button
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, child) => Transform.scale(
            scale: phase == ShadowingPhase.listening
                ? 1.0 + pulseCtrl.value * 0.1
                : 1.0,
            child: child,
          ),
          child: _ControlBtn(
            emoji: '🎤',
            label: 'Đọc theo',
            color: const Color(0xFFFF6B35),
            enabled: phase == ShadowingPhase.ready || phase == ShadowingPhase.result,
            onTap: onListen,
          ),
        ),
        const SizedBox(width: 16),
        // Next button
        _ControlBtn(
          emoji: '⏭️',
          label: 'Tiếp',
          color: const Color(0xFF06D6A0),
          enabled: phase == ShadowingPhase.result,
          onTap: onNext,
        ),
      ],
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ControlBtn({
    required this.emoji,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.3,
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.4), width: 2),
              ),
              child: Center(
                child: Text(emoji, style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                  color: enabled ? color : Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Result Panel ─────────────────────────────────────────────────────────────

class _ShadowingResultPanel extends StatelessWidget {
  final ShadowingResult result;
  const _ShadowingResultPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final correctCount = result.wordResults.where((w) => w.correct).length;
    final total = result.wordResults.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: result.scoreColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${result.score}',
                style: TextStyle(
                  color: result.scoreColor,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                '/100',
                style: TextStyle(color: Colors.white38, fontSize: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.comment,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '✅ $correctCount/$total từ đúng',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (result.tip.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '💡 ${result.tip}',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

enum ShadowingPhase { ready, playing, listening, assessing, result }

class ShadowingSentence {
  final String text;
  final String translation;
  const ShadowingSentence({required this.text, this.translation = ''});
}

class WordResult {
  final String word;
  final bool correct;
  const WordResult({required this.word, required this.correct});
}

class ShadowingResult {
  final int score;
  final String comment, tip, spokenText;
  final List<WordResult> wordResults;

  const ShadowingResult({
    required this.score,
    required this.comment,
    required this.tip,
    required this.spokenText,
    required this.wordResults,
  });

  Color get scoreColor {
    if (score >= 80) return const Color(0xFF06D6A0);
    if (score >= 60) return const Color(0xFFFFB347);
    return const Color(0xFFFF4757);
  }
}
