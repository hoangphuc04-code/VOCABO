// ignore_for_file: library_private_types_in_public_api
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:vocabodemo/AI/ai_planner_screen.dart';
import 'package:vocabodemo/data/services/motivation_service.dart';
import 'package:vocabodemo/widgets/character/meow_character.dart';
import 'package:vocabodemo/widgets/character/character_animations.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AIChatBubble — Meow tự đi lang thang trên màn hình
// ─────────────────────────────────────────────────────────────────────────────

class AIChatBubble extends StatefulWidget {
  const AIChatBubble({super.key});

  @override
  State<AIChatBubble> createState() => _AIChatBubbleState();
}

class _AIChatBubbleState extends State<AIChatBubble>
    with TickerProviderStateMixin {
  // ── Vị trí hiện tại ──────────────────────────────────
  double _x = 220;
  double _y = 400;

  // ── Vận tốc (pixel/tick) ─────────────────────────────
  double _vx = 1.2;
  double _vy = 0.8;

  // ── Kích thước nhân vật ───────────────────────────────
  static const double _size   = 90.0;
  static const double _margin = 10.0;

  // ── Trạng thái ────────────────────────────────────────
  bool           _isDragging     = false;
  bool           _facingRight    = true;
  bool           _isResting      = false; // đứng nghỉ ngẫu nhiên
  int            _unreadCount    = 0;
  CharacterState _characterState = CharacterState.idle;

  // ── Timers & controllers ──────────────────────────────
  Timer?                _moveTimer;
  Timer?                _restTimer;
  late AnimationController _bounceCtrl;
  late Animation<double>   _bounceAnim;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  final _rng = Random();

  @override
  void initState() {
    super.initState();

    // Bounce nhẹ khi idle
    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _bounceAnim = Tween<double>(begin: 0, end: -5).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );

    // Pulse cho fallback button
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _listenNotifications();
    _startWalking();

    // Vẫy tay chào khi khởi động
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _characterState = CharacterState.waving);
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) setState(() => _characterState = CharacterState.idle);
        });
      }
    });
  }

  @override
  void dispose() {
    _moveTimer?.cancel();
    _restTimer?.cancel();
    _bounceCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ── Lắng nghe thông báo ───────────────────────────────
  void _listenNotifications() {
    MotivationService.getUnreadNotifications().listen((list) {
      if (!mounted) return;
      final hasNew = list.length > _unreadCount;
      setState(() => _unreadCount = list.length);
      if (hasNew && _unreadCount > 0) {
        setState(() => _characterState = CharacterState.excited);
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) setState(() => _characterState = CharacterState.idle);
        });
      }
    });
  }

  // ── Bắt đầu đi lang thang ────────────────────────────
  void _startWalking() {
    _moveTimer?.cancel();
    // Tick mỗi 16ms (~60fps)
    _moveTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (!mounted || _isDragging || _isResting) return;
      _tick();
    });

    // Lên lịch nghỉ ngẫu nhiên
    _scheduleRest();
  }

  // Chiều cao bottom bar (72) + khoảng cách từ đáy (24) + padding thêm
  static const double _bottomBarHeight = 72 + 24 + 12;

  void _tick() {
    final screen = _screenSize;
    if (screen == Size.zero) return;

    final maxX = screen.width  - _size - _margin;
    final maxY = screen.height - _size - _margin - _bottomBarHeight;

    double nx = _x + _vx;
    double ny = _y + _vy;

    bool bounced = false;

    // Bounce cạnh trái/phải
    if (nx <= _margin) {
      nx = _margin;
      _vx = _vx.abs() * (0.9 + _rng.nextDouble() * 0.2);
      bounced = true;
    } else if (nx >= maxX) {
      nx = maxX;
      _vx = -_vx.abs() * (0.9 + _rng.nextDouble() * 0.2);
      bounced = true;
    }

    // Bounce cạnh trên/dưới
    if (ny <= _margin) {
      ny = _margin;
      _vy = _vy.abs() * (0.9 + _rng.nextDouble() * 0.2);
      bounced = true;
    } else if (ny >= maxY) {
      ny = maxY;
      _vy = -_vy.abs() * (0.9 + _rng.nextDouble() * 0.2);
      bounced = true;
    }

    // Thêm chút nhiễu ngẫu nhiên để đường đi tự nhiên hơn
    if (_rng.nextDouble() < 0.02) {
      _vx += (_rng.nextDouble() - 0.5) * 0.4;
      _vy += (_rng.nextDouble() - 0.5) * 0.4;
      _clampSpeed();
    }

    setState(() {
      _x = nx;
      _y = ny;
      if (_vx.abs() > 0.1) _facingRight = _vx > 0;
      if (bounced) _characterState = CharacterState.idle;
    });
  }

  // Giới hạn tốc độ tối đa/tối thiểu
  void _clampSpeed() {
    const minSpeed = 0.6;
    const maxSpeed = 2.2;
    final speed = sqrt(_vx * _vx + _vy * _vy);
    if (speed < minSpeed) {
      final scale = minSpeed / speed;
      _vx *= scale;
      _vy *= scale;
    } else if (speed > maxSpeed) {
      final scale = maxSpeed / speed;
      _vx *= scale;
      _vy *= scale;
    }
  }

  // Lên lịch nghỉ ngẫu nhiên (3-8 giây)
  void _scheduleRest() {
    final delay = 3000 + _rng.nextInt(5000);
    _restTimer?.cancel();
    _restTimer = Timer(Duration(milliseconds: delay), () {
      if (!mounted || _isDragging) { _scheduleRest(); return; }
      // Nghỉ 1-3 giây
      final restDuration = 1000 + _rng.nextInt(2000);
      setState(() {
        _isResting      = true;
        _characterState = CharacterState.idle;
      });
      Future.delayed(Duration(milliseconds: restDuration), () {
        if (!mounted) return;
        // Đổi hướng ngẫu nhiên sau khi nghỉ
        final angle = _rng.nextDouble() * 2 * pi;
        final speed = 0.8 + _rng.nextDouble() * 1.2;
        setState(() {
          _isResting      = false;
          _vx             = cos(angle) * speed;
          _vy             = sin(angle) * speed;
          _characterState = CharacterState.walking;
        });
        _scheduleRest();
      });
    });
  }

  // ── Trạng thái hiển thị ───────────────────────────────
  CharacterState get _displayState {
    if (_isDragging)  return CharacterState.walking;
    if (_isResting)   return CharacterState.idle;
    if (_unreadCount > 0 && _characterState == CharacterState.idle) {
      return CharacterState.thinking;
    }
    return _characterState;
  }

  // ── Mở chat ───────────────────────────────────────────
  Future<void> _openChat() async {
    final nav = Navigator.of(context);
    setState(() => _characterState = CharacterState.excited);
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    await nav.push(MaterialPageRoute(builder: (_) => const AIPlannerScreen()));
    await MotivationService.markAllAsRead();
    if (mounted) {
      setState(() {
        _unreadCount    = 0;
        _characterState = CharacterState.waving;
      });
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _characterState = CharacterState.idle);
      });
    }
  }

  // ── Snap về giữa màn hình ─────────────────────────────
  void _snapToCenter() {
    final s = _screenSize;
    setState(() {
      _x = s.width  / 2 - _size / 2;
      _y = (s.height - _bottomBarHeight) / 2 - _size / 2;
    });
  }

  Size get _screenSize {
    if (!mounted) return Size.zero;
    return MediaQuery.of(context).size;
  }

  bool _isVisible() {
    final s = _screenSize;
    return _x > -_size / 2 &&
        _x < s.width  - _size / 2 &&
        _y > -_size / 2 &&
        _y < s.height - _size / 2;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _isVisible();

    return Stack(
      fit: StackFit.expand,
      children: [
        // ── Meow đi lang thang ──────────────────────────
        AnimatedPositioned(
          duration: _isDragging
              ? Duration.zero
              : const Duration(milliseconds: 16),
          left: _x,
          top:  _y,
          child: GestureDetector(
            onPanStart: (_) {
              _moveTimer?.cancel();
              setState(() {
                _isDragging     = true;
                _characterState = CharacterState.walking;
              });
            },
            onPanUpdate: (d) {
              final s = _screenSize;
              setState(() {
                _x = (_x + d.delta.dx).clamp(_margin, s.width  - _size - _margin);
                _y = (_y + d.delta.dy).clamp(_margin, s.height - _size - _margin - _bottomBarHeight);
              });
            },
            onPanEnd: (d) {
              // Ném Meow theo hướng kéo
              final vel = d.velocity.pixelsPerSecond;
              setState(() {
                _isDragging = false;
                _vx = (vel.dx / 60).clamp(-2.5, 2.5);
                _vy = (vel.dy / 60).clamp(-2.5, 2.5);
                if (_vx.abs() < 0.3 && _vy.abs() < 0.3) {
                  _vx = (_rng.nextDouble() - 0.5) * 2;
                  _vy = (_rng.nextDouble() - 0.5) * 2;
                }
                _clampSpeed();
              });
              _startWalking();
            },
            onTap: _openChat,
            child: AnimatedBuilder(
              animation: _bounceAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(0, _isResting ? _bounceAnim.value : 0),
                child: child,
              ),
              child: Transform.scale(
                scaleX: _facingRight ? 1 : -1,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Nhân vật
                    MeowCharacter(
                      state:        _displayState,
                      size:         _size,
                      primaryColor: const Color(0xFF6C63FF),
                      skinColor:    const Color(0xFFFFD0A0),
                      accentColor:  const Color(0xFFFF6584),
                    ),
                    // Shadow
                    Positioned(
                      bottom: -4,
                      child: Container(
                        width: _size * 0.5, height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.black.withValues(alpha: 0.10),
                        ),
                      ),
                    ),
                    // Badge thông báo
                    if (_unreadCount > 0)
                      Positioned(
                        top: 0, right: 0,
                        child: Transform.scale(
                          scaleX: _facingRight ? 1 : -1,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.5, end: 1.0),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.elasticOut,
                            builder: (_, s, child) =>
                                Transform.scale(scale: s, child: child),
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(
                                  color: const Color(0xFFFF416C).withValues(alpha: 0.5),
                                  blurRadius: 6, spreadRadius: 1,
                                )],
                              ),
                              child: Center(
                                child: Text(
                                  _unreadCount > 9 ? '9+' : '$_unreadCount',
                                  style: const TextStyle(
                                    color: Colors.white, fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // ── Fallback button khi Meow ra ngoài màn hình ──
        if (!visible)
          Positioned(
            bottom: 100, right: 16,
            child: _FallbackButton(
              unreadCount: _unreadCount,
              pulseAnim:   _pulseAnim,
              onTap:       _openChat,
              onRestore:   _snapToCenter,
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Fallback button
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackButton extends StatelessWidget {
  final int              unreadCount;
  final Animation<double> pulseAnim;
  final VoidCallback     onTap;
  final VoidCallback     onRestore;

  const _FallbackButton({
    required this.unreadCount,
    required this.pulseAnim,
    required this.onTap,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Nút "Tìm Meow"
        GestureDetector(
          onTap: onRestore,
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.my_location_rounded, color: Colors.white, size: 12),
                SizedBox(width: 4),
                Text('Tìm Meow',
                    style: TextStyle(
                      color: Colors.white, fontSize: 11,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
        ),
        // Nút chat
        AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, child) =>
              Transform.scale(scale: pulseAnim.value, child: child),
          child: GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF6C63FF), Color(0xFF764ba2)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(
                      color: const Color(0xFF6C63FF).withValues(alpha: 0.45),
                      blurRadius: 14, spreadRadius: 2,
                      offset: const Offset(0, 4),
                    )],
                  ),
                  child: const Center(
                    child: Text('😺', style: TextStyle(fontSize: 26)),
                  ),
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -2, right: -2,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 9 ? '9+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white, fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
