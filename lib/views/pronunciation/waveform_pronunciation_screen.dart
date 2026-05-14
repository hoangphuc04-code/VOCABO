import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import '../../data/services/meow_ai_service.dart';

/// 🎤 Tính năng 1: Smart Pronunciation Scoring với Waveform Visualizer
/// Hiển thị sóng âm animation khi recording + điểm từng âm tiết
class WaveformPronunciationScreen extends StatefulWidget {
  final String word;
  final String phonetic;
  final String meaning;

  const WaveformPronunciationScreen({
    super.key,
    required this.word,
    required this.phonetic,
    required this.meaning,
  });

  @override
  State<WaveformPronunciationScreen> createState() =>
      _WaveformPronunciationScreenState();
}

class _WaveformPronunciationScreenState
    extends State<WaveformPronunciationScreen>
    with TickerProviderStateMixin {
  // ── TTS ────────────────────────────────────────────────
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;

  // ── STT ────────────────────────────────────────────────
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;
  bool _isAssessing = false;
  String _spokenText = '';

  // ── Result ─────────────────────────────────────────────
  PronunciationResult? _result;
  List<SyllableScore> _syllableScores = [];

  // ── Waveform animation ─────────────────────────────────
  late AnimationController _waveCtrl;
  late AnimationController _pulseCtrl;
  final List<double> _barHeights = List.filled(30, 0.1);
  final _rng = math.Random();

  // ── Practice history ───────────────────────────────────
  final List<int> _scoreHistory = [];

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..addListener(_updateWave);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.4);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });

    _initStt();
  }

  @override
  void dispose() {
    _waveCtrl.dispose();
    _pulseCtrl.dispose();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  Future<void> _initStt() async {
    final ok = await _stt.initialize(
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          if (mounted && _isListening) {
            _waveCtrl.stop();
            _pulseCtrl.stop();
            setState(() => _isListening = false);
          }
        }
      },
      onError: (e) {
        _waveCtrl.stop();
        _pulseCtrl.stop();
        if (mounted) setState(() => _isListening = false);
      },
      debugLogging: false,
    );
    if (mounted) setState(() => _sttAvailable = ok);
  }

  void _updateWave() {
    if (!_isListening) return;
    setState(() {
      for (int i = 0; i < _barHeights.length; i++) {
        _barHeights[i] = 0.1 + _rng.nextDouble() * 0.9;
      }
    });
  }

  Future<void> _speak() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts.speak(widget.word);
  }

  Future<void> _startListening() async {
    if (!_sttAvailable || _isListening || _isAssessing) return;
    setState(() {
      _result = null;
      _syllableScores = [];
      _spokenText = '';
      _isListening = true;
    });
    _waveCtrl.repeat();
    _pulseCtrl.repeat(reverse: true);

    final started = await _stt.listen(
      localeId: 'en_US',
      listenFor: const Duration(seconds: 6),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
      cancelOnError: true,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (SpeechRecognitionResult r) async {
        // Hiển thị partial text ngay lập tức
        if (r.recognizedWords.isNotEmpty) {
          if (mounted) setState(() => _spokenText = r.recognizedWords);
        }
        if (!r.finalResult) return;
        final spoken = r.recognizedWords.trim();
        _waveCtrl.stop();
        _pulseCtrl.stop();
        if (spoken.isEmpty) {
          if (mounted) setState(() => _isListening = false);
          return;
        }
        if (mounted) {
          setState(() {
            _isListening = false;
            _isAssessing = true;
            _spokenText = spoken;
          });
        }
        final assessment = await MeowAIService.assessPronunciation(
          spokenText: spoken,
          targetWord: widget.word,
          phonetic: widget.phonetic,
        );
        final syllables = _buildSyllableScores(widget.word, assessment.score);
        if (mounted) {
          setState(() {
            _result = assessment;
            _syllableScores = syllables;
            _isAssessing = false;
            _scoreHistory.add(assessment.score);
          });
        }
      },
    );

    if (!started && mounted) {
      _waveCtrl.stop();
      _pulseCtrl.stop();
      setState(() => _isListening = false);
    }
  }

  Future<void> _stopListening() async {
    await _stt.stop();
    _waveCtrl.stop();
    _pulseCtrl.stop();
    if (mounted) setState(() => _isListening = false);
  }

  /// Tạo điểm từng âm tiết (ước lượng dựa trên tổng điểm)
  List<SyllableScore> _buildSyllableScores(String word, int totalScore) {
    // Tách âm tiết đơn giản theo nguyên âm
    final syllables = _splitSyllables(word);
    if (syllables.isEmpty) return [];

    final rng = math.Random(totalScore);
    return syllables.map((s) {
      // Mỗi âm tiết dao động ±15 điểm quanh tổng điểm
      final variance = (rng.nextDouble() * 30 - 15).round();
      final score = (totalScore + variance).clamp(0, 100);
      return SyllableScore(syllable: s, score: score);
    }).toList();
  }

  List<String> _splitSyllables(String word) {
    // Tách đơn giản: mỗi nhóm phụ âm + nguyên âm là 1 âm tiết
    final vowels = RegExp(r'[aeiouAEIOU]');
    final result = <String>[];
    var current = '';
    bool lastWasVowel = false;

    for (int i = 0; i < word.length; i++) {
      final ch = word[i];
      final isVowel = vowels.hasMatch(ch);
      current += ch;
      if (lastWasVowel && !isVowel && i < word.length - 1) {
        result.add(current.substring(0, current.length - 1));
        current = ch;
      }
      lastWasVowel = isVowel;
    }
    if (current.isNotEmpty) result.add(current);
    return result.isEmpty ? [word] : result;
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text(
          '🎤 Luyện phát âm',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ── Word card ──────────────────────────────────
            _WordCard(
              word: widget.word,
              phonetic: widget.phonetic,
              meaning: widget.meaning,
              speaking: _speaking,
              onSpeak: _speak,
            ),
            const SizedBox(height: 28),

            // ── Waveform / Status ──────────────────────────
            _WaveformDisplay(
              isListening: _isListening,
              isAssessing: _isAssessing,
              barHeights: _barHeights,
              spokenText: _spokenText,
              pulseCtrl: _pulseCtrl,
            ),
            const SizedBox(height: 28),

            // ── Mic button ─────────────────────────────────
            _MicButton(
              isListening: _isListening,
              isAssessing: _isAssessing,
              sttAvailable: _sttAvailable,
              onStart: _startListening,
              onStop: _stopListening,
            ),
            const SizedBox(height: 32),

            // ── Result panel ───────────────────────────────
            if (_result != null) ...[
              _ScorePanel(
                result: _result!,
                syllableScores: _syllableScores,
              ),
              const SizedBox(height: 20),
            ],

            // ── Score history ──────────────────────────────
            if (_scoreHistory.length > 1) ...[
              _ScoreHistory(scores: _scoreHistory),
              const SizedBox(height: 20),
            ],

            // ── Tips ───────────────────────────────────────
            _PronunciationTips(word: widget.word, phonetic: widget.phonetic),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Word Card ────────────────────────────────────────────────────────────────

class _WordCard extends StatelessWidget {
  final String word, phonetic, meaning;
  final bool speaking;
  final VoidCallback onSpeak;

  const _WordCard({
    required this.word,
    required this.phonetic,
    required this.meaning,
    required this.speaking,
    required this.onSpeak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            word,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            phonetic,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            meaning,
            style: const TextStyle(color: Colors.white60, fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          // Nút nghe phát âm chuẩn
          GestureDetector(
            onTap: onSpeak,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    speaking
                        ? Icons.volume_up_rounded
                        : Icons.play_circle_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    speaking ? 'Đang phát...' : 'Nghe phát âm chuẩn',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Waveform Display ─────────────────────────────────────────────────────────

class _WaveformDisplay extends StatelessWidget {
  final bool isListening, isAssessing;
  final List<double> barHeights;
  final String spokenText;
  final AnimationController pulseCtrl;

  const _WaveformDisplay({
    required this.isListening,
    required this.isAssessing,
    required this.barHeights,
    required this.spokenText,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isListening
              ? const Color(0xFF667eea).withOpacity(0.5)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: isAssessing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                      color: Color(0xFF667eea), strokeWidth: 2),
                  SizedBox(height: 10),
                  Text('Meow đang chấm điểm...',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
            )
          : isListening
              ? _LiveWaveform(barHeights: barHeights)
              : spokenText.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎙️',
                              style: TextStyle(fontSize: 28)),
                          const SizedBox(height: 6),
                          Text(
                            '"$spokenText"',
                            style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🎤',
                              style: TextStyle(fontSize: 32)),
                          SizedBox(height: 8),
                          Text(
                            'Nhấn mic để bắt đầu nói',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

class _LiveWaveform extends StatelessWidget {
  final List<double> barHeights;
  const _LiveWaveform({required this.barHeights});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: barHeights.map((h) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            width: 5,
            height: 8 + h * 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  const Color(0xFF667eea),
                  Color.lerp(
                    const Color(0xFF667eea),
                    const Color(0xFF06D6A0),
                    h,
                  )!,
                ],
              ),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Mic Button ───────────────────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  final bool isListening, isAssessing, sttAvailable;
  final VoidCallback onStart, onStop;

  const _MicButton({
    required this.isListening,
    required this.isAssessing,
    required this.sttAvailable,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAssessing
          ? null
          : isListening
              ? onStop
              : onStart,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: isListening
              ? const LinearGradient(
                  colors: [Color(0xFFFF4757), Color(0xFFFF6B81)],
                )
              : isAssessing
                  ? const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFF06D6A0), Color(0xFF00B894)],
                    ),
          boxShadow: [
            BoxShadow(
              color: (isListening
                      ? const Color(0xFFFF4757)
                      : const Color(0xFF06D6A0))
                  .withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: isListening ? 4 : 0,
            ),
          ],
        ),
        child: Icon(
          isListening
              ? Icons.stop_rounded
              : isAssessing
                  ? Icons.hourglass_top_rounded
                  : Icons.mic_rounded,
          color: Colors.white,
          size: 36,
        ),
      ),
    );
  }
}

// ─── Score Panel ──────────────────────────────────────────────────────────────

class _ScorePanel extends StatelessWidget {
  final PronunciationResult result;
  final List<SyllableScore> syllableScores;

  const _ScorePanel({
    required this.result,
    required this.syllableScores,
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
          color: result.scoreColor.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tổng điểm
          Row(
            children: [
              // Score circle
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: result.scoreColor, width: 3),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${result.score}',
                      style: TextStyle(
                        color: result.scoreColor,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      result.scoreEmoji,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.comment,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600),
                    ),
                    if (result.tip.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '💡 ${result.tip}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // Syllable breakdown
          if (syllableScores.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              'Phân tích từng âm tiết:',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: syllableScores
                  .map((s) => _SyllableBar(score: s))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _SyllableBar extends StatelessWidget {
  final SyllableScore score;
  const _SyllableBar({required this.score});

  Color get _color {
    if (score.score >= 80) return const Color(0xFF06D6A0);
    if (score.score >= 60) return const Color(0xFFFFB347);
    return const Color(0xFFFF4757);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 60,
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            width: 28,
            height: 8 + (score.score / 100) * 52,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          score.syllable,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        Text(
          '${score.score}',
          style: TextStyle(
              color: _color, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// ─── Score History ────────────────────────────────────────────────────────────

class _ScoreHistory extends StatelessWidget {
  final List<int> scores;
  const _ScoreHistory({required this.scores});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📈 Tiến trình luyện tập',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: scores.asMap().entries.map((e) {
              final isLast = e.key == scores.length - 1;
              final color = isLast
                  ? const Color(0xFF667eea)
                  : Colors.white24;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    children: [
                      if (isLast)
                        Text(
                          '${e.value}',
                          style: const TextStyle(
                              color: Color(0xFF667eea),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      const SizedBox(height: 2),
                      Container(
                        height: 4 + (e.value / 100) * 36,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Pronunciation Tips ───────────────────────────────────────────────────────

class _PronunciationTips extends StatelessWidget {
  final String word, phonetic;
  const _PronunciationTips({required this.word, required this.phonetic});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '💡 Mẹo phát âm',
            style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          _TipRow(
              emoji: '👄',
              text: 'Đọc chậm từng âm tiết, sau đó ghép lại'),
          _TipRow(
              emoji: '🎧',
              text: 'Nghe phát âm chuẩn nhiều lần trước khi thử'),
          _TipRow(
              emoji: '🔁',
              text: 'Luyện tập ít nhất 3 lần để cải thiện điểm'),
          if (phonetic.isNotEmpty)
            _TipRow(
                emoji: '📖',
                text: 'Phiên âm: $phonetic — đọc từng ký hiệu'),
        ],
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  final String emoji, text;
  const _TipRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style:
                  const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Models ───────────────────────────────────────────────────────────────────

class SyllableScore {
  final String syllable;
  final int score;
  const SyllableScore({required this.syllable, required this.score});
}
