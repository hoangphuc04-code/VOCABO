import 'dart:math';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ChibiCharacterWidget — Nhân vật chibi có đầy đủ chân tay, animation đi bộ,
// nhảy, vẫy tay. Phong cách Avatar / Adorable Home / Nông trại vui vẻ.
// ─────────────────────────────────────────────────────────────────────────────

enum CharacterGender { female, male }
enum CharacterAction { idle, walk, jump, wave }

class ChibiCharacterWidget extends StatefulWidget {
  final CharacterGender gender;
  final CharacterAction action;
  final bool facingRight;
  final double size;

  const ChibiCharacterWidget({
    super.key,
    this.gender = CharacterGender.female,
    this.action = CharacterAction.idle,
    this.facingRight = true,
    this.size = 80,
  });

  @override
  State<ChibiCharacterWidget> createState() => _ChibiCharacterWidgetState();
}

class _ChibiCharacterWidgetState extends State<ChibiCharacterWidget>
    with TickerProviderStateMixin {
  // Body bounce (idle / walk)
  late AnimationController _bodyCtrl;
  late Animation<double> _bodyAnim;

  // Leg swing (walk)
  late AnimationController _legCtrl;
  late Animation<double> _legAnim;

  // Arm wave
  late AnimationController _armCtrl;
  late Animation<double> _armAnim;

  // Jump
  late AnimationController _jumpCtrl;
  late Animation<double> _jumpAnim;

  @override
  void initState() {
    super.initState();

    _bodyCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _bodyAnim = Tween<double>(begin: 0, end: -3).animate(
      CurvedAnimation(parent: _bodyCtrl, curve: Curves.easeInOut),
    );

    _legCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);
    _legAnim = Tween<double>(begin: -0.4, end: 0.4).animate(
      CurvedAnimation(parent: _legCtrl, curve: Curves.easeInOut),
    );

    _armCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _armAnim = Tween<double>(begin: -0.3, end: 0.5).animate(
      CurvedAnimation(parent: _armCtrl, curve: Curves.easeInOut),
    );

    _jumpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
    _jumpAnim = Tween<double>(begin: 0, end: -18).animate(
      CurvedAnimation(parent: _jumpCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _bodyCtrl.dispose();
    _legCtrl.dispose();
    _armCtrl.dispose();
    _jumpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_bodyAnim, _legAnim, _armAnim, _jumpAnim]),
      builder: (_, __) {
        double jumpOffset = 0;
        double bodyBounce = 0;
        double legAngle = 0;
        double armAngle = 0;

        switch (widget.action) {
          case CharacterAction.idle:
            bodyBounce = _bodyAnim.value;
            break;
          case CharacterAction.walk:
            bodyBounce = _bodyAnim.value * 0.5;
            legAngle = _legAnim.value;
            armAngle = -_legAnim.value * 0.6;
            break;
          case CharacterAction.jump:
            jumpOffset = _jumpAnim.value;
            legAngle = -0.3;
            break;
          case CharacterAction.wave:
            bodyBounce = _bodyAnim.value * 0.5;
            armAngle = _armAnim.value;
            break;
        }

        return Transform.translate(
          offset: Offset(0, jumpOffset + bodyBounce),
          child: Transform.scale(
            scaleX: widget.facingRight ? 1 : -1,
            child: SizedBox(
              width: widget.size,
              height: widget.size * 1.6,
              child: CustomPaint(
                painter: _ChibiPainter(
                  gender: widget.gender,
                  legAngle: legAngle,
                  armAngle: armAngle,
                  action: widget.action,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ChibiPainter — vẽ nhân vật chibi đầy đủ chân tay
// ─────────────────────────────────────────────────────────────────────────────

class _ChibiPainter extends CustomPainter {
  final CharacterGender gender;
  final double legAngle;
  final double armAngle;
  final CharacterAction action;

  const _ChibiPainter({
    required this.gender,
    required this.legAngle,
    required this.armAngle,
    required this.action,
  });

  // ── Color palette ──────────────────────────────────────────────────────────
  Color get _skinColor => const Color(0xFFFFD5B0);
  Color get _skinDark => const Color(0xFFEFB98A);
  Color get _hairColor => gender == CharacterGender.female
      ? const Color(0xFF8B4513)
      : const Color(0xFF3D2B1F);
  Color get _shirtColor => gender == CharacterGender.female
      ? const Color(0xFFFF6B9D)
      : const Color(0xFF4A90D9);
  Color get _shirtDark => gender == CharacterGender.female
      ? const Color(0xFFE0558A)
      : const Color(0xFF3070B8);
  Color get _pantsColor => gender == CharacterGender.female
      ? const Color(0xFF9B59B6)
      : const Color(0xFF2C3E50);
  Color get _pantsDark => gender == CharacterGender.female
      ? const Color(0xFF7D3C98)
      : const Color(0xFF1A252F);
  Color get _shoeColor => gender == CharacterGender.female
      ? const Color(0xFFFF6B9D)
      : const Color(0xFF2C3E50);
  Color get _eyeColor => const Color(0xFF2C1810);
  Color get _cheekColor => const Color(0xFFFFB3C6).withValues(alpha: 0.7);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Scale reference: head center at (w*0.5, h*0.18), total height = h
    final headCX = w * 0.5;
    final headCY = h * 0.18;
    final headR = w * 0.28;

    // Body top = headCY + headR, body bottom = h*0.62
    final bodyTop = headCY + headR * 0.85;
    final bodyBot = h * 0.62;
    final bodyCX = headCX;

    // ── Draw order: legs → body → arms → head (painter's algorithm) ──────────

    _drawLegs(canvas, size, bodyCX, bodyBot);
    _drawBody(canvas, size, bodyCX, bodyTop, bodyBot);
    _drawArms(canvas, size, bodyCX, bodyTop, bodyBot);
    _drawHead(canvas, size, headCX, headCY, headR);
  }

  // ── LEGS ───────────────────────────────────────────────────────────────────
  void _drawLegs(Canvas canvas, Size size, double cx, double bodyBot) {
    final h = size.height;
    final legLen = h * 0.28;
    final legW = size.width * 0.11;
    final footW = size.width * 0.14;
    final footH = size.height * 0.055;

    // Left leg
    _drawLeg(
      canvas,
      Offset(cx - size.width * 0.1, bodyBot),
      legLen, legW, footW, footH,
      -legAngle,
    );
    // Right leg
    _drawLeg(
      canvas,
      Offset(cx + size.width * 0.1, bodyBot),
      legLen, legW, footW, footH,
      legAngle,
    );
  }

  void _drawLeg(Canvas canvas, Offset top, double len, double legW,
      double footW, double footH, double angle) {
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(angle);

    // Upper leg (pants)
    final upperLen = len * 0.55;
    final upperPaint = Paint()..color = pantsColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-legW / 2, 0, legW, upperLen),
        Radius.circular(legW / 2),
      ),
      upperPaint,
    );

    // Lower leg (pants darker)
    final lowerPaint = Paint()..color = pantsDark;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-legW / 2 + 1, upperLen - 2, legW - 2, len * 0.45 + 2),
        Radius.circular(legW / 2),
      ),
      lowerPaint,
    );

    // Shoe
    final shoePaint = Paint()..color = shoeColor;
    final shoeRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(-footW / 2, len - footH + 2, footW, footH),
      const Radius.circular(5),
    );
    canvas.drawRRect(shoeRect, shoePaint);

    // Shoe highlight
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-footW / 2 + 2, len - footH + 2, footW * 0.4, footH * 0.4),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );

    canvas.restore();
  }

  // ── BODY ───────────────────────────────────────────────────────────────────
  void _drawBody(Canvas canvas, Size size, double cx, double top, double bot) {
    final bodyW = size.width * 0.44;
    final bodyH = bot - top;

    // Shirt body
    final shirtPaint = Paint()..color = shirtColor;
    final bodyPath = Path()
      ..moveTo(cx - bodyW / 2, top + bodyH * 0.1)
      ..quadraticBezierTo(cx - bodyW / 2 - 4, top + bodyH * 0.5,
          cx - bodyW / 2 + 2, bot)
      ..lineTo(cx + bodyW / 2 - 2, bot)
      ..quadraticBezierTo(cx + bodyW / 2 + 4, top + bodyH * 0.5,
          cx + bodyW / 2, top + bodyH * 0.1)
      ..quadraticBezierTo(cx, top - 4, cx - bodyW / 2, top + bodyH * 0.1)
      ..close();
    canvas.drawPath(bodyPath, shirtPaint);

    // Shirt shadow (right side)
    final shadowPaint = Paint()
      ..color = shirtDark.withValues(alpha: 0.5);
    final shadowPath = Path()
      ..moveTo(cx + bodyW * 0.1, top + bodyH * 0.1)
      ..quadraticBezierTo(cx + bodyW / 2 + 4, top + bodyH * 0.5,
          cx + bodyW / 2 - 2, bot)
      ..lineTo(cx + bodyW * 0.1, bot)
      ..close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Collar
    final collarPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, top + bodyH * 0.08),
        width: bodyW * 0.35,
        height: bodyH * 0.12,
      ),
      collarPaint,
    );

    // Belt / waist line
    if (gender == CharacterGender.female) {
      // Skirt-like waist detail
      final beltPaint = Paint()..color = pantsColor;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bodyW / 2 + 2, bot - bodyH * 0.22,
              bodyW - 4, bodyH * 0.22),
          const Radius.circular(4),
        ),
        beltPaint,
      );
    } else {
      // Belt
      final beltPaint = Paint()..color = const Color(0xFF5D4037);
      canvas.drawRect(
        Rect.fromLTWH(cx - bodyW / 2 + 2, bot - bodyH * 0.18, bodyW - 4, 5),
        beltPaint,
      );
      // Belt buckle
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 5, bot - bodyH * 0.18 - 1, 10, 7),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFD4A843),
      );
    }
  }

  // ── ARMS ───────────────────────────────────────────────────────────────────
  void _drawArms(Canvas canvas, Size size, double cx, double top, double bot) {
    final bodyW = size.width * 0.44;
    final armLen = (bot - top) * 0.75;
    final armW = size.width * 0.09;
    final shoulderY = top + (bot - top) * 0.12;

    // Left arm
    _drawArm(
      canvas,
      Offset(cx - bodyW / 2 + 2, shoulderY),
      armLen, armW,
      action == CharacterAction.wave ? armAngle + 0.2 : armAngle - 0.15,
      isLeft: true,
    );

    // Right arm (wave arm)
    _drawArm(
      canvas,
      Offset(cx + bodyW / 2 - 2, shoulderY),
      armLen, armW,
      action == CharacterAction.wave ? -armAngle - 0.8 : -armAngle + 0.15,
      isLeft: false,
    );
  }

  void _drawArm(Canvas canvas, Offset shoulder, double len, double armW,
      double angle, {required bool isLeft}) {
    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);

    // Upper arm
    final upperLen = len * 0.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-armW / 2, 0, armW, upperLen),
        Radius.circular(armW / 2),
      ),
      Paint()..color = shirtColor,
    );

    // Elbow joint
    canvas.drawCircle(
      Offset(0, upperLen),
      armW * 0.55,
      Paint()..color = skinColor,
    );

    // Forearm
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-armW / 2 + 1, upperLen - 2, armW - 2, len * 0.5),
        Radius.circular(armW / 2),
      ),
      Paint()..color = skinColor,
    );

    // Hand
    canvas.drawCircle(
      Offset(0, len),
      armW * 0.65,
      Paint()..color = skinColor,
    );
    // Hand shadow
    canvas.drawCircle(
      Offset(armW * 0.15, len + armW * 0.1),
      armW * 0.35,
      Paint()..color = skinDark.withValues(alpha: 0.4),
    );

    canvas.restore();
  }

  // ── HEAD ───────────────────────────────────────────────────────────────────
  void _drawHead(Canvas canvas, Size size, double cx, double cy, double r) {
    // Neck
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - r * 0.22, cy + r * 0.75, r * 0.44, r * 0.35),
        Radius.circular(r * 0.15),
      ),
      Paint()..color = skinColor,
    );

    // Head base (slightly oval, chibi style)
    final headPaint = Paint()..color = skinColor;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 1.9),
      headPaint,
    );

    // Head shadow (right side)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.2, cy + r * 0.1),
          width: r * 1.1, height: r * 1.5),
      Paint()..color = skinDark.withValues(alpha: 0.18),
    );

    // ── Hair ──────────────────────────────────────────────────────────────────
    _drawHair(canvas, cx, cy, r);

    // ── Eyes ──────────────────────────────────────────────────────────────────
    _drawEyes(canvas, cx, cy, r);

    // ── Nose ──────────────────────────────────────────────────────────────────
    canvas.drawCircle(
      Offset(cx + r * 0.08, cy + r * 0.18),
      r * 0.055,
      Paint()..color = skinDark.withValues(alpha: 0.5),
    );

    // ── Mouth ─────────────────────────────────────────────────────────────────
    final mouthPaint = Paint()
      ..color = const Color(0xFFD2691E)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final mouthPath = Path()
      ..moveTo(cx - r * 0.18, cy + r * 0.32)
      ..quadraticBezierTo(cx, cy + r * 0.46, cx + r * 0.18, cy + r * 0.32);
    canvas.drawPath(mouthPath, mouthPaint);

    // ── Cheeks ────────────────────────────────────────────────────────────────
    canvas.drawCircle(Offset(cx - r * 0.52, cy + r * 0.22), r * 0.18, Paint()..color = cheekColor);
    canvas.drawCircle(Offset(cx + r * 0.52, cy + r * 0.22), r * 0.18, Paint()..color = cheekColor);
  }

  void _drawHair(Canvas canvas, double cx, double cy, double r) {
    final hairPaint = Paint()..color = hairColor;

    if (gender == CharacterGender.female) {
      // Top hair
      final topHairPath = Path()
        ..moveTo(cx - r * 0.95, cy - r * 0.1)
        ..quadraticBezierTo(cx - r * 0.8, cy - r * 1.15, cx, cy - r * 1.1)
        ..quadraticBezierTo(cx + r * 0.8, cy - r * 1.15, cx + r * 0.95, cy - r * 0.1)
        ..quadraticBezierTo(cx + r * 0.7, cy - r * 0.5, cx, cy - r * 0.55)
        ..quadraticBezierTo(cx - r * 0.7, cy - r * 0.5, cx - r * 0.95, cy - r * 0.1)
        ..close();
      canvas.drawPath(topHairPath, hairPaint);

      // Side hair strands (pigtail style)
      final leftStrand = Path()
        ..moveTo(cx - r * 0.9, cy - r * 0.05)
        ..quadraticBezierTo(cx - r * 1.2, cy + r * 0.4, cx - r * 0.85, cy + r * 0.7)
        ..quadraticBezierTo(cx - r * 0.7, cy + r * 0.5, cx - r * 0.75, cy + r * 0.1)
        ..close();
      canvas.drawPath(leftStrand, hairPaint);

      final rightStrand = Path()
        ..moveTo(cx + r * 0.9, cy - r * 0.05)
        ..quadraticBezierTo(cx + r * 1.2, cy + r * 0.4, cx + r * 0.85, cy + r * 0.7)
        ..quadraticBezierTo(cx + r * 0.7, cy + r * 0.5, cx + r * 0.75, cy + r * 0.1)
        ..close();
      canvas.drawPath(rightStrand, hairPaint);

      // Hair highlight
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - r * 0.15, cy - r * 0.7),
            width: r * 0.4, height: r * 0.2),
        Paint()..color = Colors.white.withValues(alpha: 0.3),
      );
    } else {
      // Male short hair
      final topHairPath = Path()
        ..moveTo(cx - r * 0.95, cy - r * 0.05)
        ..quadraticBezierTo(cx - r * 0.85, cy - r * 1.05, cx, cy - r * 1.0)
        ..quadraticBezierTo(cx + r * 0.85, cy - r * 1.05, cx + r * 0.95, cy - r * 0.05)
        ..quadraticBezierTo(cx + r * 0.6, cy - r * 0.45, cx, cy - r * 0.5)
        ..quadraticBezierTo(cx - r * 0.6, cy - r * 0.45, cx - r * 0.95, cy - r * 0.05)
        ..close();
      canvas.drawPath(topHairPath, hairPaint);

      // Side burns
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - r * 0.95, cy - r * 0.1, r * 0.18, r * 0.4),
          const Radius.circular(4),
        ),
        hairPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + r * 0.77, cy - r * 0.1, r * 0.18, r * 0.4),
          const Radius.circular(4),
        ),
        hairPaint,
      );
    }
  }

  void _drawEyes(Canvas canvas, double cx, double cy, double r) {
    final eyeY = cy - r * 0.05;
    final eyeSpacing = r * 0.38;
    final eyeW = r * 0.28;
    final eyeH = r * 0.32;

    for (final side in [-1.0, 1.0]) {
      final ex = cx + side * eyeSpacing;

      // Eye white
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex, eyeY), width: eyeW, height: eyeH),
        Paint()..color = Colors.white,
      );

      // Iris
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex + side * 1, eyeY + 1),
            width: eyeW * 0.72, height: eyeH * 0.72),
        Paint()..color = const Color(0xFF4A90D9),
      );

      // Pupil
      canvas.drawOval(
        Rect.fromCenter(center: Offset(ex + side * 1.5, eyeY + 1.5),
            width: eyeW * 0.38, height: eyeH * 0.38),
        Paint()..color = eyeColor,
      );

      // Eye shine (2 dots)
      canvas.drawCircle(
        Offset(ex + side * 0.5, eyeY - eyeH * 0.1),
        eyeW * 0.12,
        Paint()..color = Colors.white,
      );
      canvas.drawCircle(
        Offset(ex + side * 1.8, eyeY + eyeH * 0.1),
        eyeW * 0.07,
        Paint()..color = Colors.white,
      );

      // Eyelash (top)
      final lashPaint = Paint()
        ..color = eyeColor
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(ex, eyeY), width: eyeW + 2, height: eyeH + 2),
        -pi, pi, false, lashPaint,
      );

      // Eyebrow
      final browPaint = Paint()
        ..color = hairColor
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final browPath = Path()
        ..moveTo(ex - eyeW * 0.55, eyeY - eyeH * 0.75)
        ..quadraticBezierTo(ex, eyeY - eyeH * 0.95, ex + eyeW * 0.55, eyeY - eyeH * 0.75);
      canvas.drawPath(browPath, browPaint);
    }
  }

  // ── Getters (shorthand) ────────────────────────────────────────────────────
  Color get skinColor => _skinColor;
  Color get skinDark => _skinDark;
  Color get hairColor => _hairColor;
  Color get shirtColor => _shirtColor;
  Color get shirtDark => _shirtDark;
  Color get pantsColor => _pantsColor;
  Color get pantsDark => _pantsDark;
  Color get shoeColor => _shoeColor;
  Color get eyeColor => _eyeColor;
  Color get cheekColor => _cheekColor;

  @override
  bool shouldRepaint(_ChibiPainter old) =>
      old.legAngle != legAngle ||
      old.armAngle != armAngle ||
      old.action != action ||
      old.gender != gender;
}
