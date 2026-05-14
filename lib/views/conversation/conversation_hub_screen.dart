import 'package:flutter/material.dart';
import '../../data/services/conversation_service.dart';
import 'conversation_screen.dart';

/// 🎤 Conversation Hub — chọn scenario để luyện hội thoại
class ConversationHubScreen extends StatelessWidget {
  const ConversationHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: const Color(0xFF667eea),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('🎤 Luyện Hội Thoại AI',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 8),
                        Text(
                          'Chọn tình huống và luyện nói tiếng Anh với AI',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        SizedBox(height: 12),
                        _InfoChips(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),
                _SectionHeader('🌟 Tình huống phổ biến'),
                const SizedBox(height: 12),
                ...ConversationService.scenarios
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ScenarioCard(
                            scenario: s,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ConversationScreen(scenario: s),
                              ),
                            ),
                          ),
                        ))
                    .toList(),
                const SizedBox(height: 16),
                _TipsCard(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoChips extends StatelessWidget {
  const _InfoChips();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Chip('🤖 AI đóng vai'),
        const SizedBox(width: 8),
        _Chip('🎙️ Nói hoặc gõ'),
        const SizedBox(width: 8),
        _Chip('📊 Báo cáo chi tiết'),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 11)),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF667eea),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF333333))),
      ],
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  final ConversationScenario scenario;
  final VoidCallback onTap;
  const _ScenarioCard({required this.scenario, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = Color(scenario.color);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Emoji icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(scenario.emoji,
                      style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(scenario.title,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _diffColor(scenario.difficulty)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            scenario.difficulty,
                            style: TextStyle(
                                fontSize: 10,
                                color: _diffColor(scenario.difficulty),
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(scenario.description,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                    const SizedBox(height: 8),
                    Text('AI đóng vai: ${scenario.aiRoleVi}',
                        style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 4,
                      children: scenario.targetVocab
                          .take(3)
                          .map((v) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(v,
                                    style: TextStyle(
                                        fontSize: 10, color: color)),
                              ))
                          .toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _diffColor(String diff) {
    switch (diff) {
      case 'Beginner':
        return const Color(0xFF06D6A0);
      case 'Intermediate':
        return const Color(0xFFFFB347);
      case 'Advanced':
        return const Color(0xFFFF4757);
      default:
        return Colors.grey;
    }
  }
}

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          const Text('💡 Mẹo luyện tập',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 10),
          ...[
            '🎙️ Dùng nút mic để nói, AI sẽ nhận diện giọng nói',
            '📝 Hoặc gõ text nếu không có mic',
            '🔄 Thử nhiều lần để cải thiện điểm số',
            '📊 Xem báo cáo sau mỗi buổi để biết điểm yếu',
          ].map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(tip,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              )),
        ],
      ),
    );
  }
}
