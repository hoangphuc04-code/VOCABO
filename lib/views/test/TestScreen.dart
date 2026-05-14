// VOCABO — TestScreen v2
// Khi bấm "Kiểm tra": AI (Groq) tự generate đề thi CEFR đủ 4 kỹ năng:
//   1. Vocabulary  — Từ vựng (trắc nghiệm, đồng/trái nghĩa)
//   2. Grammar     — Ngữ pháp (chia động từ, chọn đáp án đúng)
//   3. Reading     — Đọc hiểu (đoạn văn + câu hỏi)
//   4. Listening   — Nghe hiểu (transcript + câu hỏi)
// Mỗi kỹ năng 5 câu → tổng 20 câu / đề
// Lưu kết quả theo từng kỹ năng lên Firestore

import 'dart:async';
import 'dart:ui' show FontFeature;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:vocabodemo/core/config/app_secrets.dart';
import 'package:vocabodemo/core/utils/responsive.dart';
import 'package:vocabodemo/data/services/streak_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────

const _kGroqUrl = 'https://api.groq.com/openai/v1/chat/completions';
const _kModel   = 'llama-3.3-70b-versatile';

// CEFR levels
const _kCefrLevels = ['A1', 'A2', 'B1', 'B2', 'C1', 'C2'];

// Skill labels
const _kSkills = [
  _SkillInfo(id: 'vocabulary', label: 'Từ vựng',   emoji: '📖', color: Color(0xFF667eea)),
  _SkillInfo(id: 'grammar',    label: 'Ngữ pháp',  emoji: '✏️', color: Color(0xFF06D6A0)),
  _SkillInfo(id: 'reading',    label: 'Đọc hiểu',  emoji: '📰', color: Color(0xFFFF9F1C)),
  _SkillInfo(id: 'listening',  label: 'Nghe hiểu', emoji: '🎧', color: Color(0xFFFF6B6B)),
];

// Thời gian thi CEFR thực tế (phút) — theo chuẩn Cambridge/Goethe
// A1/A2: 45 phút | B1: 60 phút | B2: 75 phút | C1: 90 phút | C2: 105 phút
const _kExamTimeMinutes = {
  'A1': 45, 'A2': 45, 'B1': 60, 'B2': 75, 'C1': 90, 'C2': 105,
};

// ─────────────────────────────────────────────────────────────────────────────
// MODELS
// ─────────────────────────────────────────────────────────────────────────────

class _SkillInfo {
  final String id;
  final String label;
  final String emoji;
  final Color color;
  const _SkillInfo({required this.id, required this.label, required this.emoji, required this.color});
}

class _CefrQuestion {
  final int number;
  final String skill;       // vocabulary / grammar / reading / listening
  final String instruction; // hướng dẫn
  final String? passage;    // đoạn văn (reading/listening)
  final String questionText;
  final List<String> options; // A, B, C, D
  final int correctIndex;     // 0-3
  final String explanation;

  const _CefrQuestion({
    required this.number,
    required this.skill,
    required this.instruction,
    this.passage,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  String get correctAnswer => options[correctIndex];
}

class _UserAnswer {
  final int questionIndex;
  final int selectedIndex; // -1 = timeout
  final bool isCorrect;
  const _UserAnswer({required this.questionIndex, required this.selectedIndex, required this.isCorrect});
}

// ─────────────────────────────────────────────────────────────────────────────
// TEST SCREEN — Entry point
// ─────────────────────────────────────────────────────────────────────────────

class TestScreen extends StatefulWidget {
  const TestScreen({super.key});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  String _selectedLevel = 'B1';

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: CustomScrollView(
        slivers: [
          // ── AppBar ──────────────────────────────────────
          SliverAppBar(
            expandedHeight: r.w(160),
            pinned: true,
            backgroundColor: const Color(0xFF667eea),
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(left: r.hPad, bottom: 16),
              title: Text(
                'Kiểm tra CEFR',
                style: TextStyle(
                  fontSize: r.sp(20),
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: r.hPad,
                      top: 40,
                      child: Text('📝', style: TextStyle(fontSize: r.sp(52))),
                    ),
                    Positioned(
                      left: r.hPad,
                      bottom: 48,
                      child: Text(
                        'AI tự generate đề thi',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: r.sp(13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Body ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(r.hPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: r.w(8)),

                  // ── Skill cards ──────────────────────────
                  Text(
                    '4 kỹ năng CEFR',
                    style: TextStyle(
                      fontSize: r.sp(17),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  SizedBox(height: r.w(12)),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: r.w(12),
                    mainAxisSpacing: r.w(12),
                    childAspectRatio: 1.6,
                    children: _kSkills.map((s) => _SkillCard(skill: s)).toList(),
                  ),
                  SizedBox(height: r.w(24)),

                  // ── Level selector ───────────────────────
                  Text(
                    'Chọn cấp độ',
                    style: TextStyle(
                      fontSize: r.sp(17),
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2D3748),
                    ),
                  ),
                  SizedBox(height: r.w(12)),
                  Wrap(
                    spacing: r.w(10),
                    runSpacing: r.w(10),
                    children: _kCefrLevels.map((lvl) => _LevelChip(
                      level: lvl,
                      selected: _selectedLevel == lvl,
                      onTap: () => setState(() => _selectedLevel = lvl),
                    )).toList(),
                  ),
                  SizedBox(height: r.w(24)),

                  // ── Info card ────────────────────────────
                  _InfoCard(level: _selectedLevel),
                  SizedBox(height: r.w(28)),

                  // ── Start button ─────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: r.w(58),
                    child: ElevatedButton(
                      onPressed: () => _startExam(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        foregroundColor: Colors.white,
                        elevation: 6,
                        shadowColor: const Color(0xFF667eea).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(r.r(18)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🚀', style: TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Text(
                            'Bắt đầu kiểm tra',
                            style: TextStyle(
                              fontSize: r.sp(18),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: r.w(24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _startExam(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _GeneratingScreen(level: _selectedLevel),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GENERATING SCREEN — gọi AI generate đề, hiển thị loading
// ─────────────────────────────────────────────────────────────────────────────

class _GeneratingScreen extends StatefulWidget {
  final String level;
  const _GeneratingScreen({required this.level});

  @override
  State<_GeneratingScreen> createState() => _GeneratingScreenState();
}

class _GeneratingScreenState extends State<_GeneratingScreen>
    with SingleTickerProviderStateMixin {
  String _statusMsg = 'Đang khởi tạo...';
  double _progress = 0;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _generate();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    final questions = <_CefrQuestion>[];

    for (int i = 0; i < _kSkills.length; i++) {
      final skill = _kSkills[i];
      if (!mounted) return;
      setState(() {
        _statusMsg = '${skill.emoji} Đang tạo câu hỏi ${skill.label}...';
        _progress = i / _kSkills.length;
      });

      try {
        final batch = await _CefrGenerator.generateSkillQuestions(
          skill: skill.id,
          level: widget.level,
          count: 5,
          startNumber: questions.length + 1,
        );
        questions.addAll(batch);
      } catch (e) {
        // Nếu lỗi 1 kỹ năng → dùng fallback questions
        final fallback = _CefrGenerator.fallbackQuestions(
          skill: skill.id,
          level: widget.level,
          startNumber: questions.length + 1,
        );
        questions.addAll(fallback);
      }
    }

    if (!mounted) return;
    setState(() {
      _statusMsg = '✅ Đề thi đã sẵn sàng!';
      _progress = 1.0;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _ExamScreen(
          questions: questions,
          level: widget.level,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Scaffold(
      backgroundColor: const Color(0xFF667eea),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(r.hPad),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Pulse animation
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: r.w(120),
                    height: r.w(120),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text('🤖', style: TextStyle(fontSize: r.sp(52))),
                    ),
                  ),
                ),
                SizedBox(height: r.w(32)),
                Text(
                  'AI đang tạo đề thi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: r.sp(22),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: r.w(8)),
                Text(
                  'Cấp độ ${widget.level} • 20 câu • 4 kỹ năng',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: r.sp(14),
                  ),
                ),
                SizedBox(height: r.w(40)),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _progress,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 8,
                  ),
                ),
                SizedBox(height: r.w(16)),
                Text(
                  _statusMsg,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: r.sp(14),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: r.w(48)),
                // Skill progress indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _kSkills.asMap().entries.map((e) {
                    final done = _progress > (e.key / _kSkills.length);
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: r.w(8)),
                      child: Column(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: r.w(44),
                            height: r.w(44),
                            decoration: BoxDecoration(
                              color: done
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                e.value.emoji,
                                style: TextStyle(fontSize: r.sp(20)),
                              ),
                            ),
                          ),
                          SizedBox(height: r.w(6)),
                          Text(
                            e.value.label,
                            style: TextStyle(
                              color: done
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                              fontSize: r.sp(11),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CEFR GENERATOR — gọi Groq API để tạo câu hỏi
// ─────────────────────────────────────────────────────────────────────────────

class _CefrGenerator {
  static String get _apiKey => AppSecrets.groqApiKey;

  static String _buildPrompt(String skill, String level, int count, int startNum) {
    final skillDesc = {
      'vocabulary': '''
Tạo $count câu hỏi từ vựng tiếng Anh cấp độ $level.
Dạng câu hỏi: trắc nghiệm 4 đáp án (A/B/C/D).
Bao gồm: chọn nghĩa đúng, đồng nghĩa, trái nghĩa, điền từ vào câu.
Instruction mẫu: "Choose the correct meaning", "Choose the synonym", "Choose the antonym", "Choose the best word to complete the sentence".
''',
      'grammar': '''
Tạo $count câu hỏi ngữ pháp tiếng Anh cấp độ $level.
Dạng câu hỏi: trắc nghiệm 4 đáp án (A/B/C/D).
Bao gồm: chia động từ, chọn thì đúng, câu điều kiện, mệnh đề quan hệ, câu bị động.
Instruction mẫu: "Choose the correct verb form", "Choose the correct tense", "Complete the sentence with the correct form".
''',
      'reading': '''
Tạo 1 đoạn văn ngắn (4-6 câu, cấp độ $level) rồi tạo $count câu hỏi đọc hiểu về đoạn văn đó.
Câu hỏi: trắc nghiệm 4 đáp án (A/B/C/D).
Instruction: "Read the passage and answer the questions".
Tất cả $count câu đều dùng chung 1 đoạn văn (passage).
''',
      'listening': '''
Tạo 1 đoạn transcript ngắn (4-6 câu, cấp độ $level, dạng hội thoại hoặc thông báo) rồi tạo $count câu hỏi nghe hiểu.
Câu hỏi: trắc nghiệm 4 đáp án (A/B/C/D).
Instruction: "Listen to the audio and answer the questions" (đây là transcript mô phỏng).
Tất cả $count câu đều dùng chung 1 transcript (passage).
''',
    };

    return '''
Bạn là chuyên gia ra đề thi tiếng Anh theo chuẩn CEFR.
${skillDesc[skill] ?? ''}

YÊU CẦU QUAN TRỌNG:
- Câu hỏi phải phù hợp đúng cấp độ $level
- Đáp án sai phải hợp lý (không quá dễ đoán)
- Giải thích ngắn gọn tại sao đáp án đúng
- Đánh số câu bắt đầu từ $startNum

TRẢ LỜI ĐÚNG ĐỊNH DẠNG JSON SAU (không thêm text nào khác):
{
  "skill": "$skill",
  "passage": "đoạn văn/transcript (chỉ cho reading/listening, null cho vocabulary/grammar)",
  "questions": [
    {
      "number": $startNum,
      "instruction": "hướng dẫn làm bài",
      "questionText": "nội dung câu hỏi",
      "options": ["đáp án A", "đáp án B", "đáp án C", "đáp án D"],
      "correctIndex": 0,
      "explanation": "giải thích ngắn tại sao đáp án đúng"
    }
  ]
}

correctIndex là chỉ số 0-3 của đáp án đúng trong mảng options.
''';
  }

  static Future<List<_CefrQuestion>> generateSkillQuestions({
    required String skill,
    required String level,
    required int count,
    required int startNumber,
  }) async {
    final prompt = _buildPrompt(skill, level, count, startNumber);

    final res = await http.post(
      Uri.parse(_kGroqUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'model': _kModel,
        'messages': [
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 2500,
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 45));

    if (res.statusCode != 200) {
      throw Exception('API error ${res.statusCode}');
    }

    final data  = jsonDecode(res.body);
    final reply = data['choices'][0]['message']['content'] as String;

    // Extract JSON từ response
    final jsonStart = reply.indexOf('{');
    final jsonEnd   = reply.lastIndexOf('}');
    if (jsonStart == -1 || jsonEnd == -1) {
      throw Exception('Invalid JSON response');
    }

    final parsed = jsonDecode(reply.substring(jsonStart, jsonEnd + 1)) as Map<String, dynamic>;
    final passage = parsed['passage'] as String?;
    final rawQs   = parsed['questions'] as List<dynamic>;

    return rawQs.map((q) {
      final opts = (q['options'] as List<dynamic>).map((o) => o.toString()).toList();
      final ci   = (q['correctIndex'] as num).toInt().clamp(0, opts.length - 1);
      return _CefrQuestion(
        number:       (q['number'] as num).toInt(),
        skill:        skill,
        instruction:  q['instruction'] as String? ?? '',
        passage:      passage,
        questionText: q['questionText'] as String? ?? '',
        options:      opts,
        correctIndex: ci,
        explanation:  q['explanation'] as String? ?? '',
      );
    }).toList();
  }

  // Fallback khi AI lỗi — câu hỏi mẫu cứng
  static List<_CefrQuestion> fallbackQuestions({
    required String skill,
    required String level,
    required int startNumber,
  }) {
    final rng = Random();
    final templates = _kFallbackTemplates[skill] ?? _kFallbackTemplates['vocabulary']!;
    final shuffled = List.of(templates)..shuffle(rng);
    return shuffled.take(5).toList().asMap().entries.map((e) {
      final t = e.value;
      return _CefrQuestion(
        number:       startNumber + e.key,
        skill:        skill,
        instruction:  t['instruction'] as String,
        passage:      t['passage'] as String?,
        questionText: t['questionText'] as String,
        options:      List<String>.from(t['options'] as List),
        correctIndex: t['correctIndex'] as int,
        explanation:  t['explanation'] as String,
      );
    }).toList();
  }
}

// Fallback templates khi AI không khả dụng
const _kFallbackTemplates = {
  'vocabulary': [
    {'instruction': 'Choose the correct meaning', 'passage': null, 'questionText': 'What does "abundant" mean?', 'options': ['Scarce', 'Plentiful', 'Expensive', 'Dangerous'], 'correctIndex': 1, 'explanation': '"Abundant" means existing in large quantities — plentiful.'},
    {'instruction': 'Choose the synonym', 'passage': null, 'questionText': 'Choose the synonym of "brave":', 'options': ['Cowardly', 'Timid', 'Courageous', 'Weak'], 'correctIndex': 2, 'explanation': '"Brave" and "courageous" both mean showing no fear.'},
    {'instruction': 'Choose the antonym', 'passage': null, 'questionText': 'Choose the antonym of "ancient":', 'options': ['Old', 'Modern', 'Historic', 'Traditional'], 'correctIndex': 1, 'explanation': '"Ancient" means very old; its antonym is "modern".'},
    {'instruction': 'Complete the sentence', 'passage': null, 'questionText': 'She has a _____ personality that attracts many friends.', 'options': ['hostile', 'boring', 'charismatic', 'dull'], 'correctIndex': 2, 'explanation': '"Charismatic" means having a compelling charm that inspires devotion.'},
    {'instruction': 'Choose the correct meaning', 'passage': null, 'questionText': 'What does "diligent" mean?', 'options': ['Lazy', 'Careless', 'Hardworking', 'Reckless'], 'correctIndex': 2, 'explanation': '"Diligent" means having or showing care and conscientiousness in work.'},
  ],
  'grammar': [
    {'instruction': 'Choose the correct verb form', 'passage': null, 'questionText': 'By the time she arrived, he _____ for two hours.', 'options': ['waited', 'has waited', 'had been waiting', 'was waiting'], 'correctIndex': 2, 'explanation': 'Past perfect continuous is used for an action that was ongoing before another past action.'},
    {'instruction': 'Choose the correct form', 'passage': null, 'questionText': 'If I _____ you, I would apologize immediately.', 'options': ['am', 'was', 'were', 'be'], 'correctIndex': 2, 'explanation': 'In second conditional, we use "were" for all subjects (subjunctive mood).'},
    {'instruction': 'Choose the correct tense', 'passage': null, 'questionText': 'She _____ English for five years before she moved abroad.', 'options': ['studied', 'has studied', 'had studied', 'was studying'], 'correctIndex': 2, 'explanation': 'Past perfect is used for an action completed before another past event.'},
    {'instruction': 'Complete the sentence', 'passage': null, 'questionText': 'The report _____ by the manager yesterday.', 'options': ['wrote', 'was written', 'has written', 'is writing'], 'correctIndex': 1, 'explanation': 'Passive voice: subject + was/were + past participle.'},
    {'instruction': 'Choose the correct form', 'passage': null, 'questionText': 'I wish I _____ more time to study last week.', 'options': ['have', 'had', 'had had', 'would have'], 'correctIndex': 2, 'explanation': '"Wish + past perfect" expresses regret about a past situation.'},
  ],
  'reading': [
    {'instruction': 'Read the passage and answer', 'passage': 'Climate change is one of the most pressing issues of our time. Rising temperatures are causing glaciers to melt, sea levels to rise, and extreme weather events to become more frequent. Scientists warn that without immediate action, the consequences could be irreversible. Governments and individuals must work together to reduce carbon emissions and transition to renewable energy sources.', 'questionText': 'What is the main topic of the passage?', 'options': ['Ocean pollution', 'Climate change', 'Renewable energy', 'Government policies'], 'correctIndex': 1, 'explanation': 'The passage primarily discusses climate change and its effects.'},
    {'instruction': 'Read the passage and answer', 'passage': 'Climate change is one of the most pressing issues of our time. Rising temperatures are causing glaciers to melt, sea levels to rise, and extreme weather events to become more frequent. Scientists warn that without immediate action, the consequences could be irreversible. Governments and individuals must work together to reduce carbon emissions and transition to renewable energy sources.', 'questionText': 'According to the passage, what are glaciers doing?', 'options': ['Growing larger', 'Melting', 'Staying the same', 'Moving faster'], 'correctIndex': 1, 'explanation': 'The passage states "Rising temperatures are causing glaciers to melt."'},
    {'instruction': 'Read the passage and answer', 'passage': 'Climate change is one of the most pressing issues of our time. Rising temperatures are causing glaciers to melt, sea levels to rise, and extreme weather events to become more frequent. Scientists warn that without immediate action, the consequences could be irreversible. Governments and individuals must work together to reduce carbon emissions and transition to renewable energy sources.', 'questionText': 'What does the word "irreversible" mean in the passage?', 'options': ['Temporary', 'Manageable', 'Cannot be undone', 'Predictable'], 'correctIndex': 2, 'explanation': '"Irreversible" means impossible to change back to a previous condition.'},
    {'instruction': 'Read the passage and answer', 'passage': 'Climate change is one of the most pressing issues of our time. Rising temperatures are causing glaciers to melt, sea levels to rise, and extreme weather events to become more frequent. Scientists warn that without immediate action, the consequences could be irreversible. Governments and individuals must work together to reduce carbon emissions and transition to renewable energy sources.', 'questionText': 'Who must work together according to the passage?', 'options': ['Scientists and teachers', 'Governments and individuals', 'Companies and banks', 'Students and parents'], 'correctIndex': 1, 'explanation': 'The passage states "Governments and individuals must work together."'},
    {'instruction': 'Read the passage and answer', 'passage': 'Climate change is one of the most pressing issues of our time. Rising temperatures are causing glaciers to melt, sea levels to rise, and extreme weather events to become more frequent. Scientists warn that without immediate action, the consequences could be irreversible. Governments and individuals must work together to reduce carbon emissions and transition to renewable energy sources.', 'questionText': 'What solution does the passage suggest?', 'options': ['Build more factories', 'Reduce carbon emissions', 'Stop using electricity', 'Move to higher ground'], 'correctIndex': 1, 'explanation': 'The passage suggests reducing carbon emissions and transitioning to renewable energy.'},
  ],
  'listening': [
    {'instruction': 'Listen to the audio and answer', 'passage': '[Transcript] Receptionist: Good morning, City Hotel. How can I help you?\nCaller: Hi, I\'d like to book a room for two nights, from Friday to Sunday.\nReceptionist: Of course. Would you prefer a single or double room?\nCaller: A double room, please. Do you have any rooms with a sea view?\nReceptionist: Yes, we do. The sea-view double room is \$150 per night.\nCaller: That sounds perfect. I\'ll take it.', 'questionText': 'How many nights does the caller want to stay?', 'options': ['One night', 'Two nights', 'Three nights', 'Four nights'], 'correctIndex': 1, 'explanation': 'The caller says "I\'d like to book a room for two nights."'},
    {'instruction': 'Listen to the audio and answer', 'passage': '[Transcript] Receptionist: Good morning, City Hotel. How can I help you?\nCaller: Hi, I\'d like to book a room for two nights, from Friday to Sunday.\nReceptionist: Of course. Would you prefer a single or double room?\nCaller: A double room, please. Do you have any rooms with a sea view?\nReceptionist: Yes, we do. The sea-view double room is \$150 per night.\nCaller: That sounds perfect. I\'ll take it.', 'questionText': 'What type of room does the caller request?', 'options': ['Single room', 'Double room', 'Suite', 'Family room'], 'correctIndex': 1, 'explanation': 'The caller specifically asks for "a double room."'},
    {'instruction': 'Listen to the audio and answer', 'passage': '[Transcript] Receptionist: Good morning, City Hotel. How can I help you?\nCaller: Hi, I\'d like to book a room for two nights, from Friday to Sunday.\nReceptionist: Of course. Would you prefer a single or double room?\nCaller: A double room, please. Do you have any rooms with a sea view?\nReceptionist: Yes, we do. The sea-view double room is \$150 per night.\nCaller: That sounds perfect. I\'ll take it.', 'questionText': 'How much does the sea-view room cost per night?', 'options': ['\$100', '\$120', '\$150', '\$200'], 'correctIndex': 2, 'explanation': 'The receptionist says "The sea-view double room is \$150 per night."'},
    {'instruction': 'Listen to the audio and answer', 'passage': '[Transcript] Receptionist: Good morning, City Hotel. How can I help you?\nCaller: Hi, I\'d like to book a room for two nights, from Friday to Sunday.\nReceptionist: Of course. Would you prefer a single or double room?\nCaller: A double room, please. Do you have any rooms with a sea view?\nReceptionist: Yes, we do. The sea-view double room is \$150 per night.\nCaller: That sounds perfect. I\'ll take it.', 'questionText': 'What special feature does the caller ask about?', 'options': ['Mountain view', 'Sea view', 'City view', 'Garden view'], 'correctIndex': 1, 'explanation': 'The caller asks "Do you have any rooms with a sea view?"'},
    {'instruction': 'Listen to the audio and answer', 'passage': '[Transcript] Receptionist: Good morning, City Hotel. How can I help you?\nCaller: Hi, I\'d like to book a room for two nights, from Friday to Sunday.\nReceptionist: Of course. Would you prefer a single or double room?\nCaller: A double room, please. Do you have any rooms with a sea view?\nReceptionist: Yes, we do. The sea-view double room is \$150 per night.\nCaller: That sounds perfect. I\'ll take it.', 'questionText': 'What is the caller\'s final decision?', 'options': ['Cancel the booking', 'Ask for a discount', 'Book the sea-view room', 'Choose a cheaper room'], 'correctIndex': 2, 'explanation': 'The caller says "That sounds perfect. I\'ll take it," confirming the sea-view room.'},
  ],
};

// ─────────────────────────────────────────────────────────────────────────────
// EXAM SCREEN — tổng thời gian CEFR thật, tự do điều hướng
// ─────────────────────────────────────────────────────────────────────────────

class _ExamScreen extends StatefulWidget {
  final List<_CefrQuestion> questions;
  final String level;
  const _ExamScreen({required this.questions, required this.level});

  @override
  State<_ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends State<_ExamScreen>
    with SingleTickerProviderStateMixin {

  int _currentIndex = 0;

  // Map câu hỏi → đáp án đã chọn (null = chưa chọn)
  final Map<int, int> _selectedMap = {};

  // ── Tổng thời gian đếm ngược theo chuẩn CEFR ──────────
  // A1/A2: 45 phút | B1: 60 phút | B2: 75 phút | C1: 90 phút | C2: 105 phút
  late int _totalSecsLeft;
  int _elapsedSecs = 0;
  Timer? _timer;

  // Shake animation (khi chọn sai sau khi nộp)
  late final AnimationController _shakeCtrl;
  late final Animation<double> _shakeAnim;

  int get _totalSecs => (_kExamTimeMinutes[widget.level] ?? 60) * 60;
  int get _answeredCount => _selectedMap.length;

  String get _timeDisplay {
    final m = _totalSecsLeft ~/ 60;
    final s = _totalSecsLeft % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // Cảnh báo khi còn ≤ 5 phút
  bool get _isWarning => _totalSecsLeft <= 300;
  // Cảnh báo đỏ khi còn ≤ 1 phút
  bool get _isDanger  => _totalSecsLeft <= 60;

  @override
  void initState() {
    super.initState();
    _totalSecsLeft = _totalSecs;
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn),
    );
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _totalSecsLeft--;
        _elapsedSecs++;
      });
      if (_totalSecsLeft <= 0) {
        t.cancel();
        _onTimeUp();
      }
    });
  }

  void _onTimeUp() {
    HapticFeedback.heavyImpact();
    _finishExam(timeUp: true);
  }

  // Chọn / đổi đáp án — không auto-next, người dùng tự điều hướng
  void _onSelectAnswer(int idx) {
    setState(() => _selectedMap[_currentIndex] = idx);
    HapticFeedback.selectionClick();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.questions.length) return;
    setState(() => _currentIndex = index);
  }

  void _finishExam({bool timeUp = false}) {
    _timer?.cancel();
    final answers = <_UserAnswer>[];
    for (int i = 0; i < widget.questions.length; i++) {
      final sel = _selectedMap[i] ?? -1;
      final isCorrect = sel >= 0 && sel == widget.questions[i].correctIndex;
      answers.add(_UserAnswer(questionIndex: i, selectedIndex: sel, isCorrect: isCorrect));
    }
    _saveResult(answers);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => _ResultScreen(
          questions: widget.questions,
          answers: answers,
          level: widget.level,
          elapsedSecs: _elapsedSecs,
          timeUp: timeUp,
        ),
      ),
    );
  }

  Future<void> _saveResult(List<_UserAnswer> answers) async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final correct = answers.where((a) => a.isCorrect).length;
      final total   = widget.questions.length;
      final score   = (correct / total * 10).roundToDouble();
      final pct     = correct / total * 100;
      await FirebaseFirestore.instance.collection('study_history').add({
        'uid':            uid,
        'date':           Timestamp.now(),
        'wordsStudied':   total,
        'minutesStudied': (_elapsedSecs ~/ 60).clamp(1, 120),
        'activityType':   'cefr_test',
        'score':          score.round(),
        'level':          widget.level,
      });
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'lastTestScore': score.round(),
        'totalTests':    FieldValue.increment(1),
      });
      if (pct >= 50) await StreakService.recordLessonCompleted();
    } catch (_) {}
  }

  _SkillInfo get _currentSkill =>
      _kSkills.firstWhere((s) => s.id == widget.questions[_currentIndex].skill,
          orElse: () => _kSkills[0]);

  void _confirmSubmit(BuildContext context) {
    final unanswered = widget.questions.length - _answeredCount;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nộp bài?'),
        content: Text(
          unanswered > 0
              ? 'Bạn còn $unanswered câu chưa trả lời. Vẫn muốn nộp bài?'
              : 'Bạn đã trả lời tất cả ${widget.questions.length} câu. Xác nhận nộp bài?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tiếp tục làm'),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _finishExam(); },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF667eea)),
            child: const Text('Nộp bài', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmQuit(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thoát bài kiểm tra?'),
        content: const Text('Tiến độ sẽ không được lưu.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tiếp tục')),
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('Thoát', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final q = widget.questions[_currentIndex];
    final skill = _currentSkill;
    final selectedIdx = _selectedMap[_currentIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: skill.color,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => _confirmQuit(context),
        ),
        title: Text(
          '${skill.emoji} Câu ${_currentIndex + 1}/${widget.questions.length}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: r.sp(16),
          ),
        ),
        actions: [
          // Đồng hồ tổng MM:SS
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: _TotalTimerBadge(
                display: _timeDisplay,
                isWarning: _isWarning,
                isDanger: _isDanger,
              ),
            ),
          ),
          // Nút nộp bài
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: TextButton(
              onPressed: () => _confirmSubmit(context),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              child: Text(
                'Nộp bài',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: r.sp(13),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress bar tổng ──────────────────────────
          LinearProgressIndicator(
            value: _answeredCount / widget.questions.length,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(skill.color),
            minHeight: 4,
          ),

          // ── Skill section bar ──────────────────────────
          _SkillProgressBar(
            questions: widget.questions,
            currentIndex: _currentIndex,
          ),

          // ── Nội dung câu hỏi ──────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(r.hPad, r.w(14), r.hPad, r.w(100)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Instruction badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.w(12), vertical: r.w(6)),
                    decoration: BoxDecoration(
                      color: skill.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: skill.color.withOpacity(0.3)),
                    ),
                    child: Text(
                      q.instruction,
                      style: TextStyle(
                        color: skill.color,
                        fontSize: r.sp(12),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: r.w(12)),

                  // Passage (reading / listening)
                  if (q.passage != null && q.passage!.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.w(14)),
                      decoration: BoxDecoration(
                        color: skill.color.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(r.r(14)),
                        border: Border.all(color: skill.color.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(skill.emoji, style: const TextStyle(fontSize: 15)),
                              const SizedBox(width: 6),
                              Text(
                                q.skill == 'listening' ? 'Transcript' : 'Passage',
                                style: TextStyle(
                                  color: skill.color,
                                  fontWeight: FontWeight.w700,
                                  fontSize: r.sp(13),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: r.w(8)),
                          Text(
                            q.passage!,
                            style: TextStyle(
                              fontSize: r.sp(13),
                              color: const Color(0xFF4A5568),
                              height: 1.65,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: r.w(12)),
                  ],

                  // Question card
                  AnimatedBuilder(
                    animation: _shakeAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(sin(_shakeAnim.value * pi * 6) * 8, 0),
                      child: child,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(r.w(18)),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(r.r(18)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        q.questionText,
                        style: TextStyle(
                          fontSize: r.sp(17),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2D3748),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: r.w(16)),

                  // Options — chỉ highlight đáp án đã chọn, không hiện đúng/sai
                  ...q.options.asMap().entries.map((e) {
                    final idx    = e.key;
                    final text   = e.value;
                    final labels = ['A', 'B', 'C', 'D'];
                    final isSelected = selectedIdx == idx;
                    return Padding(
                      padding: EdgeInsets.only(bottom: r.w(10)),
                      child: _OptionButton(
                        label: labels[idx],
                        text: text,
                        state: isSelected ? _OptionState.selected : _OptionState.idle,
                        color: skill.color,
                        onTap: () => _onSelectAnswer(idx),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),

      // ── Bottom navigation bar ──────────────────────────
      bottomNavigationBar: _ExamNavBar(
        currentIndex: _currentIndex,
        total: widget.questions.length,
        selectedMap: _selectedMap,
        onPrev: () => _goTo(_currentIndex - 1),
        onNext: () => _goTo(_currentIndex + 1),
        onGoTo: _goTo,
        accentColor: skill.color,
      ),
    );
  }
}
// ─────────────────────────────────────────────────────────────────────────────
// RESULT SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _ResultScreen extends StatelessWidget {
  final List<_CefrQuestion> questions;
  final List<_UserAnswer> answers;
  final String level;
  final int elapsedSecs;
  final bool timeUp;

  const _ResultScreen({
    required this.questions,
    required this.answers,
    required this.level,
    required this.elapsedSecs,
    this.timeUp = false,
  });

  int get _correct => answers.where((a) => a.isCorrect).length;
  int get _total   => questions.length;
  double get _pct  => _correct / _total * 100;
  double get _score => (_correct / _total * 10);

  String get _gradeEmoji {
    if (_pct >= 90) return '🏆';
    if (_pct >= 80) return '🌟';
    if (_pct >= 70) return '👍';
    if (_pct >= 60) return '😊';
    if (_pct >= 50) return '💪';
    return '📚';
  }

  String get _gradeLabel {
    if (_pct >= 90) return 'A+';
    if (_pct >= 80) return 'A';
    if (_pct >= 70) return 'B';
    if (_pct >= 60) return 'C';
    if (_pct >= 50) return 'D';
    return 'F';
  }

  String get _feedback {
    if (_pct >= 90) return 'Xuất sắc! Bạn nắm vững cả 4 kỹ năng!';
    if (_pct >= 80) return 'Rất tốt! Chỉ cần ôn thêm một chút nữa!';
    if (_pct >= 70) return 'Khá tốt! Tiếp tục cố gắng nhé!';
    if (_pct >= 60) return 'Được rồi! Hãy ôn lại các kỹ năng còn yếu.';
    if (_pct >= 50) return 'Cần cố gắng thêm! Đừng nản lòng nhé.';
    return 'Hãy ôn tập lại từ đầu, bạn sẽ làm được!';
  }

  // Điểm theo từng kỹ năng
  Map<String, Map<String, int>> get _skillStats {
    final stats = <String, Map<String, int>>{};
    for (final s in _kSkills) {
      stats[s.id] = {'correct': 0, 'total': 0};
    }
    for (int i = 0; i < questions.length; i++) {
      final skill = questions[i].skill;
      stats[skill]!['total'] = (stats[skill]!['total'] ?? 0) + 1;
      if (i < answers.length && answers[i].isCorrect) {
        stats[skill]!['correct'] = (stats[skill]!['correct'] ?? 0) + 1;
      }
    }
    return stats;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final wrong = _total - _correct;
    final stats = _skillStats;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF667eea),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Kết quả — CEFR $level',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: r.sp(18)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(r.hPad),
        child: Column(
          children: [
            SizedBox(height: r.w(12)),

            // ── Score card ─────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(r.w(28)),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(r.r(24)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(_gradeEmoji, style: TextStyle(fontSize: r.sp(56))),
                  SizedBox(height: r.w(8)),
                  Text(
                    '${_score.toStringAsFixed(1)} / 10',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(42),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: r.w(4)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: r.w(16), vertical: r.w(6)),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Xếp loại $_gradeLabel • CEFR $level',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: r.sp(15),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(height: r.w(10)),
                  Text(
                    _feedback,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: r.sp(14),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.w(18)),

            // ── Hết giờ banner ─────────────────────────────
            if (timeUp)
              Container(
                width: double.infinity,
                margin: EdgeInsets.only(bottom: r.w(14)),
                padding: EdgeInsets.all(r.w(12)),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF4757).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Text('⏰', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hết giờ! Bài thi đã được tự động nộp.',
                        style: TextStyle(
                          color: const Color(0xFFFF4757),
                          fontWeight: FontWeight.w600,
                          fontSize: r.sp(13),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Overall stats ──────────────────────────────
            Row(
              children: [
                Expanded(child: _StatTile(emoji: '✅', label: 'Đúng', value: '$_correct', color: const Color(0xFF06D6A0))),
                SizedBox(width: r.w(8)),
                Expanded(child: _StatTile(emoji: '❌', label: 'Sai', value: '$wrong', color: const Color(0xFFFF4757))),
                SizedBox(width: r.w(8)),
                Expanded(child: _StatTile(emoji: '📊', label: 'Tỉ lệ', value: '${_pct.round()}%', color: const Color(0xFF667eea))),
                SizedBox(width: r.w(8)),
                Expanded(child: _StatTile(emoji: '⏱️', label: 'Thời gian', value: '${elapsedSecs ~/ 60}p${(elapsedSecs % 60).toString().padLeft(2, "0")}s', color: const Color(0xFFFF9F1C))),
              ],
            ),
            SizedBox(height: r.w(20)),

            // ── Skill breakdown ────────────────────────────
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kết quả theo kỹ năng',
                style: TextStyle(
                  fontSize: r.sp(16),
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ),
            SizedBox(height: r.w(12)),
            ..._kSkills.map((s) {
              final st = stats[s.id]!;
              final c  = st['correct']!;
              final t  = st['total']!;
              final p  = t > 0 ? c / t : 0.0;
              return Padding(
                padding: EdgeInsets.only(bottom: r.w(10)),
                child: _SkillResultCard(skill: s, correct: c, total: t, percentage: p),
              );
            }),
            SizedBox(height: r.w(20)),

            // ── Wrong answers review ───────────────────────
            if (_correct < _total) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Xem lại câu sai (${_total - _correct} câu)',
                  style: TextStyle(
                    fontSize: r.sp(16),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2D3748),
                  ),
                ),
              ),
              SizedBox(height: r.w(12)),
              ...answers.where((a) => !a.isCorrect).map((a) {
                final q = questions[a.questionIndex];
                return Padding(
                  padding: EdgeInsets.only(bottom: r.w(10)),
                  child: _WrongAnswerCard(question: q, answer: a),
                );
              }),
              SizedBox(height: r.w(16)),
            ],

            // ── Action buttons ─────────────────────────────
            SizedBox(
              width: double.infinity,
              height: r.w(52),
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.r(14))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🔄', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text('Làm đề mới', style: TextStyle(fontSize: r.sp(16), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            SizedBox(height: r.w(10)),
            SizedBox(
              width: double.infinity,
              height: r.w(52),
              child: OutlinedButton(
                onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF667eea),
                  side: const BorderSide(color: Color(0xFF667eea), width: 2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.r(14))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('🏠', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Text('Về trang chủ', style: TextStyle(fontSize: r.sp(16), fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
            SizedBox(height: r.w(24)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

enum _OptionState { idle, selected, correct, wrong }

// ── Skill card (setup screen) ─────────────────────────
class _SkillCard extends StatelessWidget {
  final _SkillInfo skill;
  const _SkillCard({required this.skill});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [skill.color, skill.color.withOpacity(0.7)],
        ),
        borderRadius: BorderRadius.circular(r.r(16)),
        boxShadow: [
          BoxShadow(
            color: skill.color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(r.w(14)),
        child: Row(
          children: [
            Text(skill.emoji, style: TextStyle(fontSize: r.sp(28))),
            SizedBox(width: r.w(10)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    skill.label,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: r.sp(14),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '5 câu',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: r.sp(12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Level chip ────────────────────────────────────────
class _LevelChip extends StatelessWidget {
  final String level;
  final bool selected;
  final VoidCallback onTap;
  const _LevelChip({required this.level, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: r.w(18), vertical: r.w(10)),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF667eea) : Colors.white,
          borderRadius: BorderRadius.circular(r.r(12)),
          border: Border.all(
            color: selected ? const Color(0xFF667eea) : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: selected
              ? [BoxShadow(color: const Color(0xFF667eea).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
              : [],
        ),
        child: Text(
          level,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF4A5568),
            fontWeight: FontWeight.w700,
            fontSize: r.sp(15),
          ),
        ),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────
class _InfoCard extends StatelessWidget {
  final String level;
  const _InfoCard({required this.level});

  String get _desc {
    switch (level) {
      case 'A1': return 'Sơ cấp — Từ vựng và ngữ pháp cơ bản nhất';
      case 'A2': return 'Sơ cấp nâng cao — Giao tiếp hàng ngày đơn giản';
      case 'B1': return 'Trung cấp — Hiểu các chủ đề quen thuộc';
      case 'B2': return 'Trung cấp nâng cao — Giao tiếp tự nhiên, trôi chảy';
      case 'C1': return 'Cao cấp — Sử dụng ngôn ngữ linh hoạt, hiệu quả';
      case 'C2': return 'Thành thạo — Gần như người bản ngữ';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Container(
      padding: EdgeInsets.all(r.w(16)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.r(16)),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: r.w(48),
            height: r.w(48),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                level,
                style: TextStyle(
                  color: const Color(0xFF667eea),
                  fontWeight: FontWeight.w900,
                  fontSize: r.sp(16),
                ),
              ),
            ),
          ),
          SizedBox(width: r.w(14)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '20 câu • 4 kỹ năng •  phút',
                  style: TextStyle(
                    fontSize: r.sp(13),
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                SizedBox(height: r.w(3)),
                Text(
                  _desc,
                  style: TextStyle(fontSize: r.sp(12), color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Skill progress bar (exam screen) ─────────────────
class _SkillProgressBar extends StatelessWidget {
  final List<_CefrQuestion> questions;
  final int currentIndex;
  const _SkillProgressBar({required this.questions, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: r.hPad, vertical: r.w(8)),
      child: Row(
        children: _kSkills.map((s) {
          final firstIdx = questions.indexWhere((q) => q.skill == s.id);
          final lastIdx  = questions.lastIndexWhere((q) => q.skill == s.id);
          final isActive = currentIndex >= firstIdx && currentIndex <= lastIdx;
          final isDone   = currentIndex > lastIdx;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.w(3)),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDone
                          ? s.color
                          : isActive
                              ? s.color.withOpacity(0.5)
                              : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: r.w(3)),
                  Text(
                    s.emoji,
                    style: TextStyle(
                      fontSize: r.sp(isActive ? 14 : 11),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Option button ─────────────────────────────────────
class _OptionButton extends StatelessWidget {
  final String label;
  final String text;
  final _OptionState state;
  final Color color;
  final VoidCallback onTap;
  const _OptionButton({required this.label, required this.text, required this.state, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    Color bg, border, textColor, labelBg;
    switch (state) {
      case _OptionState.selected:
        bg = color.withOpacity(0.1);
        border = color;
        textColor = color;
        labelBg = color;
        break;
      case _OptionState.correct:
        bg = const Color(0xFF06D6A0).withOpacity(0.12);
        border = const Color(0xFF06D6A0);
        textColor = const Color(0xFF00A878);
        labelBg = const Color(0xFF06D6A0);
        break;
      case _OptionState.wrong:
        bg = const Color(0xFFFF4757).withOpacity(0.12);
        border = const Color(0xFFFF4757);
        textColor = const Color(0xFFFF4757);
        labelBg = const Color(0xFFFF4757);
        break;
      case _OptionState.idle:
        bg = Colors.white;
        border = Colors.grey.shade200;
        textColor = const Color(0xFF2D3748);
        labelBg = color.withOpacity(0.12);
        break;
    }
    return GestureDetector(
      onTap: (state == _OptionState.idle || state == _OptionState.selected) ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: EdgeInsets.symmetric(horizontal: r.w(14), vertical: r.w(14)),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(r.r(14)),
          border: Border.all(color: border, width: 1.5),
          boxShadow: (state == _OptionState.idle || state == _OptionState.selected)
              ? [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        child: Row(
          children: [
            Container(
              width: r.w(32), height: r.w(32),
              decoration: BoxDecoration(
                color: (state == _OptionState.idle || state == _OptionState.selected) ? labelBg : (state == _OptionState.correct ? const Color(0xFF06D6A0) : const Color(0xFFFF4757)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: (state == _OptionState.idle || state == _OptionState.selected) ? color : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: r.sp(14),
                  ),
                ),
              ),
            ),
            SizedBox(width: r.w(12)),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  color: textColor,
                  fontSize: r.sp(14),
                  fontWeight: (state == _OptionState.selected || state == _OptionState.correct || state == _OptionState.wrong) ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
            if (state == _OptionState.correct)
              const Icon(Icons.check_circle, color: Color(0xFF06D6A0), size: 20),
            if (state == _OptionState.wrong)
              const Icon(Icons.cancel, color: Color(0xFFFF4757), size: 20),
          ],
        ),
      ),
    );
  }
}


// ── Total timer badge (MM:SS) ─────────────────────────
class _TotalTimerBadge extends StatelessWidget {
  final String display;
  final bool isWarning;
  final bool isDanger;
  const _TotalTimerBadge({
    required this.display,
    required this.isWarning,
    required this.isDanger,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDanger
        ? const Color(0xFFFF4757)
        : isWarning
            ? const Color(0xFFFFBE0B)
            : Colors.white;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: isDanger
            ? const Color(0xFFFF4757).withOpacity(0.25)
            : Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: isDanger
            ? Border.all(color: const Color(0xFFFF4757), width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isDanger ? Icons.timer_off : Icons.timer,
            color: color,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            display,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Exam navigation bar ───────────────────────────────
// Hiển thị: [← Trước] [grid câu] [Sau →]
class _ExamNavBar extends StatelessWidget {
  final int currentIndex;
  final int total;
  final Map<int, int> selectedMap;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final void Function(int) onGoTo;
  final Color accentColor;

  const _ExamNavBar({
    required this.currentIndex,
    required this.total,
    required this.selectedMap,
    required this.onPrev,
    required this.onNext,
    required this.onGoTo,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.hPad, vertical: r.w(10)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Question number grid
              SizedBox(
                height: r.w(36),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: total,
                  itemBuilder: (_, i) {
                    final isAnswered = selectedMap.containsKey(i);
                    final isCurrent  = i == currentIndex;
                    return GestureDetector(
                      onTap: () => onGoTo(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: r.w(32),
                        height: r.w(32),
                        margin: EdgeInsets.only(right: r.w(6)),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? accentColor
                              : isAnswered
                                  ? accentColor.withOpacity(0.15)
                                  : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: isCurrent
                              ? null
                              : isAnswered
                                  ? Border.all(color: accentColor.withOpacity(0.4))
                                  : Border.all(color: Colors.grey.shade300),
                        ),
                        child: Center(
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: r.sp(11),
                              fontWeight: FontWeight.w700,
                              color: isCurrent
                                  ? Colors.white
                                  : isAnswered
                                      ? accentColor
                                      : Colors.grey.shade500,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: r.w(10)),
              // Prev / Next buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: currentIndex > 0 ? onPrev : null,
                      icon: const Icon(Icons.arrow_back_ios, size: 14),
                      label: const Text('Trước'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accentColor,
                        side: BorderSide(color: accentColor.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: r.w(10)),
                      ),
                    ),
                  ),
                  SizedBox(width: r.w(12)),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: currentIndex < total - 1 ? onNext : null,
                      icon: const Text('Sau'),
                      label: const Icon(Icons.arrow_forward_ios, size: 14),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.symmetric(vertical: r.w(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat tile ─────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String emoji;
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.emoji, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: r.w(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.r(14)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Text(emoji, style: TextStyle(fontSize: r.sp(22))),
          SizedBox(height: r.w(4)),
          Text(value, style: TextStyle(fontSize: r.sp(20), fontWeight: FontWeight.w800, color: color)),
          SizedBox(height: r.w(2)),
          Text(label, style: TextStyle(fontSize: r.sp(11), color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

// ── Skill result card ─────────────────────────────────
class _SkillResultCard extends StatelessWidget {
  final _SkillInfo skill;
  final int correct;
  final int total;
  final double percentage;
  const _SkillResultCard({required this.skill, required this.correct, required this.total, required this.percentage});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Container(
      padding: EdgeInsets.all(r.w(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.r(14)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(skill.emoji, style: TextStyle(fontSize: r.sp(22))),
              SizedBox(width: r.w(10)),
              Expanded(
                child: Text(
                  skill.label,
                  style: TextStyle(fontSize: r.sp(15), fontWeight: FontWeight.w700, color: const Color(0xFF2D3748)),
                ),
              ),
              Text(
                '$correct/$total',
                style: TextStyle(fontSize: r.sp(15), fontWeight: FontWeight.w700, color: skill.color),
              ),
              SizedBox(width: r.w(8)),
              Text(
                '${(percentage * 100).round()}%',
                style: TextStyle(fontSize: r.sp(13), color: Colors.grey.shade600),
              ),
            ],
          ),
          SizedBox(height: r.w(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(skill.color),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Wrong answer card ─────────────────────────────────
class _WrongAnswerCard extends StatelessWidget {
  final _CefrQuestion question;
  final _UserAnswer answer;
  const _WrongAnswerCard({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final skill = _kSkills.firstWhere((s) => s.id == question.skill, orElse: () => _kSkills[0]);
    final selectedText = answer.selectedIndex >= 0 && answer.selectedIndex < question.options.length
        ? question.options[answer.selectedIndex]
        : null;

    return Container(
      padding: EdgeInsets.all(r.w(14)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.r(14)),
        border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.25)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Skill badge + question number
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: r.w(8), vertical: r.w(3)),
                decoration: BoxDecoration(
                  color: skill.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${skill.emoji} ${skill.label} • Câu ${question.number}',
                  style: TextStyle(fontSize: r.sp(11), color: skill.color, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          SizedBox(height: r.w(8)),
          Text(
            question.questionText,
            style: TextStyle(fontSize: r.sp(14), fontWeight: FontWeight.w600, color: const Color(0xFF2D3748)),
          ),
          SizedBox(height: r.w(8)),
          if (selectedText != null)
            Row(
              children: [
                const Icon(Icons.cancel, color: Color(0xFFFF4757), size: 15),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Bạn chọn: $selectedText',
                    style: TextStyle(fontSize: r.sp(13), color: const Color(0xFFFF4757)),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                const Icon(Icons.timer_off, color: Color(0xFFFF4757), size: 15),
                const SizedBox(width: 5),
                Text('Hết giờ', style: TextStyle(fontSize: r.sp(13), color: const Color(0xFFFF4757))),
              ],
            ),
          SizedBox(height: r.w(4)),
          Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF06D6A0), size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Đáp án đúng: ${question.correctAnswer}',
                  style: TextStyle(fontSize: r.sp(13), color: const Color(0xFF06D6A0), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (question.explanation.isNotEmpty) ...[
            SizedBox(height: r.w(6)),
            Text(
              '💡 ${question.explanation}',
              style: TextStyle(fontSize: r.sp(12), color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}








