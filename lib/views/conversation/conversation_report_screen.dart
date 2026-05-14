import 'package:flutter/material.dart';
import '../../data/services/conversation_service.dart';

/// 📊 Conversation Report Screen — báo cáo sau buổi hội thoại
class ConversationReportScreen extends StatelessWidget {
  final ConversationScenario scenario;
  final ConversationReport report;
  final int turnCount;

  const ConversationReportScreen({
    super.key,
    required this.scenario,
    required this.report,
    required this.turnCount,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(scenario.color);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        title: const Text('📊 Báo cáo hội thoại',
            style: TextStyle(fontWeight: FontWeight.w700)),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Overall score card
            _OverallCard(
              scenario: scenario,
              report: report,
              turnCount: turnCount,
              color: color,
            ),
            const SizedBox(height: 16),

            // Score breakdown
            _ScoreBreakdown(report: report),
            const SizedBox(height: 16),

            // Vocabulary used
            _VocabCard(report: report, color: color),
            const SizedBox(height: 16),

            // Feedback
            _FeedbackCard(report: report),
            const SizedBox(height: 16),

            // Suggestions
            if (report.suggestions.isNotEmpty) _SuggestionsCard(report: report),
            const SizedBox(height: 24),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Chọn tình huống khác'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: color,
                      side: BorderSide(color: color),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ConversationReportScreen(
                            scenario: scenario,
                            report: report,
                            turnCount: turnCount,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Thử lại'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─── Overall Card ─────────────────────────────────────────────────────────────

class _OverallCard extends StatelessWidget {
  final ConversationScenario scenario;
  final ConversationReport report;
  final int turnCount;
  final Color color;
  const _OverallCard({
    required this.scenario,
    required this.report,
    required this.turnCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Text(scenario.emoji, style: const TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(scenario.title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            '${report.overallScore}',
            style: const TextStyle(
                color: Colors.white,
                fontSize: 64,
                fontWeight: FontWeight.w900),
          ),
          Text('/ 100',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.7), fontSize: 16)),
          const SizedBox(height: 8),
          Text(_scoreLabel(report.overallScore),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StatChip('💬 $turnCount lượt'),
              const SizedBox(width: 12),
              _StatChip(
                  '✅ ${report.usedTargetVocab.length}/${scenario.targetVocab.length} từ mục tiêu'),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.summary,
            style: TextStyle(
                color: Colors.white.withOpacity(0.85), fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _scoreLabel(int score) {
    if (score >= 90) return '🌟 Xuất sắc!';
    if (score >= 75) return '👍 Tốt lắm!';
    if (score >= 60) return '😊 Khá ổn!';
    if (score >= 40) return '💪 Cần cải thiện';
    return '🔄 Hãy thử lại!';
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  const _StatChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}

// ─── Score Breakdown ──────────────────────────────────────────────────────────

class _ScoreBreakdown extends StatelessWidget {
  final ConversationReport report;
  const _ScoreBreakdown({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📈 Điểm chi tiết',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          _ScoreBar('📝 Ngữ pháp', report.grammarScore,
              const Color(0xFF667eea)),
          const SizedBox(height: 12),
          _ScoreBar('📚 Từ vựng', report.vocabularyScore,
              const Color(0xFF06D6A0)),
          const SizedBox(height: 12),
          _ScoreBar('🗣️ Lưu loát', report.fluencyScore,
              const Color(0xFFFFB347)),
        ],
      ),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  final String label;
  final int score;
  final Color color;
  const _ScoreBar(this.label, this.score, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            Text('$score/100',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: score / 100,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}

// ─── Vocab Card ───────────────────────────────────────────────────────────────

class _VocabCard extends StatelessWidget {
  final ConversationReport report;
  final Color color;
  const _VocabCard({required this.report, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🎯 Từ vựng mục tiêu',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          if (report.usedTargetVocab.isNotEmpty) ...[
            Text('✅ Đã dùng:',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: report.usedTargetVocab
                  .map((v) => _VocabChip(v, Colors.green))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (report.missedVocab.isNotEmpty) ...[
            Text('❌ Chưa dùng:',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: report.missedVocab
                  .map((v) => _VocabChip(v, Colors.orange))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _VocabChip extends StatelessWidget {
  final String word;
  final Color color;
  const _VocabChip(this.word, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(word,
          style: TextStyle(
              fontSize: 12, color: color, fontWeight: FontWeight.w500)),
    );
  }
}

// ─── Feedback Card ────────────────────────────────────────────────────────────

class _FeedbackCard extends StatelessWidget {
  final ConversationReport report;
  const _FeedbackCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💬 Nhận xét chi tiết',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _FeedbackRow('📝 Ngữ pháp', report.grammarFeedback,
              const Color(0xFF667eea)),
          const Divider(height: 20),
          _FeedbackRow('📚 Từ vựng', report.vocabularyFeedback,
              const Color(0xFF06D6A0)),
          const Divider(height: 20),
          _FeedbackRow('🗣️ Lưu loát', report.fluencyFeedback,
              const Color(0xFFFFB347)),
        ],
      ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  final String title;
  final String feedback;
  final Color color;
  const _FeedbackRow(this.title, this.feedback, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
        const SizedBox(height: 4),
        Text(feedback,
            style: TextStyle(
                fontSize: 13, color: Colors.grey.shade700, height: 1.5)),
      ],
    );
  }
}

// ─── Suggestions Card ─────────────────────────────────────────────────────────

class _SuggestionsCard extends StatelessWidget {
  final ConversationReport report;
  const _SuggestionsCard({required this.report});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡 Gợi ý cải thiện',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 12),
          ...report.suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('→ ',
                        style: TextStyle(
                            color: Colors.white70, fontSize: 13)),
                    Expanded(
                      child: Text(s,
                          style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
