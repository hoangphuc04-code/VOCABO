import 'dart:math';
import 'package:flutter/material.dart';
import 'character_animations.dart';
import 'meow_painter.dart';

/// Widget nhân vật Meow 2D game hoàn chỉnh
/// Có đầy đủ tay chân, đuôi, tai với skeleton animation
class MeowCharacter extends StatefulWidget {
  /// Trạng thái animation hiện tại
  final CharacterState state;

  /// Kích thước nhân vật (canvas)
  final double size;

  /// Màu chính (thân, tay, chân)
  final Color primaryColor;

  /// Màu da (bàn tay, mặt)
  final Color skinColor;

  /// Màu nhấn (tai, cổ áo, đuôi tip)
  final Color accentColor;

  const MeowCharacter({
    super.key,
    this.state = CharacterState.idle,
    this.size = 160,
    this.primaryColor = const Color(0xFF6C63FF),
    this.skinColor = const Color(0xFFFFD0A0),
    this.accentColor = const Color(0xFFFF6584),
  });

  @override
  State<MeowCharacter> createState() => _MeowCharacterState();
}

class _MeowCharacterState extends State<MeowCharacter>
    with TickerProviderStateMixin {
  late AnimationController _poseCtrl;
  late Animation<double> _poseCurve;

  // Controller nhắm mắt độc lập
  late AnimationController _blinkCtrl;
  late Animation<double> _blinkAnim;

  CharacterState _currentState = CharacterState.idle;
  SkeletonPose _currentPose = CharacterPoses.idleA;

  final Random _rng = Random();
  double _eyeBlink = 0;

  @override
  void initState() {
    super.initState();
    _currentState = widget.state;
    _setupPoseController(_currentState);
    _setupBlinkController();
    _scheduleNextBlink();
  }

  void _setupPoseController(CharacterState state) {
    final (poseA, poseB) = CharacterPoses.forState(state);
    final duration = CharacterPoses.durationFor(state);

    _poseCtrl = AnimationController(vsync: this, duration: duration)
      ..repeat(reverse: true);

    _poseCurve = CurvedAnimation(
      parent: _poseCtrl,
      curve: state == CharacterState.walking
          ? Curves.easeInOut
          : state == CharacterState.jumping || state == CharacterState.excited
              ? Curves.elasticOut
              : Curves.easeInOutSine,
    );

    _poseCtrl.addListener(() {
      if (!mounted) return;
      setState(() {
        _currentPose = SkeletonPose.lerp(poseA, poseB, _poseCurve.value);
      });
    });
  }

  void _setupBlinkController() {
    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _blinkAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _blinkCtrl, curve: Curves.easeInOut),
    );
    _blinkCtrl.addListener(() {
      if (mounted) setState(() => _eyeBlink = _blinkAnim.value);
    });
  }

  void _scheduleNextBlink() {
    Future.delayed(Duration(milliseconds: 2000 + _rng.nextInt(3000)), () {
      if (!mounted) return;
      _blinkCtrl.forward().then((_) {
        _blinkCtrl.reverse().then((_) => _scheduleNextBlink());
      });
    });
  }

  @override
  void didUpdateWidget(MeowCharacter old) {
    super.didUpdateWidget(old);
    if (old.state != widget.state) {
      _poseCtrl.dispose();
      _currentState = widget.state;
      _setupPoseController(widget.state);
    }
  }

  @override
  void dispose() {
    _poseCtrl.dispose();
    _blinkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Canvas rộng hơn cao để chứa đuôi và tay vươn ra hai bên
    // Tỉ lệ 1.4:1 (width:height) phù hợp với skeleton chibi
    return SizedBox(
      width: widget.size * 1.4,
      height: widget.size,
      child: CustomPaint(
        painter: MeowPainter(
          pose: _currentPose,
          state: _currentState,
          eyeBlink: _eyeBlink,
          primaryColor: widget.primaryColor,
          skinColor: widget.skinColor,
          accentColor: widget.accentColor,
        ),
      ),
    );
  }
}

/// Phiên bản nổi (Overlay) có thể kéo thả - dùng trong Scaffold overlay
class FloatingMeowCharacter extends StatefulWidget {
  final CharacterState initialState;
  final VoidCallback? onTap;

  const FloatingMeowCharacter({
    super.key,
    this.initialState = CharacterState.idle,
    this.onTap,
  });

  @override
  State<FloatingMeowCharacter> createState() => _FloatingMeowCharacterState();
}

class _FloatingMeowCharacterState extends State<FloatingMeowCharacter> {
  double _top = 480;
  double _left = 260;
  CharacterState _state = CharacterState.idle;

  @override
  void initState() {
    super.initState();
    _state = widget.initialState;
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _top,
      left: _left,
      child: GestureDetector(
        onPanStart: (_) {
          setState(() => _state = CharacterState.walking);
        },
        onPanUpdate: (details) {
          setState(() {
            _left += details.delta.dx;
            _top += details.delta.dy;
          });
        },
        onPanEnd: (_) {
          setState(() => _state = widget.initialState);
        },
        onTap: () {
          setState(() => _state = CharacterState.excited);
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (mounted) setState(() => _state = widget.initialState);
          });
          widget.onTap?.call();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MeowCharacter(
              state: _state,
              size: 120,
              primaryColor: const Color(0xFF6C63FF),
              skinColor: const Color(0xFFFFD0A0),
              accentColor: const Color(0xFFFF6584),
            ),
            // Shadow dưới nhân vật
            Container(
              width: 50,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.black.withValues(alpha: 0.13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
