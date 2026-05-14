import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// 🗺️ Tính năng 6: Vocabulary Map — Bản đồ từ vựng trực quan
/// Hiển thị word cloud / mind map theo chủ đề, màu theo độ thành thạo
class VocabMapScreen extends StatefulWidget {
  const VocabMapScreen({super.key});

  @override
  State<VocabMapScreen> createState() => _VocabMapScreenState();
}

class _VocabMapScreenState extends State<VocabMapScreen>
    with SingleTickerProviderStateMixin {
  List<VocabNode> _nodes = [];
  bool _loading = true;
  String _filterTopic = 'Tất cả';
  List<String> _topics = ['Tất cả'];
  VocabNode? _selected;
  late AnimationController _floatCtrl;

  @override
  void initState() {
    super.initState();
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _loadVocab();
  }

  @override
  void dispose() {
    _floatCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVocab() async {
    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final learnedSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learned_words')
          .get();

      final progressSnap = await FirebaseFirestore.instance
          .collection('vocabulary_progress')
          .where('uid', isEqualTo: uid)
          .get();

      // Map wordId -> strength
      final strengthMap = <String, double>{};
      for (final doc in progressSnap.docs) {
        final d = doc.data();
        strengthMap[d['wordId'] as String? ?? ''] =
            (d['strength'] as num? ?? 0.5).toDouble();
      }

      final nodes = <VocabNode>[];
      final topicSet = <String>{'Tất cả'};
      final rng = math.Random(42);

      for (final doc in learnedSnap.docs) {
        final d = doc.data();
        final wordId = d['wordId'] as String? ?? '';
        final topic = d['topicName'] as String? ?? 'Khác';
        topicSet.add(topic);
        nodes.add(VocabNode(
          word: d['word'] as String? ?? '',
          meaning: d['meaning'] as String? ?? '',
          phonetic: d['phonetic'] as String? ?? '',
          topic: topic,
          topicEmoji: d['topicEmoji'] as String? ?? '📚',
          strength: strengthMap[wordId] ?? 0.5,
          // Random position trong canvas
          x: 0.05 + rng.nextDouble() * 0.9,
          y: 0.05 + rng.nextDouble() * 0.9,
          size: 12.0 + (strengthMap[wordId] ?? 0.5) * 16,
        ));
      }

      if (mounted) {
        setState(() {
          _nodes = nodes;
          _topics = topicSet.toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<VocabNode> get _filteredNodes => _filterTopic == 'Tất cả'
      ? _nodes
      : _nodes.where((n) => n.topic == _filterTopic).toList();

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
          '🗺️ Bản đồ từ vựng',
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_filteredNodes.length} từ',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF667eea)))
          : _nodes.isEmpty
              ? _buildEmpty()
              : Column(
                  children: [
                    // Topic filter
                    _TopicFilter(
                      topics: _topics,
                      selected: _filterTopic,
                      onSelect: (t) =>
                          setState(() {
                            _filterTopic = t;
                            _selected = null;
                          }),
                    ),
                    // Legend
                    _Legend(),
                    // Word cloud canvas
                    Expanded(
                      child: Stack(
                        children: [
                          _WordCloud(
                            nodes: _filteredNodes,
                            floatCtrl: _floatCtrl,
                            onTap: (n) =>
                                setState(() => _selected = _selected?.word == n.word ? null : n),
                          ),
                          // Selected word popup
                          if (_selected != null)
                            Positioned(
                              bottom: 20,
                              left: 20,
                              right: 20,
                              child: _NodeDetail(node: _selected!),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmpty() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🗺️', style: TextStyle(fontSize: 64)),
          SizedBox(height: 16),
          Text(
            'Học thêm từ vựng để xem bản đồ!',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ─── Topic Filter ─────────────────────────────────────────────────────────────

class _TopicFilter extends StatelessWidget {
  final List<String> topics;
  final String selected;
  final ValueChanged<String> onSelect;

  const _TopicFilter({
    required this.topics,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: topics.length,
        itemBuilder: (_, i) {
          final t = topics[i];
          final isSelected = t == selected;
          return GestureDetector(
            onTap: () => onSelect(t),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF667eea)
                    : Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF667eea)
                      : Colors.white.withOpacity(0.15),
                ),
              ),
              child: Text(
                t,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 12,
                  fontWeight: isSelected
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Legend ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          const Text('Độ thành thạo: ',
              style: TextStyle(color: Colors.white38, fontSize: 11)),
          _LegendDot(color: const Color(0xFFFF4757), label: 'Mới'),
          const SizedBox(width: 10),
          _LegendDot(color: const Color(0xFFFFB347), label: 'Đang học'),
          const SizedBox(width: 10),
          _LegendDot(color: const Color(0xFF06D6A0), label: 'Thuộc'),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ],
    );
  }
}

// ─── Word Cloud Canvas ────────────────────────────────────────────────────────

class _WordCloud extends StatelessWidget {
  final List<VocabNode> nodes;
  final AnimationController floatCtrl;
  final ValueChanged<VocabNode> onTap;

  const _WordCloud({
    required this.nodes,
    required this.floatCtrl,
    required this.onTap,
  });

  Color _strengthColor(double s) {
    if (s >= 0.8) return const Color(0xFF06D6A0);
    if (s >= 0.5) return const Color(0xFFFFB347);
    return const Color(0xFFFF4757);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: floatCtrl,
      builder: (_, __) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final h = constraints.maxHeight;
            return GestureDetector(
              onTapDown: (details) {
                // Tìm node gần nhất với tap
                final pos = details.localPosition;
                for (final node in nodes) {
                  final nx = node.x * w;
                  final ny = node.y * h;
                  final dist = math.sqrt(
                      math.pow(pos.dx - nx, 2) + math.pow(pos.dy - ny, 2));
                  if (dist < node.size + 8) {
                    onTap(node);
                    return;
                  }
                }
              },
              child: CustomPaint(
                size: Size(w, h),
                painter: _WordCloudPainter(
                  nodes: nodes,
                  floatValue: floatCtrl.value,
                  strengthColor: _strengthColor,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _WordCloudPainter extends CustomPainter {
  final List<VocabNode> nodes;
  final double floatValue;
  final Color Function(double) strengthColor;

  const _WordCloudPainter({
    required this.nodes,
    required this.floatValue,
    required this.strengthColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(0);
    for (int i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      final color = strengthColor(node.strength);
      final floatOffset = math.sin(floatValue * math.pi * 2 + i * 0.7) * 3;

      final x = node.x * size.width;
      final y = node.y * size.height + floatOffset;

      // Glow
      final glowPaint = Paint()
        ..color = color.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawCircle(Offset(x, y), node.size + 4, glowPaint);

      // Circle
      final circlePaint = Paint()
        ..color = color.withOpacity(0.2)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), node.size, circlePaint);

      // Border
      final borderPaint = Paint()
        ..color = color.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(Offset(x, y), node.size, borderPaint);

      // Text
      final textPainter = TextPainter(
        text: TextSpan(
          text: node.word,
          style: TextStyle(
            color: color,
            fontSize: node.size * 0.55,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: node.size * 2.5);
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_WordCloudPainter old) =>
      old.floatValue != floatValue || old.nodes != nodes;
}

// ─── Node Detail ──────────────────────────────────────────────────────────────

class _NodeDetail extends StatelessWidget {
  final VocabNode node;
  const _NodeDetail({required this.node});

  Color get _color {
    if (node.strength >= 0.8) return const Color(0xFF06D6A0);
    if (node.strength >= 0.5) return const Color(0xFFFFB347);
    return const Color(0xFFFF4757);
  }

  String get _strengthLabel {
    if (node.strength >= 0.8) return 'Thuộc lòng ⭐';
    if (node.strength >= 0.5) return 'Đang học 📖';
    return 'Mới học 🌱';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _color.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
              color: _color.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Text(node.topicEmoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      node.word,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 8),
                    if (node.phonetic.isNotEmpty)
                      Text(
                        node.phonetic,
                        style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  node.meaning,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _color.withOpacity(0.3)),
            ),
            child: Text(
              _strengthLabel,
              style: TextStyle(
                  color: _color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Model ────────────────────────────────────────────────────────────────────

class VocabNode {
  final String word, meaning, phonetic, topic, topicEmoji;
  final double strength, x, y, size;

  const VocabNode({
    required this.word,
    required this.meaning,
    required this.phonetic,
    required this.topic,
    required this.topicEmoji,
    required this.strength,
    required this.x,
    required this.y,
    required this.size,
  });
}
