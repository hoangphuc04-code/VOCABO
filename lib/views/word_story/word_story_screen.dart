import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/config/app_secrets.dart';

/// 📖 Tính năng 4: Word Story Mode
/// Meow AI tạo câu chuyện ngắn chứa các từ đang học
/// Người dùng nhấn vào từ để xem nghĩa → học qua ngữ cảnh
class WordStoryScreen extends StatefulWidget {
  final List<StoryWord> words; // Tối đa 5 từ

  const WordStoryScreen({super.key, required this.words});

  @override
  State<WordStoryScreen> createState() => _WordStoryScreenState();
}

class _WordStoryScreenState extends State<WordStoryScreen>
    with SingleTickerProviderStateMixin {
  bool _loading = true;
  String _story = '';
  String _title = '';
  String _storyVi = '';
  bool _showTranslation = false;
  StoryWord? _selectedWord;
  final FlutterTts _tts = FlutterTts();
  bool _speaking = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _tts.setLanguage('en-US');
    _tts.setSpeechRate(0.42);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
    _generateStory();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _generateStory() async {
    setState(() => _loading = true);
    final wordList = widget.words.map((w) => w.word).join(', ');
    final wordDetails = widget.words
        .map((w) => '- ${w.word} (${w.meaning})')
        .join('\n');

    try {
      final apiKey = AppSecrets.groqApiKey;
      const model = 'llama-3.3-70b-versatile';

      final res = await http
          .post(
            Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {
                  'role': 'system',
                  'content': '''
Bạn là Meow 😺 — chuyên gia tạo câu chuyện học tiếng Anh.
Nhiệm vụ: Tạo câu chuyện ngắn tiếng Anh (5-7 câu) có chứa các từ được yêu cầu.

QUY TẮC:
1. Câu chuyện phải tự nhiên, thú vị, dễ hiểu (trình độ B1-B2)
2. Mỗi từ trong danh sách PHẢI xuất hiện ít nhất 1 lần trong câu chuyện
3. Trả lời ĐÚNG định dạng JSON sau:
{
  "title": "Tiêu đề câu chuyện (tiếng Anh)",
  "story": "Nội dung câu chuyện tiếng Anh...",
  "storyVi": "Bản dịch tiếng Việt của câu chuyện..."
}
4. KHÔNG thêm text nào ngoài JSON
''',
                },
                {
                  'role': 'user',
                  'content':
                      'Tạo câu chuyện chứa các từ sau:\n$wordDetails\n\nDanh sách từ: $wordList',
                },
              ],
              'max_tokens': 600,
              'temperature': 0.8,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final reply =
            (data['choices'][0]['message']['content'] as String).trim();
        final jsonStart = reply.indexOf('{');
        final jsonEnd = reply.lastIndexOf('}');
        if (jsonStart != -1 && jsonEnd != -1) {
          final parsed = jsonDecode(reply.substring(jsonStart, jsonEnd + 1))
              as Map<String, dynamic>;
          if (mounted) {
            setState(() {
              _title = parsed['title'] as String? ?? 'A Short Story';
              _story = parsed['story'] as String? ?? '';
              _storyVi = parsed['storyVi'] as String? ?? '';
              _loading = false;
            });
            _fadeCtrl.forward();
            // Lưu story vào Firestore
            _saveStory();
          }
          return;
        }
      }
    } catch (_) {}

    // Fallback story
    if (mounted) {
      setState(() {
        _title = 'A Learning Adventure';
        _story =
            'Could not generate story. Please check your connection and try again.';
        _loading = false;
      });
    }
  }

  Future<void> _saveStory() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      await FirebaseFirestore.instance.collection('word_stories').add({
        'uid': uid,
        'title': _title,
        'story': _story,
        'storyVi': _storyVi,
        'words': widget.words.map((w) => w.word).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<void> _speakStory() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts.speak(_story);
  }

  Future<void> _regenerate() async {
    _fadeCtrl.reset();
    setState(() {
      _selectedWord = null;
      _showTranslation = false;
    });
    await _generateStory();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        title: const Text(
          '📖 Word Story',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (!_loading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _regenerate,
              tooltip: 'Tạo câu chuyện mới',
            ),
        ],
      ),
      body: _loading
          ? _buildLoading()
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Word chips
                          _WordChips(words: widget.words),
                          const SizedBox(height: 20),

                          // Story card
                          _StoryCard(
                            title: _title,
                            story: _story,
                            storyVi: _storyVi,
                            words: widget.words,
                            showTranslation: _showTranslation,
                            speaking: _speaking,
                            onSpeak: _speakStory,
                            onToggleTranslation: () => setState(
                                () => _showTranslation = !_showTranslation),
                            onWordTap: (w) => setState(
                                () => _selectedWord =
                                    _selectedWord?.word == w.word ? null : w),
                          ),
                          const SizedBox(height: 16),

                          // Word popup
                          if (_selectedWord != null)
                            _WordPopup(word: _selectedWord!),

                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Color(0xFF667eea)),
          const SizedBox(height: 20),
          const Text(
            '😺 Meow đang viết câu chuyện...',
            style: TextStyle(
                color: Color(0xFF667eea),
                fontSize: 15,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Sử dụng ${widget.words.length} từ của bạn',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── Word Chips ───────────────────────────────────────────────────────────────

class _WordChips extends StatelessWidget {
  final List<StoryWord> words;
  const _WordChips({required this.words});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Từ vựng trong câu chuyện:',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: words
              .map((w) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF667eea).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: const Color(0xFF667eea).withOpacity(0.3)),
                    ),
                    child: Text(
                      '${w.word} · ${w.meaning}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667eea),
                          fontWeight: FontWeight.w500),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// ─── Story Card ───────────────────────────────────────────────────────────────

class _StoryCard extends StatelessWidget {
  final String title, story, storyVi;
  final List<StoryWord> words;
  final bool showTranslation, speaking;
  final VoidCallback onSpeak, onToggleTranslation;
  final ValueChanged<StoryWord> onWordTap;

  const _StoryCard({
    required this.title,
    required this.story,
    required this.storyVi,
    required this.words,
    required this.showTranslation,
    required this.speaking,
    required this.onSpeak,
    required this.onToggleTranslation,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title + controls
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF222222),
                  ),
                ),
              ),
              // Speak button
              IconButton(
                onPressed: onSpeak,
                icon: Icon(
                  speaking
                      ? Icons.stop_circle_outlined
                      : Icons.volume_up_rounded,
                  color: const Color(0xFF667eea),
                ),
                tooltip: 'Nghe câu chuyện',
              ),
              // Translation toggle
              IconButton(
                onPressed: onToggleTranslation,
                icon: Icon(
                  showTranslation
                      ? Icons.translate_rounded
                      : Icons.translate_outlined,
                  color: showTranslation
                      ? const Color(0xFF06D6A0)
                      : Colors.grey,
                ),
                tooltip: 'Xem bản dịch',
              ),
            ],
          ),
          const Divider(height: 16),
          const SizedBox(height: 4),

          // Story text với highlighted words
          _HighlightedText(
            text: story,
            words: words,
            onWordTap: onWordTap,
          ),

          // Translation
          if (showTranslation && storyVi.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF06D6A0).withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF06D6A0).withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🇻🇳 Bản dịch:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF06D6A0)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    storyVi,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF444444),
                        height: 1.6),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Text(
            '💡 Nhấn vào từ được highlight để xem nghĩa',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// ─── Highlighted Text ─────────────────────────────────────────────────────────

class _HighlightedText extends StatelessWidget {
  final String text;
  final List<StoryWord> words;
  final ValueChanged<StoryWord> onWordTap;

  const _HighlightedText({
    required this.text,
    required this.words,
    required this.onWordTap,
  });

  @override
  Widget build(BuildContext context) {
    // Tách text thành spans, highlight các từ trong danh sách
    final spans = <InlineSpan>[];
    final lowerText = text.toLowerCase();
    int cursor = 0;

    // Tìm tất cả vị trí của các từ cần highlight
    final matches = <_WordMatch>[];
    for (final w in words) {
      final pattern = RegExp(
        r'\b' + RegExp.escape(w.word.toLowerCase()) + r'\b',
        caseSensitive: false,
      );
      for (final m in pattern.allMatches(lowerText)) {
        matches.add(_WordMatch(start: m.start, end: m.end, word: w));
      }
    }
    matches.sort((a, b) => a.start.compareTo(b.start));

    for (final match in matches) {
      if (match.start < cursor) continue;
      // Text trước từ highlight
      if (match.start > cursor) {
        spans.add(TextSpan(
          text: text.substring(cursor, match.start),
          style: const TextStyle(
              color: Color(0xFF333333), fontSize: 15, height: 1.7),
        ));
      }
      // Từ highlight
      final originalWord = text.substring(match.start, match.end);
      spans.add(WidgetSpan(
        child: GestureDetector(
          onTap: () => onWordTap(match.word),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                  color: const Color(0xFF667eea).withOpacity(0.4)),
            ),
            child: Text(
              originalWord,
              style: const TextStyle(
                color: Color(0xFF667eea),
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.7,
              ),
            ),
          ),
        ),
      ));
      cursor = match.end;
    }

    // Text còn lại
    if (cursor < text.length) {
      spans.add(TextSpan(
        text: text.substring(cursor),
        style: const TextStyle(
            color: Color(0xFF333333), fontSize: 15, height: 1.7),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _WordMatch {
  final int start, end;
  final StoryWord word;
  const _WordMatch({required this.start, required this.end, required this.word});
}

// ─── Word Popup ───────────────────────────────────────────────────────────────

class _WordPopup extends StatelessWidget {
  final StoryWord word;
  const _WordPopup({required this.word});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                word.word,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              if (word.phonetic.isNotEmpty)
                Text(
                  word.phonetic,
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            word.meaning,
            style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
          ),
          if (word.example.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '"${word.example}"',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class StoryWord {
  final String word;
  final String meaning;
  final String phonetic;
  final String example;

  const StoryWord({
    required this.word,
    required this.meaning,
    this.phonetic = '',
    this.example = '',
  });
}


// ─── Entry Screen — chọn từ để tạo story ─────────────────────────────────────

/// Màn hình chọn từ đã học để tạo Word Story
class WordStoryEntryScreen extends StatefulWidget {
  const WordStoryEntryScreen({super.key});

  @override
  State<WordStoryEntryScreen> createState() => _WordStoryEntryScreenState();
}

class _WordStoryEntryScreenState extends State<WordStoryEntryScreen> {
  List<StoryWord> _allWords = [];
  List<StoryWord> _selected = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWords();
  }

  Future<void> _loadWords() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learned_words')
          .limit(50)
          .get();
      final words = snap.docs.map((d) {
        final data = d.data();
        return StoryWord(
          word: data['word'] as String? ?? '',
          meaning: data['meaning'] as String? ?? '',
          phonetic: data['phonetic'] as String? ?? '',
          example: data['example'] as String? ?? '',
        );
      }).where((w) => w.word.isNotEmpty).toList();
      words.shuffle();
      if (mounted) setState(() {
        _allWords = words;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleWord(StoryWord w) {
    setState(() {
      if (_selected.any((s) => s.word == w.word)) {
        _selected.removeWhere((s) => s.word == w.word);
      } else if (_selected.length < 5) {
        _selected.add(w);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        foregroundColor: Colors.white,
        title: const Text('📖 Word Story',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WordStoryScreen(words: _selected),
                ),
              ),
              child: Text(
                'Tạo (${_selected.length}/5)',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : _allWords.isEmpty
              ? const Center(
                  child: Text('Học thêm từ vựng để tạo câu chuyện!',
                      style: TextStyle(color: Colors.grey)))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: const Color(0xFF667eea).withOpacity(0.08),
                      child: Row(
                        children: [
                          const Text('💡 ',
                              style: TextStyle(fontSize: 16)),
                          Expanded(
                            child: Text(
                              'Chọn 2-5 từ để Meow AI tạo câu chuyện. Đã chọn: ${_selected.length}/5',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF667eea)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _allWords.length,
                        itemBuilder: (_, i) {
                          final w = _allWords[i];
                          final isSelected =
                              _selected.any((s) => s.word == w.word);
                          return GestureDetector(
                            onTap: () => _toggleWord(w),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF667eea).withOpacity(0.1)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF667eea)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF667eea)
                                          : Colors.grey.shade200,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.grey,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          w.word,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: isSelected
                                                ? const Color(0xFF667eea)
                                                : const Color(0xFF222222),
                                          ),
                                        ),
                                        Text(
                                          w.meaning,
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
      floatingActionButton: _selected.length >= 2
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WordStoryScreen(words: _selected),
                ),
              ),
              backgroundColor: const Color(0xFF667eea),
              icon: const Icon(Icons.auto_stories_rounded,
                  color: Colors.white),
              label: Text(
                'Tạo câu chuyện (${_selected.length} từ)',
                style: const TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}
