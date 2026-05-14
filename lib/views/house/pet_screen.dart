import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/services/house_service.dart';
import 'gacha_screen.dart';
import 'pet_painter.dart';

// ignore_for_file: library_private_types_in_public_api

// ─────────────────────────────────────────────────────────────────────────────
// PetScreen — Game-style pet home (inspired by Adorable Home / Tamagotchi)
// Layout: sky+house background, pet in window, speech bubble, bottom action bar
// ─────────────────────────────────────────────────────────────────────────────

class PetScreen extends StatefulWidget {
  final PetData pet;
  final bool isOwner;
  const PetScreen({super.key, required this.pet, required this.isOwner});

  @override
  State<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends State<PetScreen> with TickerProviderStateMixin {
  late PageController _pageCtrl;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HouseData>(
      stream: HouseService.houseStream(),
      builder: (context, snap) {
        final house = snap.data ?? HouseData.defaultHouse();
        final pets = house.pets;

        if (pets.isEmpty) {
          return _EmptyPetScaffold();
        }

        final initialIdx = pets.indexWhere((p) => p.id == widget.pet.id);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageCtrl.hasClients && initialIdx > 0 && _currentPage == 0) {
            _pageCtrl.jumpToPage(initialIdx);
          }
        });

        return Scaffold(
          backgroundColor: const Color(0xFF87CEEB),
          body: Stack(
            children: [
              // Full-screen page view of pet scenes
              PageView.builder(
                controller: _pageCtrl,
                itemCount: pets.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, i) => _PetGameScene(
                  pet: pets[i],
                  isOwner: widget.isOwner,
                  house: house,
                ),
              ),
              // Top bar overlay
              SafeArea(
                child: _TopBar(
                  pets: pets,
                  currentPage: _currentPage,
                  house: house,
                  isOwner: widget.isOwner,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPetScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🥚', style: TextStyle(fontSize: 72)),
            const SizedBox(height: 16),
            const Text('Chưa có thú cưng nào!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5C4033),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('Quay lại'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Top Bar — back button + timer + shop/food icons + page dots
// ─────────────────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final List<PetData> pets;
  final int currentPage;
  final HouseData house;
  final bool isOwner;

  const _TopBar({
    required this.pets,
    required this.currentPage,
    required this.house,
    required this.isOwner,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Back button
          _CircleBtn(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF5C4033), size: 18),
          ),
          const SizedBox(width: 8),
          // Timer pill (decorative — shows session time)
          _TimerPill(),
          const Spacer(),
          // Shop icon
          _CircleBtn(
            onTap: () {},
            child: const Text('🏠', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 6),
          // Food icon
          _CircleBtn(
            onTap: () {},
            child: const Text('🍎', style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 6),
          // More
          _CircleBtn(
            onTap: () {},
            child: const Icon(Icons.more_horiz_rounded, color: Color(0xFF5C4033), size: 20),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _CircleBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _TimerPill extends StatefulWidget {
  @override
  State<_TimerPill> createState() => _TimerPillState();
}

class _TimerPillState extends State<_TimerPill> {
  late Timer _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String get _formatted {
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600) ~/ 60;
    final s = _seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏠', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(_formatted,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF5C4033))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pet Game Scene — the main full-screen scene per pet
// ─────────────────────────────────────────────────────────────────────────────

class _PetGameScene extends StatefulWidget {
  final PetData pet;
  final bool isOwner;
  final HouseData house;
  const _PetGameScene({required this.pet, required this.isOwner, required this.house});

  @override
  State<_PetGameScene> createState() => _PetGameSceneState();
}

class _PetGameSceneState extends State<_PetGameScene> with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late Animation<double> _bounceAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  Timer? _eggTimer;
  int _eggSecondsLeft = 0;
  bool _loading = false;
  String _message = '';
  int _activeTab = 3; // default: social tab (index 3)
  PetAction _currentPetAction = PetAction.idle;

  // Speech bubble messages per mood
  static const _happyMessages = [
    'Mình đang rất vui! 💕',
    'Cảm ơn bạn đã chăm sóc mình! 🌸',
    'Hôm nay thật tuyệt! ✨',
    'Mình yêu bạn lắm! 💖',
  ];
  static const _hungryMessages = [
    'Mình đói bụng rồi... 🍖',
    'Cho mình ăn với! 😿',
    'Bụng mình đang kêu đó! 🍽️',
  ];
  static const _sadMessages = [
    'Mình buồn quá... 😢',
    'Chơi với mình đi! 🎾',
    'Đừng bỏ mình một mình... 💔',
  ];

  String get _speechText {
    if (widget.pet.hunger < 30) {
      return _hungryMessages[DateTime.now().second % _hungryMessages.length];
    }
    if (widget.pet.happiness < 40) {
      return _sadMessages[DateTime.now().second % _sadMessages.length];
    }
    return _happyMessages[DateTime.now().second % _happyMessages.length];
  }

  @override
  void initState() {
    super.initState();
    _bounceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -8).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
    if (widget.pet.isEgg) _startEggCountdown();
  }

  void _startEggCountdown() {
    final hatchAt = widget.pet.hatchAt;
    if (hatchAt == null) return;
    _updateEggSeconds(hatchAt);
    _eggTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateEggSeconds(hatchAt);
      if (_eggSecondsLeft <= 0) {
        _eggTimer?.cancel();
        HouseService.checkAndHatchEggs().then((_) {
          if (mounted) _showHatchCelebration();
        });
      }
    });
  }

  void _updateEggSeconds(DateTime hatchAt) {
    final remaining = hatchAt.difference(DateTime.now());
    setState(() => _eggSecondsLeft = remaining.inSeconds.clamp(0, 999999));
  }

  void _showHatchCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFFFF8E1),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎉', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 12),
            const Text('Trứng đã nở!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Thú cưng của bạn đã ra đời!',
                style: TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 16),
            const Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                Text('🎊', style: TextStyle(fontSize: 24)),
                Text('✨', style: TextStyle(fontSize: 24)),
                Text('🌟', style: TextStyle(fontSize: 24)),
                Text('🎉', style: TextStyle(fontSize: 24)),
                Text('💫', style: TextStyle(fontSize: 24)),
              ],
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFBE0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Tuyệt vời!'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _glowCtrl.dispose();
    _eggTimer?.cancel();
    super.dispose();
  }

  Future<void> _feed() async {
    setState(() { _loading = true; _currentPetAction = PetAction.eat; });
    final result = await HouseService.feedPet(widget.pet.id);
    setState(() { _loading = false; _message = result.message; });
    if (result.success) _bounceCtrl.forward(from: 0);
    _clearMessage();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _currentPetAction = PetAction.happy);
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) setState(() => _currentPetAction = PetAction.idle);
      });
    });
  }

  Future<void> _play() async {
    setState(() { _loading = true; _currentPetAction = PetAction.play; });
    final result = await HouseService.playWithPet(widget.pet.id);
    setState(() { _loading = false; _message = result.message; });
    if (result.success) _bounceCtrl.forward(from: 0);
    _clearMessage();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _currentPetAction = PetAction.excited);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _currentPetAction = PetAction.idle);
      });
    });
  }

  void _clearMessage() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _message = '');
    });
  }

  void _rename() {
    final ctrl = TextEditingController(text: widget.pet.name);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Đặt tên thú cưng'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Nhập tên...', border: OutlineInputBorder()),
          maxLength: 20,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () async {
              await HouseService.namePet(ctrl.text.trim(), widget.pet.id);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C4033), foregroundColor: Colors.white,
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _release() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Thả thú cưng?'),
        content: Text('Bạn có chắc muốn thả ${widget.pet.name} đi không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await HouseService.releasePet(widget.pet.id);
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Thả'),
          ),
        ],
      ),
    );
  }

  void _evolve() {
    final info = kPetSpecies[widget.pet.species];
    final nextStage = {'baby': 'teen', 'teen': 'adult', 'adult': 'evolved'}[widget.pet.stage];
    final nextEmoji = nextStage == 'teen' ? info?.teenEmoji
        : nextStage == 'adult' ? info?.adultEmoji
        : info?.evolvedEmoji;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFFFF8E1),
        title: const Text('✨ Tiến hóa!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.pet.emoji, style: const TextStyle(fontSize: 40)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text('→', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                ),
                Text(nextEmoji ?? '✨', style: const TextStyle(fontSize: 40)),
              ],
            ),
            const SizedBox(height: 12),
            Text('${widget.pet.name} sẽ tiến hóa!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Huỷ')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await HouseService.evolvePet(widget.pet.id);
              if (err != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err), behavior: SnackBarBehavior.floating),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea), foregroundColor: Colors.white,
            ),
            child: const Text('Tiến hóa!'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pet = widget.pet;
    final xpForNext = pet.level * 50;
    final xpProgress = (pet.xp % xpForNext) / xpForNext;

    return Stack(
      children: [
        // ── Sky background ──────────────────────────────────
        Positioned.fill(child: _SkyBackground()),

        // ── House building ──────────────────────────────────
        Positioned(
          bottom: 100, left: 0, right: 0,
          child: _HouseBuilding(size: size),
        ),

        // ── Pet in window with bounce ───────────────────────
        Positioned(
          bottom: size.height * 0.30,
          left: size.width * 0.20,
          right: size.width * 0.20,
          child: AnimatedBuilder(
            animation: _bounceAnim,
            builder: (_, __) => Transform.translate(
              offset: Offset(0, _bounceAnim.value),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Speech bubble
                  _SpeechBubble(text: _message.isNotEmpty ? _message : _speechText),
                  const SizedBox(height: 8),
                  // Animated pet body
                  GestureDetector(
                    onTap: () {
                      _bounceCtrl.forward(from: 0);
                      setState(() => _message = '${pet.name} thích được vuốt ve! 💕');
                      _clearMessage();
                    },
                    onDoubleTap: () {
                      _bounceCtrl.forward(from: 0);
                      setState(() => _message = '${pet.name} vui lắm! 🎉');
                      _clearMessage();
                    },
                    child: pet.isEgg
                        ? Text(pet.emoji, style: const TextStyle(fontSize: 72))
                        : AnimatedPetWidget(
                            species: petSpeciesFromString(pet.species),
                            action: _currentPetAction,
                            size: 110,
                            facingRight: true,
                            happiness: pet.happiness.toDouble(),
                            hunger: pet.hunger.toDouble(),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // ── Pet name sign ───────────────────────────────────
        Positioned(
          bottom: size.height * 0.22,
          left: 0, right: 0,
          child: Center(child: _NameSign(pet: pet, isOwner: widget.isOwner, onRename: _rename)),
        ),

        // ── Left HUD panel ──────────────────────────────────
        Positioned(
          top: 80, left: 12,
          child: _LeftHudPanel(pet: pet, xpProgress: xpProgress),
        ),

        // ── Right side buttons ──────────────────────────────
        Positioned(
          top: 80, right: 12,
          child: Column(
            children: [
              // Gacha / rút thăm button
              _SideBtn(
                emoji: '🎰',
                badge: 'Rút thăm',
                badgeColor: const Color(0xFF7C4DFF),
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const GachaScreen())),
              ),
              const SizedBox(height: 12),
              // Shop button
              _SideBtn(
                emoji: '🏪',
                onTap: () {},
              ),
            ],
          ),
        ),

        // ── Left side action buttons ────────────────────────
        Positioned(
          bottom: 160, left: 12,
          child: Column(
            children: [
              // Mail / notification
              _SideBtn(
                emoji: '📬',
                badge: 'New',
                badgeColor: Colors.red,
                onTap: () {},
              ),
              const SizedBox(height: 12),
              // Bag / items
              _SideBtn(
                emoji: '🎒',
                hasDot: true,
                onTap: () {},
              ),
            ],
          ),
        ),

        // ── Bottom action log text ──────────────────────────
        Positioned(
          bottom: 108, left: 16, right: 16,
          child: _ActionLog(pet: pet),
        ),

        // ── Bottom navigation bar ───────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: _BottomNavBar(
            activeTab: _activeTab,
            isOwner: widget.isOwner,
            loading: _loading,
            onFeed: _feed,
            onPlay: _play,
            onEvolve: widget.isOwner && pet.canEvolve ? _evolve : null,
            onRelease: widget.isOwner ? _release : null,
            onTabChanged: (i) => setState(() => _activeTab = i),
          ),
        ),

        // ── Egg countdown overlay ───────────────────────────
        if (pet.isEgg)
          Positioned(
            bottom: 160, left: 0, right: 0,
            child: Center(
              child: _EggCountdownWidget(secondsLeft: _eggSecondsLeft, hatchAt: pet.hatchAt),
            ),
          ),

        // ── Evolve glow button (if can evolve) ─────────────
        if (widget.isOwner && pet.canEvolve)
          Positioned(
            top: 80, left: size.width / 2 - 60,
            child: AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => GestureDetector(
                onTap: _evolve,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFFC44DFF)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF667eea).withValues(alpha: _glowAnim.value * 0.7),
                      blurRadius: 14, spreadRadius: 2,
                    )],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('✨', style: TextStyle(fontSize: 16)),
                      SizedBox(width: 6),
                      Text('Tiến hóa!',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sky Background
// ─────────────────────────────────────────────────────────────────────────────

class _SkyBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF87CEEB), Color(0xFFB0E0FF), Color(0xFFD4F1C0)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Clouds
          Positioned(top: 60, left: 30, child: _Cloud(size: 60)),
          Positioned(top: 40, right: 50, child: _Cloud(size: 45)),
          Positioned(top: 100, left: 120, child: _Cloud(size: 35)),
          // Ground strip
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              height: 110,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF8BC34A), Color(0xFF558B2F)],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Cloud extends StatelessWidget {
  final double size;
  const _Cloud({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.8,
      height: size * 0.7,
      child: CustomPaint(painter: _CloudPainter()),
    );
  }
}

class _CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final cx = size.width / 2;
    final cy = size.height * 0.6;
    canvas.drawCircle(Offset(cx, cy), size.height * 0.5, paint);
    canvas.drawCircle(Offset(cx - size.width * 0.22, cy + size.height * 0.1), size.height * 0.38, paint);
    canvas.drawCircle(Offset(cx + size.width * 0.22, cy + size.height * 0.1), size.height * 0.38, paint);
    canvas.drawCircle(Offset(cx - size.width * 0.38, cy + size.height * 0.2), size.height * 0.28, paint);
    canvas.drawCircle(Offset(cx + size.width * 0.38, cy + size.height * 0.2), size.height * 0.28, paint);
  }

  @override
  bool shouldRepaint(_CloudPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// House Building (cartoon style)
// ─────────────────────────────────────────────────────────────────────────────

class _HouseBuilding extends StatelessWidget {
  final Size size;
  const _HouseBuilding({required this.size});

  @override
  Widget build(BuildContext context) {
    final w = size.width;
    final h = size.height * 0.55;
    return SizedBox(
      width: w,
      height: h,
      child: CustomPaint(painter: _HousePainter()),
    );
  }
}

class _HousePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // House body (cream/beige)
    final bodyPaint = Paint()..color = const Color(0xFFFFF8E7);
    final bodyRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.05, h * 0.28, w * 0.90, h * 0.72),
      topLeft: const Radius.circular(8),
      topRight: const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Roof (salmon/pink)
    final roofPaint = Paint()..color = const Color(0xFFE8907A);
    final roofPath = Path()
      ..moveTo(w * 0.0, h * 0.32)
      ..lineTo(w * 0.5, h * 0.0)
      ..lineTo(w * 1.0, h * 0.32)
      ..close();
    canvas.drawPath(roofPath, roofPaint);

    // Roof ridge (darker)
    final ridgePaint = Paint()
      ..color = const Color(0xFFD4705A)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(w * 0.0, h * 0.32), Offset(w * 1.0, h * 0.32), ridgePaint);

    // Chimney
    final chimneyPaint = Paint()..color = const Color(0xFFD4705A);
    canvas.drawRect(Rect.fromLTWH(w * 0.72, h * 0.04, w * 0.08, h * 0.22), chimneyPaint);

    // Window (center — where pet sits)
    _drawWindow(canvas, Rect.fromLTWH(w * 0.30, h * 0.30, w * 0.40, h * 0.32));

    // Side windows
    _drawSmallWindow(canvas, Rect.fromLTWH(w * 0.08, h * 0.38, w * 0.16, h * 0.18));
    _drawSmallWindow(canvas, Rect.fromLTWH(w * 0.76, h * 0.38, w * 0.16, h * 0.18));

    // Door
    final doorPaint = Paint()..color = const Color(0xFF8D6E63);
    final doorRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(w * 0.40, h * 0.68, w * 0.20, h * 0.32),
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
    );
    canvas.drawRRect(doorRect, doorPaint);

    // Door knob
    final knobPaint = Paint()..color = const Color(0xFFFFD700);
    canvas.drawCircle(Offset(w * 0.575, h * 0.82), 4, knobPaint);

    // Door frame
    final doorFramePaint = Paint()
      ..color = const Color(0xFF6D4C41)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(doorRect, doorFramePaint);
  }

  void _drawWindow(Canvas canvas, Rect rect) {
    // Window frame
    final framePaint = Paint()..color = const Color(0xFFD4C4A8);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), framePaint);

    // Glass
    final glassPaint = Paint()..color = const Color(0xFFB8E4F9);
    final inner = rect.deflate(4);
    canvas.drawRRect(RRect.fromRectAndRadius(inner, const Radius.circular(4)), glassPaint);

    // Cross divider
    final divPaint = Paint()..color = const Color(0xFFD4C4A8)..strokeWidth = 3;
    canvas.drawLine(Offset(rect.center.dx, inner.top), Offset(rect.center.dx, inner.bottom), divPaint);
    canvas.drawLine(Offset(inner.left, rect.center.dy), Offset(inner.right, rect.center.dy), divPaint);

    // Window sill
    final sillPaint = Paint()..color = const Color(0xFFBEAD94);
    canvas.drawRect(Rect.fromLTWH(rect.left - 6, rect.bottom - 4, rect.width + 12, 8), sillPaint);

    // Light reflection
    final reflectPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final reflectPath = Path()
      ..moveTo(inner.left + 4, inner.top + 4)
      ..lineTo(inner.left + inner.width * 0.35, inner.top + 4)
      ..lineTo(inner.left + inner.width * 0.25, inner.top + inner.height * 0.4)
      ..lineTo(inner.left + 4, inner.top + inner.height * 0.4)
      ..close();
    canvas.drawPath(reflectPath, reflectPaint);
  }

  void _drawSmallWindow(Canvas canvas, Rect rect) {
    final framePaint = Paint()..color = const Color(0xFFD4C4A8);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), framePaint);
    final glassPaint = Paint()..color = const Color(0xFFB8E4F9);
    canvas.drawRRect(RRect.fromRectAndRadius(rect.deflate(3), const Radius.circular(3)), glassPaint);
    final divPaint = Paint()..color = const Color(0xFFD4C4A8)..strokeWidth = 2;
    canvas.drawLine(Offset(rect.center.dx, rect.top + 3), Offset(rect.center.dx, rect.bottom - 3), divPaint);
  }

  @override
  bool shouldRepaint(_HousePainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Speech Bubble
// ─────────────────────────────────────────────────────────────────────────────

class _SpeechBubble extends StatelessWidget {
  final String text;
  const _SpeechBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: const BoxConstraints(maxWidth: 220),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 13, color: Color(0xFF333333), height: 1.4),
            textAlign: TextAlign.center,
          ),
        ),
        // Bubble tail pointing down
        Positioned(
          bottom: -8,
          child: CustomPaint(
            size: const Size(16, 10),
            painter: _BubbleTailPainter(),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BubbleTailPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Name Sign (wooden board)
// ─────────────────────────────────────────────────────────────────────────────

class _NameSign extends StatelessWidget {
  final PetData pet;
  final bool isOwner;
  final VoidCallback onRename;
  const _NameSign({required this.pet, required this.isOwner, required this.onRename});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wooden sign board
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFD4A96A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF8D6E63), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pet.name,
                style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF4E342E),
                  shadows: [Shadow(color: Colors.white38, offset: Offset(0, 1), blurRadius: 2)],
                ),
              ),
              if (isOwner) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onRename,
                  child: const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF6D4C41)),
                ),
              ],
            ],
          ),
        ),
        // Sign post
        Container(width: 6, height: 20, color: const Color(0xFF8D6E63)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Left HUD Panel (level + exp + streaks)
// ─────────────────────────────────────────────────────────────────────────────

class _LeftHudPanel extends StatelessWidget {
  final PetData pet;
  final double xpProgress;
  const _LeftHudPanel({required this.pet, required this.xpProgress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Level badge + XP bar
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF3F51B5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('Lv.${pet.level}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: xpProgress,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF3F51B5)),
                    minHeight: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // XP text
          Text(
            'Exp hôm nay',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          Text(
            '${pet.xp % (pet.level * 50)}/${pet.level * 50}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFFF9800)),
          ),
          const SizedBox(height: 8),
          // Streak lightning bolts
          Row(
            children: List.generate(5, (i) => Padding(
              padding: const EdgeInsets.only(right: 2),
              child: Text('⚡', style: TextStyle(fontSize: 14, color: i < 3 ? const Color(0xFFFF9800) : Colors.grey.shade300)),
            )),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Side Button (right/left floating buttons)
// ─────────────────────────────────────────────────────────────────────────────

class _SideBtn extends StatelessWidget {
  final String emoji;
  final String? badge;
  final Color? badgeColor;
  final bool hasDot;
  final VoidCallback onTap;

  const _SideBtn({
    required this.emoji,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.hasDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6, offset: const Offset(0, 3))],
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 26))),
          ),
          if (badge != null)
            Positioned(
              top: -6, left: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ),
          if (hasDot)
            Positioned(
              top: 4, right: 4,
              child: Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action Log (bottom text above nav bar)
// ─────────────────────────────────────────────────────────────────────────────

class _ActionLog extends StatelessWidget {
  final PetData pet;
  const _ActionLog({required this.pet});

  String get _logText {
    if (pet.hunger < 30) return '${pet.name} đang rất đói, hãy cho ăn ngay!';
    if (pet.happiness < 40) return '${pet.name} đang buồn, hãy chơi cùng!';
    return '${pet.name} đang vui vẻ trong nhà. 🏠';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)],
      ),
      child: Text(
        _logText,
        style: const TextStyle(fontSize: 12, color: Color(0xFF5C4033), fontWeight: FontWeight.w500),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom Navigation Bar (game-style brown tabs)
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNavBar extends StatelessWidget {
  final int activeTab;
  final bool isOwner;
  final bool loading;
  final VoidCallback onFeed;
  final VoidCallback onPlay;
  final VoidCallback? onEvolve;
  final VoidCallback? onRelease;
  final void Function(int) onTabChanged;

  const _BottomNavBar({
    required this.activeTab,
    required this.isOwner,
    required this.loading,
    required this.onFeed,
    required this.onPlay,
    this.onEvolve,
    this.onRelease,
    required this.onTabChanged,
  });

  static const _tabs = [
    ('🍽️', 'Ăn'),
    ('🚿', 'Tắm'),
    ('🎮', 'Chơi'),
    ('👥', 'Bạn bè'),
    ('💬', 'Chat'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: Color(0xFF5C4033),
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final (emoji, label) = _tabs[i];
          final isActive = activeTab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                onTabChanged(i);
                if (i == 0) onFeed();
                if (i == 2) onPlay();
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isActive ? Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5) : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    loading && (i == 0 || i == 2)
                        ? const SizedBox(
                            width: 24, height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(emoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(
                          fontSize: 10,
                          color: isActive ? Colors.white : Colors.white60,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Egg Countdown Widget
// ─────────────────────────────────────────────────────────────────────────────

class _EggCountdownWidget extends StatelessWidget {
  final int secondsLeft;
  final DateTime? hatchAt;
  const _EggCountdownWidget({required this.secondsLeft, this.hatchAt});

  @override
  Widget build(BuildContext context) {
    if (hatchAt == null) return const SizedBox.shrink();
    final m = secondsLeft ~/ 60;
    final s = secondsLeft % 60;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            secondsLeft <= 0 ? '🐣 Sắp nở!' : '🥚 Đang ấp... ${m}m ${s}s',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF5C4033)),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 160,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: secondsLeft <= 0 ? 1.0 : 0.5,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation(Color(0xFFFFBE0B)),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

