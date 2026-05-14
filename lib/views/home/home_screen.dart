import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vocabodemo/views/add/add_screen.dart';
import 'package:vocabodemo/views/calendar/CalendarScreen.dart';
import 'package:vocabodemo/views/notification/notification_screen.dart';
import 'package:vocabodemo/views/settings/setting_screen.dart';
import 'package:vocabodemo/views/review/ReviewScreen.dart';
import 'package:vocabodemo/views/test/TestScreen.dart';
import 'package:vocabodemo/views/flashcard/flashcard_screen.dart';
import 'package:vocabodemo/views/grammar/grammar_screen.dart';
import 'package:vocabodemo/AI/ai_chat_bubble.dart';
import 'package:vocabodemo/views/home/widgets/achievement_card.dart';
import 'package:vocabodemo/data/services/weekly_chart_firestore.dart';
import 'package:vocabodemo/views/home/widgets/search_box.dart';
import 'package:vocabodemo/views/home/widgets/learning_path.dart';
import 'package:vocabodemo/views/checkin/checkin_bubble.dart';
import 'package:vocabodemo/data/services/currency_service.dart';
import 'package:vocabodemo/data/services/streak_service.dart';
import 'package:vocabodemo/data/services/chat_service.dart';
import 'package:vocabodemo/data/services/friend_service.dart';
import 'package:vocabodemo/data/services/game_service.dart';
import 'package:vocabodemo/views/friends/chat_list_screen.dart';
import 'package:vocabodemo/views/games/games_hub_screen.dart';
import 'package:vocabodemo/views/house/house_screen.dart';
import 'package:vocabodemo/views/character/character_creator_screen.dart';
import 'package:vocabodemo/data/services/character_service.dart';
import 'package:vocabodemo/data/models/character_model.dart';
import 'package:vocabodemo/views/character/character_widget.dart';
import 'package:vocabodemo/data/services/house_service.dart';
import 'package:vocabodemo/data/services/farm_service.dart';
import 'package:vocabodemo/views/farm/farm_hub_screen.dart';
import 'package:vocabodemo/core/utils/responsive.dart';
import 'package:vocabodemo/views/home/widgets/srs_due_widget.dart';
import 'package:vocabodemo/views/conversation/conversation_hub_screen.dart';
import 'package:vocabodemo/views/context_import/context_import_screen.dart';
import 'package:vocabodemo/views/battle/battle_hub_screen.dart';
import 'package:vocabodemo/views/review/srs_review_screen.dart';
import 'package:vocabodemo/views/daily_challenge/daily_challenge_screen.dart';
import 'package:vocabodemo/views/vocab_map/vocab_map_screen.dart';
import 'package:vocabodemo/views/ai_conversation/ai_conversation_screen.dart';
import 'package:vocabodemo/views/home/widgets/srs_insight_widget.dart';
import 'package:vocabodemo/views/word_story/word_story_screen.dart';

////////////////////////////////////////////////////////////
/// USER STATS
////////////////////////////////////////////////////////////

class UserStats {
  final String level;
  final int streak;
  final int wordsLearned;
  final double progress;
  final int totalWords;
  final int lastTestScore;
  final int totalTests;

  const UserStats({
    required this.level,
    required this.streak,
    required this.wordsLearned,
    required this.progress,
    this.totalWords = 0,
    this.lastTestScore = 0,
    this.totalTests = 0,
  });

  factory UserStats.fromMap(Map<String, dynamic> d) {
    return UserStats(
      level: (d['level'] ?? 'A1').toString(),
      streak: (d['streak'] ?? 0).toInt(),
      wordsLearned: (d['wordsLearned'] ?? 0).toInt(),
      progress: (d['progress'] ?? 0.0).toDouble(),
      totalWords: (d['totalWords'] ?? 0).toInt(),
      lastTestScore: (d['lastTestScore'] ?? 0).toInt(),
      totalTests: (d['totalTests'] ?? 0).toInt(),
    );
  }

  static const empty = UserStats(
    level: 'A1',
    streak: 0,
    wordsLearned: 0,
    progress: 0,
  );
}

////////////////////////////////////////////////////////////
/// HOME SCREEN
////////////////////////////////////////////////////////////

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  /// Public method — cho phép widget con chuyển tab mà không dùng setState trực tiếp
  void switchTab(int i) => setState(() => index = i);

  @override
  void initState() {
    super.initState();
    CurrencyService.initCurrencyIfNeeded();
    CurrencyService.checkHeartRecovery();
    StreakService.checkAndUpdateStreak();
    GameService.initCoinsIfNeeded();
    HouseService.initHouseIfNeeded();
  }

  List<Widget> get _screens => [
    const HomePage(),
    const GamesHubScreen(),
    AddScreen(onBack: () => switchTab(0)),
    const ChatListScreen(),
    const SettingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: index, children: _screens),
          const AIChatBubble(),
          const CheckinBubble(),
          Positioned(
            left: 20,
            right: 20,
            bottom: 24,
            child: _FloatingNavBar(
              currentIndex: index,
              onTap: (i) => setState(() => index = i),
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// FLOATING NAV BAR — Adorable House cozy style
////////////////////////////////////////////////////////////

class _FloatingNavBar extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<_FloatingNavBar> createState() => _FloatingNavBarState();
}

class _FloatingNavBarState extends State<_FloatingNavBar> {
  int _chatUnread = 0;
  int _friendRequests = 0;

  // Emoji + label pairs for cozy nav
  static const _items = [
    _NavItem(icon: Icons.home_rounded,               label: 'Trang chủ', emoji: '🏡'),
    _NavItem(icon: Icons.sports_esports_rounded,     label: 'Games',     emoji: '🎮'),
    _NavItem(icon: Icons.add_circle_rounded,         label: 'Thêm',      emoji: '➕', isCenter: true),
    _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chat',     emoji: '💬'),
    _NavItem(icon: Icons.settings_rounded,           label: 'Cài đặt',  emoji: '⚙️'),
  ];

  @override
  void initState() {
    super.initState();
    _listenChatUnread();
    _listenFriendRequests();
  }

  void _listenChatUnread() {
    ChatService.totalUnreadStream().listen((count) {
      if (mounted) setState(() => _chatUnread = count);
    });
  }

  void _listenFriendRequests() {
    FriendService.pendingRequestCountStream().listen((count) {
      if (mounted) setState(() => _friendRequests = count);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Warm cream background for nav
    final navBg = isDark ? const Color(0xFF2C2C3E) : const Color(0xFFFFFBF5);
    final chatBadge = _chatUnread + _friendRequests;

    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: navBg,
        borderRadius: BorderRadius.circular(36),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(isDark ? 0.3 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFFFF8C69).withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.06)
              : const Color(0xFFFFD580).withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final sel  = widget.currentIndex == i;
          final badge = i == 3 ? chatBadge : 0;

          return Expanded(
            child: Center(
              child: item.isCenter
                  ? _CenterButton(onTap: () => widget.onTap(i))
                  : _NavButton(
                      item:    item,
                      selected: sel,
                      badge:   badge,
                      onTap:   () => widget.onTap(i),
                    ),
            ),
          );
        }),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// CENTER ADD BUTTON
////////////////////////////////////////////////////////////

class _CenterButton extends StatefulWidget {
  final VoidCallback onTap;
  const _CenterButton({required this.onTap});

  @override
  State<_CenterButton> createState() => _CenterButtonState();
}

class _CenterButtonState extends State<_CenterButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scale = Tween(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _rotation = Tween(begin: 0.0, end: 0.125).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_) async {
    await Future.delayed(const Duration(milliseconds: 100));
    _ctrl.reverse();
    widget.onTap();
  }
  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.scale(
          scale: _scale.value,
          child: Transform.rotate(
            angle: _rotation.value * 3.14159 * 2,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB347), Color(0xFFFF8C69)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8C69).withOpacity(0.45),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Center(
                child: Text('➕', style: TextStyle(fontSize: 22)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// NAV BUTTON với hiệu ứng bounce + indicator
////////////////////////////////////////////////////////////

class _NavButton extends StatefulWidget {
  final _NavItem item;
  final bool selected;
  final int  badge;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bounce = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -6.0), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -6.0, end: 2.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 2.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_NavButton old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Warm orange-amber active color — Adorable House palette
    const activeColor = Color(0xFFFF8C69);
    final inactiveColor = Theme.of(context).brightness == Brightness.dark
        ? Colors.grey.shade500
        : const Color(0xFFBCAAA4);

    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Transform.translate(
          offset: Offset(0, widget.selected ? _bounce.value : 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Indicator dot — warm amber
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: widget.selected ? 20 : 0,
                height: 3,
                margin: const EdgeInsets.only(bottom: 2),
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Emoji icon with pastel bg when selected
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.selected
                      ? activeColor.withOpacity(0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Show emoji if available, else fallback to icon
                    widget.item.emoji.isNotEmpty
                        ? Text(
                            widget.item.emoji,
                            style: TextStyle(
                              fontSize: widget.selected ? 22 : 20,
                            ),
                          )
                        : Icon(
                            widget.item.icon,
                            color: widget.selected ? activeColor : inactiveColor,
                            size: widget.selected ? 24 : 22,
                          ),
                    // Badge đỏ
                    if (widget.badge > 0)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              widget.badge > 9 ? '9+' : '${widget.badge}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 2),

              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: widget.selected ? 10.5 : 10,
                  fontWeight: widget.selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: widget.selected ? activeColor : inactiveColor,
                ),
                child: Text(widget.item.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// NAV ITEM MODEL
////////////////////////////////////////////////////////////

class _NavItem {
  final IconData icon;
  final String label;
  final bool isCenter;
  final String emoji;

  const _NavItem({
    required this.icon,
    required this.label,
    this.isCenter = false,
    this.emoji = '',
  });
}

////////////////////////////////////////////////////////////
/// HOME PAGE STREAM
////////////////////////////////////////////////////////////

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const _HomeContent(stats: UserStats.empty);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final stats = UserStats.fromMap(data);
        return _HomeContent(stats: stats);
      },
    );
  }
}

////////////////////////////////////////////////////////////
/// HOME CONTENT
////////////////////////////////////////////////////////////

class _HomeContent extends StatelessWidget {
  final UserStats stats;

  const _HomeContent({required this.stats});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? null : const Color(0xFFFFF8F0),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: HeaderSection(stats: stats)),
          SliverToBoxAdapter(child: const MenuSection()),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: r.hPad),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 16),
                const LearningPath(),
                const SizedBox(height: 16),
                const SrsDueWidget(),
                const SizedBox(height: 16),
                const SrsInsightWidget(),
                const SizedBox(height: 16),
                const WeeklyChartFirestore(),
                const SizedBox(height: 16),
                AchievementCard(
                  streak: stats.streak,
                  words: stats.wordsLearned,
                  progress: stats.progress,
                ),
                const SizedBox(height: 16),
                const _MiniGamesPreview(),
                const SizedBox(height: 16),
                const _MiniHousePreview(),
                SizedBox(height: r.isAnyTablet ? 130 : 110),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// HEADER — Adorable House style (warm cozy room top)
////////////////////////////////////////////////////////////

class HeaderSection extends StatelessWidget {
  final UserStats stats;

  const HeaderSection({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    final progressPct = (stats.progress * 100).toInt();

    return Container(
      decoration: const BoxDecoration(
        // Warm sky gradient — giống trần nhà Adorable House
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFD580), Color(0xFFFFB347), Color(0xFFFF8C69)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Decorative clouds / stars
          const Positioned(top: 18, left: 30, child: _CloudDeco(size: 28)),
          const Positioned(top: 10, right: 80, child: _CloudDeco(size: 20)),
          const Positioned(top: 30, right: 20, child: _StarDeco()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                context.r.hPad, context.r.vPad,
                context.r.hPad, context.r.vPad + 4,
              ),
              child: Column(
                children: [
                  // Top row: avatar + name | currency + action buttons
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with cute border
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.orange.withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundImage: NetworkImage(
                            user.photoURL ?? 'https://i.pravatar.cc/300',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Name + level + streak
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName ?? 'User',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: context.r.sp(16),
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x55000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                _LevelBadge(level: stats.level),
                                const SizedBox(width: 6),
                                _StreakBadge(streak: stats.streak),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Right side: currency + icon buttons stacked
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Currency (hearts + gems + coins)
                          _HeaderCurrencyWidget(uid: user.uid),
                          const SizedBox(height: 6),
                          // Action buttons row
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CharacterAvatarBtn(uid: user.uid),
                              const SizedBox(width: 4),
                              _HeaderIconBtn(
                                icon: Icons.calendar_month_rounded,
                                onTap: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) => const CalendarScreen())),
                              ),
                              const SizedBox(width: 4),
                              _HeaderIconBtn(
                                icon: Icons.notifications_rounded,
                                onTap: () => Navigator.push(context,
                                  MaterialPageRoute(
                                      builder: (_) => const NotificationScreen())),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const SearchBox(),
                  const SizedBox(height: 16),
                  // Stat tiles — cozy card style
                  Row(
                    children: [
                      Expanded(
                        child: _CozyStatTile(
                          emoji: '📖',
                          value: '${stats.wordsLearned}',
                          label: 'Từ vựng',
                          bgColor: const Color(0xFFFFF3E0),
                          accentColor: const Color(0xFFFF8C00),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CozyStatTile(
                          emoji: '🌱',
                          value: '$progressPct%',
                          label: 'Tiến độ',
                          bgColor: const Color(0xFFE8F5E9),
                          accentColor: const Color(0xFF4CAF50),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _CozyStatTile(
                          emoji: '🔥',
                          value: '${stats.streak}',
                          label: 'Streak',
                          bgColor: const Color(0xFFFFEBEE),
                          accentColor: const Color(0xFFE53935),
                        ),
                      ),
                    ],
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

/// Cozy stat tile — card trắng nhỏ kiểu Adorable House
class _CozyStatTile extends StatelessWidget {
  final String emoji;
  final String value;
  final String label;
  final Color bgColor;
  final Color accentColor;

  const _CozyStatTile({
    required this.emoji,
    required this.value,
    required this.label,
    required this.bgColor,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Container(
      padding: EdgeInsets.symmetric(vertical: r.w(10), horizontal: r.w(8)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r.r(16)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.18),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: TextStyle(fontSize: r.sp(22))),
          SizedBox(height: r.w(4)),
          Text(
            value,
            style: TextStyle(
              fontSize: r.sp(16),
              fontWeight: FontWeight.bold,
              color: accentColor,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: r.sp(10),
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Cloud decoration widget
class _CloudDeco extends StatelessWidget {
  final double size;
  const _CloudDeco({required this.size});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.35,
      child: CustomPaint(
        size: Size(size * 2.2, size),
        painter: _CloudPainter(),
      ),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w * 0.3, h * 0.6), h * 0.4, paint);
    canvas.drawCircle(Offset(w * 0.5, h * 0.4), h * 0.5, paint);
    canvas.drawCircle(Offset(w * 0.7, h * 0.6), h * 0.38, paint);
    canvas.drawRect(Rect.fromLTRB(w * 0.15, h * 0.55, w * 0.85, h), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Star decoration
class _StarDeco extends StatelessWidget {
  const _StarDeco();

  @override
  Widget build(BuildContext context) {
    return const Opacity(
      opacity: 0.5,
      child: Text('✨', style: TextStyle(fontSize: 16)),
    );
  }
}

////////////////////////////////////////////////////////////
/// MENU SECTION — Adorable House style grid
////////////////////////////////////////////////////////////

enum _MenuRoute { words, review, test, grammar, house, conversation, battle, contextImport, srsReview, dailyChallenge, vocabMap, wordStory, aiConversation }

class MenuSection extends StatelessWidget {
  const MenuSection({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(r.hPad, r.vPad + 4, r.hPad, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C69),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Học ngay',
                style: TextStyle(
                  fontSize: r.sp(15),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D4037),
                ),
              ),
            ],
          ),
          SizedBox(height: r.w(14)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              MenuItem(
                emoji: '📚',
                title: 'Từ vựng',
                routeType: _MenuRoute.words,
                bgColor: Color(0xFFFFF3E0),
                accentColor: Color(0xFFFF8C00),
              ),
              MenuItem(
                emoji: '🔄',
                title: 'Ôn tập',
                routeType: _MenuRoute.review,
                bgColor: Color(0xFFE3F2FD),
                accentColor: Color(0xFF1E88E5),
              ),
              MenuItem(
                emoji: '📝',
                title: 'Kiểm tra',
                routeType: _MenuRoute.test,
                bgColor: Color(0xFFF3E5F5),
                accentColor: Color(0xFF8E24AA),
              ),
              MenuItem(
                emoji: '📖',
                title: 'Ngữ pháp',
                routeType: _MenuRoute.grammar,
                bgColor: Color(0xFFE8F5E9),
                accentColor: Color(0xFF43A047),
              ),
              MenuItem(
                emoji: '🏠',
                title: 'Nhà',
                routeType: _MenuRoute.house,
                bgColor: Color(0xFFFFEBEE),
                accentColor: Color(0xFFE53935),
              ),
            ],
          ),
          SizedBox(height: r.w(14)),
          // Row 2: tính năng mới
          Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Tính năng mới ✨',
                style: TextStyle(
                  fontSize: r.sp(15),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D4037),
                ),
              ),
            ],
          ),
          SizedBox(height: r.w(14)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              MenuItem(
                emoji: '🎤',
                title: 'Hội thoại',
                routeType: _MenuRoute.conversation,
                bgColor: Color(0xFFE8EAF6),
                accentColor: Color(0xFF3949AB),
              ),
              MenuItem(
                emoji: '📊',
                title: 'SRS Ôn tập',
                routeType: _MenuRoute.srsReview,
                bgColor: Color(0xFFE0F2F1),
                accentColor: Color(0xFF00897B),
              ),
              MenuItem(
                emoji: '🎬',
                title: 'Lyrics',
                routeType: _MenuRoute.contextImport,
                bgColor: Color(0xFFFCE4EC),
                accentColor: Color(0xFFD81B60),
              ),
              MenuItem(
                emoji: '⚔️',
                title: 'Battle',
                routeType: _MenuRoute.battle,
                bgColor: Color(0xFFFFF8E1),
                accentColor: Color(0xFFF57F17),
              ),
            ],
          ),
          SizedBox(height: r.w(14)),
          // Row 3: tính năng nổi bật mới
          Row(
            children: [
              Container(
                width: 4, height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF06D6A0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Nổi bật 🚀',
                style: TextStyle(
                  fontSize: r.sp(15),
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF5D4037),
                ),
              ),
            ],
          ),
          SizedBox(height: r.w(14)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: const [
              MenuItem(
                emoji: '🏆',
                title: 'Thử thách',
                routeType: _MenuRoute.dailyChallenge,
                bgColor: Color(0xFFFFF3E0),
                accentColor: Color(0xFFFF8C00),
              ),
              MenuItem(
                emoji: '🗺️',
                title: 'Vocab Map',
                routeType: _MenuRoute.vocabMap,
                bgColor: Color(0xFFE8F5E9),
                accentColor: Color(0xFF2E7D32),
              ),
              MenuItem(
                emoji: '📖',
                title: 'Word Story',
                routeType: _MenuRoute.wordStory,
                bgColor: Color(0xFFE3F2FD),
                accentColor: Color(0xFF1565C0),
              ),
              MenuItem(
                emoji: '🤖',
                title: 'AI Chat',
                routeType: _MenuRoute.aiConversation,
                bgColor: Color(0xFFF3E5F5),
                accentColor: Color(0xFF6A1B9A),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// MENU ITEM — Adorable House style (emoji + pastel card)
////////////////////////////////////////////////////////////

class MenuItem extends StatefulWidget {
  final String emoji;
  final String title;
  final _MenuRoute routeType;
  final Color bgColor;
  final Color accentColor;

  // Legacy icon params kept for backward compat (ignored)
  final IconData? icon;
  final double iconSize;
  final Color iconColor;

  const MenuItem({
    super.key,
    required this.title,
    required this.routeType,
    this.emoji = '📌',
    this.bgColor = const Color(0xFFF5F5F5),
    this.accentColor = const Color(0xFF667eea),
    // legacy
    this.icon,
    this.iconSize = 30,
    this.iconColor = const Color(0xff2651ff),
  });

  @override
  State<MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<MenuItem>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  void _down(TapDownDetails _) => setState(() => _scale = 0.88);
  void _up(TapUpDetails _) => setState(() => _scale = 1.0);
  void _cancel() => setState(() => _scale = 1.0);

  void _navigate(BuildContext ctx) {
    switch (widget.routeType) {
      case _MenuRoute.words:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const FlashcardScreen()));
        break;
      case _MenuRoute.review:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const ReviewScreen()));
        break;
      case _MenuRoute.test:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const TestScreen()));
        break;
      case _MenuRoute.grammar:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const GrammarScreen()));
        break;
      case _MenuRoute.house:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const HouseScreen()));
        break;
      case _MenuRoute.conversation:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const ConversationHubScreen()));
        break;
      case _MenuRoute.srsReview:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const SrsReviewScreen()));
        break;
      case _MenuRoute.contextImport:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const ContextImportScreen()));
        break;
      case _MenuRoute.battle:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const BattleHubScreen()));
        break;
      case _MenuRoute.dailyChallenge:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const DailyChallengeScreen()));
        break;
      case _MenuRoute.vocabMap:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const VocabMapScreen()));
        break;
      case _MenuRoute.wordStory:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const WordStoryEntryScreen()));
        break;
      case _MenuRoute.aiConversation:
        Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const AIConversationScreen()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    final cardSize = r.w(58);
    return GestureDetector(
      onTap: () => _navigate(context),
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: cardSize,
              height: cardSize,
              decoration: BoxDecoration(
                color: widget.bgColor,
                borderRadius: BorderRadius.circular(r.r(18)),
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: widget.accentColor.withOpacity(0.18),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  widget.emoji,
                  style: TextStyle(fontSize: r.sp(26)),
                ),
              ),
            ),
            SizedBox(height: r.w(7)),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: r.sp(11),
                fontWeight: FontWeight.w600,
                color: widget.accentColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// STAT TILE (legacy — no longer used, kept for reference)
////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////
/// BADGES
////////////////////////////////////////////////////////////

class _LevelBadge extends StatelessWidget {
  final String level;
  const _LevelBadge({required this.level});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white24,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      'Lv.$level',
      style: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
}

class _StreakBadge extends StatelessWidget {
  final int streak;
  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    // Lấy trạng thái học hôm nay realtime
    return StreamBuilder<StreakInfo>(
      stream: StreakService.streakStream(),
      builder: (context, snap) {
        final info = snap.data;
        final hasStudiedToday = info?.hasStudiedToday ?? false;
        final displayStreak = info?.streak ?? streak;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: hasStudiedToday ? Colors.orange : Colors.orange.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasStudiedToday ? '🔥' : '💤',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(width: 3),
              Text(
                '$displayStreak',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}

////////////////////////////////////////////////////////////
/// HEADER CURRENCY WIDGET (Hearts + Diamonds)
////////////////////////////////////////////////////////////

/// Button icon nhỏ trên header (calendar, notification)
class _HeaderIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconBtn({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.5),
            width: 1.5,
          ),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _HeaderCurrencyWidget extends StatelessWidget {
  final String uid;
  const _HeaderCurrencyWidget({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final hearts = (data['hearts'] ?? 5).toInt();
        final diamonds = (data['diamonds'] ?? 0).toInt();
        final coins = (data['coins'] ?? 0).toInt();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hearts row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) => Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  i < hearts ? '❤️' : '🖤',
                  style: const TextStyle(fontSize: 13),
                ),
              )),
            ),
            const SizedBox(height: 4),
            // Diamonds + Coins
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CurrencyPill(icon: '💎', value: diamonds),
                const SizedBox(width: 4),
                _CurrencyPill(icon: '🪙', value: coins),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _CurrencyPill extends StatelessWidget {
  final String icon;
  final int value;
  const _CurrencyPill({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// MINI GAMES PREVIEW (Home page widget) — Adorable House style
////////////////////////////////////////////////////////////

class _MiniGamesPreview extends StatelessWidget {
  const _MiniGamesPreview();

  static const _games = [
    ('🔗', 'Nối Từ', Color(0xFFFFB347)),
    ('🃏', 'Lật Thẻ', Color(0xFF81C784)),
    ('🔍', 'Tìm Từ', Color(0xFFFF8A65)),
    ('⚡', 'Quiz',   Color(0xFFFFD54F)),
    ('🧩', 'Anagram', Color(0xFF9575CD)),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C69),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '🎮 Mini Games',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {
                final homeState = context
                    .findAncestorStateOfType<_HomeScreenState>();
                homeState?.switchTab(1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFFB347).withOpacity(0.4),
                  ),
                ),
                child: const Text(
                  'Xem tất cả →',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _games.map((g) {
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  final homeState = context
                      .findAncestorStateOfType<_HomeScreenState>();
                  homeState?.switchTab(1);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: g.$3.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: g.$3.withOpacity(0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(
                          color: g.$3.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(g.$1,
                            style: const TextStyle(fontSize: 26)),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      g.$2,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: g.$3.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

////////////////////////////////////////////////////////////
/// MINI HOUSE PREVIEW (Home page widget) — Adorable House style
////////////////////////////////////////////////////////////

class _MiniHousePreview extends StatelessWidget {
  const _MiniHousePreview();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4, height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C69),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '🏠 Nhà của tôi',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5D4037)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HouseScreen()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8C69).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFFF8C69).withOpacity(0.35),
                  ),
                ),
                child: const Text(
                  'Vào nhà →',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFE64A19),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const HouseScreen()),
          ),
          child: StreamBuilder<HouseData>(
            stream: HouseService.houseStream(uid),
            builder: (context, snap) {
              final house = snap.data ?? HouseData.defaultHouse();
              final pet = house.pet;
              return Container(
                decoration: BoxDecoration(
                  // Warm cream border card
                  color: const Color(0xFFFFFBF5),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFD580).withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF8C69).withOpacity(0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IntrinsicHeight(
                  child: Row(
                  children: [
                    // Mini room — Adorable House style: mint wall + wood floor
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          // Mint green wall like Adorable House
                          color: const Color(0xFFB2DFDB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            children: [
                              // Wall (mint)
                              Container(color: const Color(0xFFB2DFDB)),
                              // Wood floor strip at bottom
                              Positioned(
                                bottom: 0, left: 0, right: 0,
                                height: 28,
                                child: CustomPaint(
                                  painter: _WoodFloorPainter(),
                                ),
                              ),
                              // Window top-left
                              Positioned(
                                top: 6, left: 6,
                                child: _MiniWindow(),
                              ),
                              // Shelf top-right
                              Positioned(
                                top: 8, right: 4,
                                child: const Text('📚', style: TextStyle(fontSize: 12)),
                              ),
                              // Pet
                              Positioned(
                                left: 18, bottom: 28,
                                child: Text(pet.emoji,
                                    style: const TextStyle(fontSize: 22)),
                              ),
                              // Heart bubble above pet
                              Positioned(
                                left: 28, bottom: 46,
                                child: const Text('�', style: TextStyle(fontSize: 10)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Info panel
                    Expanded(
                      flex: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Text(pet.emoji,
                                    style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 6),
                                Text(
                                  pet.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Color(0xFF5D4037)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _MiniStatBar(
                              icon: '🍖',
                              value: pet.hunger / 100,
                              color: const Color(0xFFFFB347),
                            ),
                            const SizedBox(height: 4),
                            _MiniStatBar(
                              icon: '💕',
                              value: pet.happiness / 100,
                              color: const Color(0xFFFF8A80),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFFB347), Color(0xFFFF8C69)],
                                ),
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFF8C69).withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Text(
                                '🏠 Vào nhà',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                ), // IntrinsicHeight
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Farm preview
        _MiniFarmPreview(uid: uid),
      ],
    );
  }
}

////////////////////////////////////////////////////////////
/// MINI FARM PREVIEW (inside _MiniHousePreview) — cozy style
////////////////////////////////////////////////////////////

class _MiniFarmPreview extends StatelessWidget {
  final String uid;
  const _MiniFarmPreview({required this.uid});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const FarmHubScreen()),
      ),
      child: StreamBuilder<FarmData>(
        stream: FarmService.farmStream(),
        builder: (context, snap) {
          final farm = snap.data ?? FarmData.defaultFarm();
          final readyCrops = farm.readyCrops;
          final readyAnimals = farm.readyAnimals;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xFF81C784).withOpacity(0.45),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF81C784).withOpacity(0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Farm icon — pastel green card
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8E6C9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('🌿', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nông trại',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF5D4037)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (readyCrops > 0) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFC8E6C9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🌱 $readyCrops sẵn thu',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF2E7D32),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (readyAnimals > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFE0B2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🐄 $readyAnimals sản phẩm',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFFE65100),
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          if (readyCrops == 0 && readyAnimals == 0)
                            Text(
                              '${farm.plots.where((p) => p.stage == 'growing').length} cây đang trồng',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Color(0xFF81C784)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MiniStatBar extends StatelessWidget {
  final String icon;
  final double value;
  final Color color;
  const _MiniStatBar({
    required this.icon,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(icon, style: const TextStyle(fontSize: 11)),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: value.clamp(0.0, 1.0),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(color),
              minHeight: 5,
            ),
          ),
        ),
      ],
    );
  }
}

////////////////////////////////////////////////////////////
/// WOOD FLOOR PAINTER — Adorable House style planks
////////////////////////////////////////////////////////////

class _WoodFloorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final plankPaint = Paint()..color = const Color(0xFFCB9B5E);
    final linePaint = Paint()
      ..color = const Color(0xFFAD7C3E)
      ..strokeWidth = 1;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), plankPaint);

    // Horizontal plank lines
    for (double y = 0; y < size.height; y += 9) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
    // Vertical plank joints (staggered)
    for (int row = 0; row * 9 < size.height; row++) {
      final offset = row.isEven ? 0.0 : size.width / 2;
      for (double x = offset; x < size.width; x += size.width / 2) {
        canvas.drawLine(
          Offset(x, row * 9.0),
          Offset(x, (row + 1) * 9.0),
          linePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

////////////////////////////////////////////////////////////
/// MINI WINDOW — cute 2-pane window like Adorable House
////////////////////////////////////////////////////////////

class _MiniWindow extends StatelessWidget {
  const _MiniWindow();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 22,
      decoration: BoxDecoration(
        color: const Color(0xFF87CEEB),
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF8D6E63), width: 1.5),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container(color: const Color(0xFF87CEEB))),
                Container(width: 1, color: const Color(0xFF8D6E63)),
                Expanded(child: Container(color: const Color(0xFFB0E0FF))),
              ],
            ),
          ),
          Container(height: 1, color: const Color(0xFF8D6E63)),
          Expanded(
            child: Row(
              children: [
                Expanded(child: Container(color: const Color(0xFFB0E0FF))),
                Container(width: 1, color: const Color(0xFF8D6E63)),
                Expanded(child: Container(color: const Color(0xFF87CEEB))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}




// ─── Character Avatar Button (header) ────────────────────────────────────────
class _CharacterAvatarBtn extends StatelessWidget {
  final String uid;
  const _CharacterAvatarBtn({required this.uid});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CharacterModel?>(
      stream: CharacterService.characterStream(),
      builder: (context, snap) {
        final character = snap.data;
        return GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CharacterCreatorScreen(
                  initial: character,
                  isFirstTime: character == null,
                ),
              ),
            );
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: character != null
                    ? const Color(0xFFFF8C69)
                    : Colors.grey.shade300,
                width: 2,
              ),
            ),
            child: character != null
                ? ClipOval(
                    child: CharacterWidget(
                      character: character,
                      mode: CharAnimMode.idle,
                      size: 36,
                    ),
                  )
                : const Icon(
                    Icons.person_add_rounded,
                    color: Color(0xFFFF8C69),
                    size: 20,
                  ),
          ),
        );
      },
    );
  }
}
