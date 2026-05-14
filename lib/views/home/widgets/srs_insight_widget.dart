import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/services/smart_srs_service.dart';

/// 🧠 Widget hiển thị AI SRS Insight trên home screen
/// Phân tích pattern sai và gợi ý cải thiện
class SrsInsightWidget extends StatefulWidget {
  const SrsInsightWidget({super.key});

  @override
  State<SrsInsightWidget> createState() => _SrsInsightWidgetState();
}

class _SrsInsightWidgetState extends State<SrsInsightWidget> {
  SrsInsight? _insight;
  SrsStats _stats = SrsStats.empty;
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final stats = await SmartSrsService.getStats();
    final insight = await SmartSrsService.analyzeWeakWords();
    if (mounted) {
      setState(() {
        _stats = stats;
        _insight = insight;
        _loading = false;
      });
    }
  }

  Future<void> _applyFix() async {
    if (_insight == null) return;
    await SmartSrsService.adjustIntervalForWeakWords(_insight!.weakWords);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '✅ Đã đặt lại lịch ôn cho ${_insight!.weakWords.length} từ yếu'),
          backgroundColor: const Color(0xFF06D6A0),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        height: 60,
        child: Center(
          child: CircularProgressIndicator(
              color: Color(0xFF667eea), strokeWidth: 2),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(_expanded ? 0 : 20),
                  bottomRight: Radius.circular(_expanded ? 0 : 20),
                ),
              ),
              child: Row(
                children: [
                  const Text('🧠', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI SRS Insight',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14),
                        ),
                        Text(
                          'Phân tích điểm yếu & gợi ý cải thiện',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
          ),

          // Stats row (always visible)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _StatChip(
                    emoji: '⭐',
                    value: '${_stats.mastered}',
                    label: 'Thuộc',
                    color: const Color(0xFF06D6A0)),
                const SizedBox(width: 8),
                _StatChip(
                    emoji: '📖',
                    value: '${_stats.learning}',
                    label: 'Đang học',
                    color: const Color(0xFFFFB347)),
                const SizedBox(width: 8),
                _StatChip(
                    emoji: '🔔',
                    value: '${_stats.dueToday}',
                    label: 'Cần ôn',
                    color: const Color(0xFFFF4757)),
              ],
            ),
          ),

          // Expanded insight
          if (_expanded) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            if (_insight == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('🐱', style: TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    const Text(
                      'Chưa có đủ dữ liệu để phân tích',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF444444)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hãy ôn tập thêm để Meow phân tích điểm yếu của bạn nhé!',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Pattern
                  if (_insight!.pattern.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('📊 ',
                            style: TextStyle(fontSize: 14)),
                        Expanded(
                          child: Text(
                            _insight!.pattern,
                            style: const TextStyle(
                                fontSize: 13, color: Color(0xFF444444)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Confused pairs
                  if (_insight!.confusedPairs.isNotEmpty) ...[
                    const Text(
                      '🔀 Hay nhầm lẫn:',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey),
                    ),
                    const SizedBox(height: 6),
                    ..._insight!.confusedPairs.take(3).map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '"${p.word1}" vs "${p.word2}"',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF8C00)),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '— ${p.reason}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 8),
                  ],

                  // Tip
                  if (_insight!.tip.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('💡 ',
                              style: TextStyle(fontSize: 14)),
                          Expanded(
                            child: Text(
                              _insight!.tip,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF667eea)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Fix button
                  if (_insight!.weakWords.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _applyFix,
                        icon: const Icon(Icons.auto_fix_high_rounded,
                            size: 16),
                        label: Text(
                            'Ôn lại ${_insight!.weakWords.length} từ yếu ngay'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
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

class _StatChip extends StatelessWidget {
  final String emoji, value, label;
  final Color color;

  const _StatChip({
    required this.emoji,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w800),
            ),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
