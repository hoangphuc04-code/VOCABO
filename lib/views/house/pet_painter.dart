import 'dart:math';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

enum PetAction { idle, walk, eat, play, sleep, happy, sad, excited }

enum PetSpeciesType { cat, dog, rabbit, bear, fox, dragon, unicorn, penguin }

// ---------------------------------------------------------------------------
// Helper functions
// ---------------------------------------------------------------------------

PetSpeciesType petSpeciesFromString(String s) {
  switch (s.toLowerCase()) {
    case 'dog':
      return PetSpeciesType.dog;
    case 'rabbit':
      return PetSpeciesType.rabbit;
    case 'bear':
      return PetSpeciesType.bear;
    case 'fox':
      return PetSpeciesType.fox;
    case 'dragon':
      return PetSpeciesType.dragon;
    case 'unicorn':
      return PetSpeciesType.unicorn;
    case 'penguin':
      return PetSpeciesType.penguin;
    case 'cat':
    default:
      return PetSpeciesType.cat;
  }
}

PetAction petActionFromMood(double happiness, double hunger) {
  if (hunger < 20) return PetAction.sleep;
  if (happiness < 30) return PetAction.sad;
  if (hunger < 50 && Random().nextBool()) return PetAction.eat;
  if (happiness > 80) return PetAction.happy;
  return PetAction.idle;
}

// ---------------------------------------------------------------------------
// AnimatedPetWidget
// ---------------------------------------------------------------------------

class AnimatedPetWidget extends StatefulWidget {
  final PetSpeciesType species;
  final PetAction action;
  final double size;
  final bool facingRight;
  final double happiness;
  final double hunger;

  const AnimatedPetWidget({
    super.key,
    required this.species,
    required this.action,
    this.size = 80,
    this.facingRight = true,
    this.happiness = 70,
    this.hunger = 70,
  });

  @override
  State<AnimatedPetWidget> createState() => _AnimatedPetWidgetState();
}

class _AnimatedPetWidgetState extends State<AnimatedPetWidget>
    with TickerProviderStateMixin {
  late AnimationController _bounceCtrl;
  late AnimationController _walkCtrl;
  late AnimationController _tailCtrl;
  late AnimationController _blinkCtrl;
  late AnimationController _eatCtrl;
  late AnimationController _excitedCtrl;

  late Animation<double> _bounce;
  late Animation<double> _walk;
  late Animation<double> _tail;
  late Animation<double> _blink;
  late Animation<double> _eat;
  late Animation<double> _excited;

  @override
  void initState() {
    super.initState();

    _bounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _walkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..repeat(reverse: true);

    _tailCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _blinkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..repeat(reverse: true);

    _eatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _excitedCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..repeat(reverse: true);

    _bounce = Tween<double>(begin: -3, end: 3).animate(
      CurvedAnimation(parent: _bounceCtrl, curve: Curves.easeInOut),
    );
    _walk = Tween<double>(begin: -0.4, end: 0.4).animate(
      CurvedAnimation(parent: _walkCtrl, curve: Curves.easeInOut),
    );
    _tail = Tween<double>(begin: -0.5, end: 0.5).animate(
      CurvedAnimation(parent: _tailCtrl, curve: Curves.easeInOut),
    );
    _blink = Tween<double>(begin: 0, end: 0).animate(_blinkCtrl);
    _eat = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _eatCtrl, curve: Curves.easeInOut),
    );
    _excited = Tween<double>(begin: -1, end: 1).animate(
      CurvedAnimation(parent: _excitedCtrl, curve: Curves.easeInOut),
    );

    _setupBlinkAnimation();
    _updateAnimationsForAction();
  }

  void _setupBlinkAnimation() {
    // Blink every ~3 seconds: mostly 0 (open), briefly 1 (closed)
    _blinkCtrl.duration = const Duration(milliseconds: 3000);
    _blink = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(0), weight: 90),
      TweenSequenceItem(
          tween: Tween<double>(begin: 0, end: 1), weight: 5),
      TweenSequenceItem(
          tween: Tween<double>(begin: 1, end: 0), weight: 5),
    ]).animate(_blinkCtrl);
    _blinkCtrl.repeat();
  }

  void _updateAnimationsForAction() {
    switch (widget.action) {
      case PetAction.walk:
        _walkCtrl.repeat(reverse: true);
        _bounceCtrl.repeat(reverse: true);
        break;
      case PetAction.eat:
        _eatCtrl.repeat(reverse: true);
        _walkCtrl.stop();
        break;
      case PetAction.sleep:
        _bounceCtrl.stop();
        _walkCtrl.stop();
        _tailCtrl.stop();
        _excitedCtrl.stop();
        break;
      case PetAction.excited:
        _excitedCtrl.repeat(reverse: true);
        _bounceCtrl.repeat(reverse: true);
        _tailCtrl.repeat(reverse: true);
        break;
      case PetAction.happy:
        _bounceCtrl.repeat(reverse: true);
        _tailCtrl.repeat(reverse: true);
        break;
      case PetAction.sad:
        _bounceCtrl.stop();
        _tailCtrl.stop();
        break;
      case PetAction.idle:
      case PetAction.play:
        _bounceCtrl.repeat(reverse: true);
        _tailCtrl.repeat(reverse: true);
        break;
    }
  }

  @override
  void didUpdateWidget(AnimatedPetWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.action != widget.action) {
      _updateAnimationsForAction();
    }
  }

  @override
  void dispose() {
    _bounceCtrl.dispose();
    _walkCtrl.dispose();
    _tailCtrl.dispose();
    _blinkCtrl.dispose();
    _eatCtrl.dispose();
    _excitedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.4,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _bounce,
          _walk,
          _tail,
          _blink,
          _eat,
          _excited,
        ]),
        builder: (context, _) {
          return Transform.scale(
            scaleX: widget.facingRight ? 1 : -1,
            child: CustomPaint(
              painter: _PetPainter(
                species: widget.species,
                action: widget.action,
                bounceVal: _bounce.value,
                walkVal: _walk.value,
                tailVal: _tail.value,
                blinkVal: _blink.value,
                eatVal: _eat.value,
                excitedVal: _excited.value,
                happiness: widget.happiness,
                hunger: widget.hunger,
              ),
              size: Size(widget.size, widget.size * 1.4),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PetPainter CustomPainter
// ---------------------------------------------------------------------------

class _PetPainter extends CustomPainter {
  final PetSpeciesType species;
  final PetAction action;
  final double bounceVal;
  final double walkVal;
  final double tailVal;
  final double blinkVal;
  final double eatVal;
  final double excitedVal;
  final double happiness;
  final double hunger;

  const _PetPainter({
    required this.species,
    required this.action,
    required this.bounceVal,
    required this.walkVal,
    required this.tailVal,
    required this.blinkVal,
    required this.eatVal,
    required this.excitedVal,
    required this.happiness,
    required this.hunger,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawShadow(canvas, size);
    switch (species) {
      case PetSpeciesType.cat:
        _drawCat(canvas, size);
        break;
      case PetSpeciesType.dog:
        _drawDog(canvas, size);
        break;
      case PetSpeciesType.rabbit:
        _drawRabbit(canvas, size);
        break;
      case PetSpeciesType.bear:
        _drawBear(canvas, size);
        break;
      case PetSpeciesType.fox:
        _drawFox(canvas, size);
        break;
      case PetSpeciesType.dragon:
        _drawDragon(canvas, size);
        break;
      case PetSpeciesType.unicorn:
        _drawUnicorn(canvas, size);
        break;
      case PetSpeciesType.penguin:
        _drawPenguin(canvas, size);
        break;
    }
  }

  @override
  bool shouldRepaint(_PetPainter old) {
    return old.bounceVal != bounceVal ||
        old.walkVal != walkVal ||
        old.tailVal != tailVal ||
        old.blinkVal != blinkVal ||
        old.eatVal != eatVal ||
        old.excitedVal != excitedVal ||
        old.happiness != happiness ||
        old.hunger != hunger ||
        old.species != species ||
        old.action != action;
  }

  // -------------------------------------------------------------------------
  // Shadow
  // -------------------------------------------------------------------------

  void _drawShadow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.5, size.height * 0.92),
        width: size.width * 0.55,
        height: size.height * 0.07,
      ),
      paint,
    );
  }

  // -------------------------------------------------------------------------
  // Helper drawing methods
  // -------------------------------------------------------------------------

  void _drawLeg(Canvas canvas, Offset top, double len, double width,
      double angle, Color color) {
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(angle);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, len / 2), width: width, height: len),
      Radius.circular(width / 2),
    );
    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  void _drawEye(Canvas canvas, Offset center, double radius, double blink) {
    // White sclera
    canvas.drawCircle(center, radius, Paint()..color = Colors.white);
    // Pupil – squish vertically when blinking
    final pupilH = radius * 1.2 * (1 - blink * 0.95);
    final pupilW = radius * 0.7;
    canvas.drawOval(
      Rect.fromCenter(
          center: center, width: pupilW * 2, height: max(pupilH * 2, 1)),
      Paint()..color = const Color(0xFF2D2D2D),
    );
    // Shine
    if (blink < 0.5) {
      canvas.drawCircle(
        Offset(center.dx + radius * 0.2, center.dy - radius * 0.2),
        radius * 0.2,
        Paint()..color = Colors.white,
      );
    }
    // Outline
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF2D2D2D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  void _drawSmile(Canvas canvas, Offset center, double radius, double happy) {
    final paint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    double curvature;
    if (happy > 70) {
      curvature = radius * 0.8;
    } else if (happy < 30) {
      curvature = -radius * 0.5;
    } else {
      curvature = radius * 0.2;
    }
    path.moveTo(center.dx - radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy + curvature,
        center.dx + radius, center.dy);
    canvas.drawPath(path, paint);
  }

  void _drawCatTail(Canvas canvas, Offset base, double wag, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(base.dx, base.dy);
    final ctrlX = base.dx + 30 + wag * 20;
    final ctrlY = base.dy - 30;
    final endX = base.dx + 20 + wag * 30;
    final endY = base.dy - 55;
    path.quadraticBezierTo(ctrlX, ctrlY, endX, endY);
    canvas.drawPath(path, paint);
    // Tip
    canvas.drawCircle(Offset(endX, endY), 5, Paint()..color = color);
  }

  void _drawCatEar(Canvas canvas, Offset tip, double size, bool isLeft) {
    final outerPaint = Paint()..color = const Color(0xFFFF9A5C);
    final innerPaint = Paint()..color = const Color(0xFFFFB3C6);
    final dx = isLeft ? -size * 0.5 : size * 0.5;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + dx - size * 0.3, tip.dy + size * 1.2)
      ..lineTo(tip.dx + dx + size * 0.3, tip.dy + size * 1.2)
      ..close();
    canvas.drawPath(path, outerPaint);
    final innerPath = Path()
      ..moveTo(tip.dx, tip.dy + size * 0.3)
      ..lineTo(tip.dx + dx - size * 0.15, tip.dy + size * 1.0)
      ..lineTo(tip.dx + dx + size * 0.15, tip.dy + size * 1.0)
      ..close();
    canvas.drawPath(innerPath, innerPaint);
  }

  void _drawCatNose(Canvas canvas, Offset center, double size) {
    final paint = Paint()..color = const Color(0xFFFF8FAB);
    final path = Path()
      ..moveTo(center.dx, center.dy + size)
      ..lineTo(center.dx - size, center.dy - size * 0.5)
      ..lineTo(center.dx + size, center.dy - size * 0.5)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawWhiskers(Canvas canvas, Offset nosePos, double headR) {
    final paint = Paint()
      ..color = const Color(0xFF2D2D2D).withOpacity(0.5)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    // Left whiskers
    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(nosePos.dx - headR * 0.1, nosePos.dy + i * headR * 0.1),
        Offset(nosePos.dx - headR * 0.8, nosePos.dy + i * headR * 0.15),
        paint,
      );
    }
    // Right whiskers
    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(nosePos.dx + headR * 0.1, nosePos.dy + i * headR * 0.1),
        Offset(nosePos.dx + headR * 0.8, nosePos.dy + i * headR * 0.15),
        paint,
      );
    }
  }

  // -------------------------------------------------------------------------
  // Cat
  // -------------------------------------------------------------------------

  void _drawCat(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shakeX = excitedVal * 3;

    final bodyCX = w * 0.5 + shakeX;
    final bodyCY = h * 0.58 + bounceVal;
    final bodyRX = w * 0.28;
    final bodyRY = h * 0.22;

    // Legs
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.07, walkVal, const Color(0xFFE8A87C));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.07, -walkVal, const Color(0xFFE8A87C));
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.065, -walkVal * 0.7, const Color(0xFFE8A87C));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.065, walkVal * 0.7, const Color(0xFFE8A87C));

    // Body
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY),
          width: bodyRX * 2,
          height: bodyRY * 2),
      Paint()..color = const Color(0xFFFF9A5C),
    );

    // Belly
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY + bodyRY * 0.1),
          width: bodyRX * 1.1,
          height: bodyRY * 1.1),
      Paint()..color = const Color(0xFFFFF0E0),
    );

    // Tail
    _drawCatTail(
        canvas, Offset(bodyCX + bodyRX * 0.9, bodyCY), tailVal, const Color(0xFFFF9A5C));

    // Head
    final headCX = bodyCX + eatVal * 4;
    final headCY = bodyCY - bodyRY - h * 0.14;
    final headR = w * 0.22;

    // Ears
    _drawCatEar(
        canvas, Offset(headCX - headR * 0.6, headCY - headR * 0.7), headR * 0.35, true);
    _drawCatEar(
        canvas, Offset(headCX + headR * 0.6, headCY - headR * 0.7), headR * 0.35, false);

    // Head circle
    canvas.drawCircle(
        Offset(headCX, headCY), headR, Paint()..color = const Color(0xFFFF9A5C));

    // Face marking
    canvas.drawCircle(Offset(headCX, headCY + headR * 0.1), headR * 0.65,
        Paint()..color = const Color(0xFFFFF0E0));

    // Eyes
    _drawEye(canvas, Offset(headCX - headR * 0.35, headCY - headR * 0.05),
        headR * 0.18, blinkVal);
    _drawEye(canvas, Offset(headCX + headR * 0.35, headCY - headR * 0.05),
        headR * 0.18, blinkVal);

    // Nose
    _drawCatNose(canvas, Offset(headCX, headCY + headR * 0.2), headR * 0.1);

    // Whiskers
    _drawWhiskers(canvas, Offset(headCX, headCY + headR * 0.2), headR);

    // Mouth
    _drawSmile(
        canvas, Offset(headCX, headCY + headR * 0.32), headR * 0.2, happiness);

    // Cheeks
    canvas.drawCircle(
        Offset(headCX - headR * 0.55, headCY + headR * 0.25),
        headR * 0.15,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.6));
    canvas.drawCircle(
        Offset(headCX + headR * 0.55, headCY + headR * 0.25),
        headR * 0.15,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.6));
  }

  // -------------------------------------------------------------------------
  // Dog
  // -------------------------------------------------------------------------

  void _drawDogTail(Canvas canvas, Offset base, double wag, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(base.dx, base.dy);
    path.quadraticBezierTo(
        base.dx + 15 + wag * 15, base.dy - 20, base.dx + 10 + wag * 20, base.dy - 35);
    canvas.drawPath(path, paint);
    canvas.drawCircle(
        Offset(base.dx + 10 + wag * 20, base.dy - 35), 4, Paint()..color = color);
  }

  void _drawDogEar(Canvas canvas, Offset top, double size, bool isLeft) {
    final paint = Paint()..color = const Color(0xFF8B5E3C);
    final dx = isLeft ? -size * 0.3 : size * 0.3;
    // Floppy drooping ear
    final path = Path()
      ..moveTo(top.dx - size * 0.4, top.dy)
      ..cubicTo(
          top.dx - size * 0.5 + dx, top.dy + size * 0.5,
          top.dx - size * 0.3 + dx, top.dy + size * 1.2,
          top.dx + dx, top.dy + size * 1.3)
      ..cubicTo(
          top.dx + size * 0.3 + dx, top.dy + size * 1.2,
          top.dx + size * 0.4 + dx, top.dy + size * 0.5,
          top.dx + size * 0.4, top.dy)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawDog(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shakeX = excitedVal * 3;
    final bodyCX = w * 0.5 + shakeX;
    final bodyCY = h * 0.58 + bounceVal;
    final bodyRX = w * 0.29;
    final bodyRY = h * 0.21;

    // Legs
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.19, w * 0.08, walkVal, const Color(0xFF8B5E3C));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.19, w * 0.08, -walkVal, const Color(0xFF8B5E3C));
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.17, w * 0.07, -walkVal * 0.7, const Color(0xFF8B5E3C));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.17, w * 0.07, walkVal * 0.7, const Color(0xFF8B5E3C));

    // Body
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY),
          width: bodyRX * 2,
          height: bodyRY * 2),
      Paint()..color = const Color(0xFFA0714F),
    );

    // Belly
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY + bodyRY * 0.1),
          width: bodyRX * 1.0,
          height: bodyRY * 1.0),
      Paint()..color = const Color(0xFFF5DEB3),
    );

    // Tail
    _drawDogTail(
        canvas, Offset(bodyCX + bodyRX * 0.9, bodyCY - bodyRY * 0.2), tailVal, const Color(0xFFA0714F));

    // Head
    final headCX = bodyCX + eatVal * 4;
    final headCY = bodyCY - bodyRY - h * 0.13;
    final headR = w * 0.23;

    // Floppy ears (behind head)
    _drawDogEar(canvas, Offset(headCX - headR * 0.7, headCY - headR * 0.4),
        headR * 0.7, true);
    _drawDogEar(canvas, Offset(headCX + headR * 0.3, headCY - headR * 0.4),
        headR * 0.7, false);

    // Head
    canvas.drawCircle(
        Offset(headCX, headCY), headR, Paint()..color = const Color(0xFFA0714F));

    // Muzzle
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(headCX, headCY + headR * 0.25),
          width: headR * 1.1,
          height: headR * 0.7),
      Paint()..color = const Color(0xFFF5DEB3),
    );

    // Eyes
    _drawEye(canvas, Offset(headCX - headR * 0.35, headCY - headR * 0.1),
        headR * 0.18, blinkVal);
    _drawEye(canvas, Offset(headCX + headR * 0.35, headCY - headR * 0.1),
        headR * 0.18, blinkVal);

    // Nose
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(headCX, headCY + headR * 0.15),
          width: headR * 0.3,
          height: headR * 0.2),
      Paint()..color = const Color(0xFF2D2D2D),
    );

    // Mouth
    _drawSmile(
        canvas, Offset(headCX, headCY + headR * 0.38), headR * 0.22, happiness);

    // Cheeks
    canvas.drawCircle(
        Offset(headCX - headR * 0.6, headCY + headR * 0.3),
        headR * 0.14,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.5));
    canvas.drawCircle(
        Offset(headCX + headR * 0.6, headCY + headR * 0.3),
        headR * 0.14,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.5));
  }

  // -------------------------------------------------------------------------
  // Rabbit
  // -------------------------------------------------------------------------

  void _drawRabbitTail(Canvas canvas, Offset base, Color color) {
    canvas.drawCircle(base, 7, Paint()..color = Colors.white);
    canvas.drawCircle(base, 7,
        Paint()
          ..color = Colors.white.withOpacity(0.6)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  void _drawRabbit(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shakeX = excitedVal * 3;
    final bodyCX = w * 0.5 + shakeX;
    final bodyCY = h * 0.60 + bounceVal;
    final bodyRX = w * 0.25;
    final bodyRY = h * 0.20;

    // Legs
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.17, w * 0.07, walkVal, const Color(0xFFFFD6E0));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.17, w * 0.07, -walkVal, const Color(0xFFFFD6E0));
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.15, w * 0.065, -walkVal * 0.7, const Color(0xFFFFD6E0));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.15, w * 0.065, walkVal * 0.7, const Color(0xFFFFD6E0));

    // Body
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY),
          width: bodyRX * 2,
          height: bodyRY * 2),
      Paint()..color = const Color(0xFFFFF0F5),
    );

    // Belly
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY + bodyRY * 0.1),
          width: bodyRX * 0.9,
          height: bodyRY * 0.9),
      Paint()..color = const Color(0xFFFFD6E0),
    );

    // Fluffy tail
    _drawRabbitTail(
        canvas, Offset(bodyCX + bodyRX * 0.95, bodyCY + bodyRY * 0.1), Colors.white);

    // Head
    final headCX = bodyCX + eatVal * 3;
    final headCY = bodyCY - bodyRY - h * 0.12;
    final headR = w * 0.20;

    // Tall ears
    _drawRabbitEar(canvas, Offset(headCX - headR * 0.45, headCY - headR * 0.8),
        headR * 0.22, h * 0.22, true);
    _drawRabbitEar(canvas, Offset(headCX + headR * 0.45, headCY - headR * 0.8),
        headR * 0.22, h * 0.22, false);

    // Head
    canvas.drawCircle(
        Offset(headCX, headCY), headR, Paint()..color = const Color(0xFFFFF0F5));

    // Face
    canvas.drawCircle(Offset(headCX, headCY + headR * 0.1), headR * 0.65,
        Paint()..color = const Color(0xFFFFD6E0));

    // Eyes
    _drawEye(canvas, Offset(headCX - headR * 0.32, headCY - headR * 0.05),
        headR * 0.17, blinkVal);
    _drawEye(canvas, Offset(headCX + headR * 0.32, headCY - headR * 0.05),
        headR * 0.17, blinkVal);

    // Nose
    canvas.drawCircle(Offset(headCX, headCY + headR * 0.2), headR * 0.08,
        Paint()..color = const Color(0xFFFF8FAB));

    // Mouth
    _drawSmile(
        canvas, Offset(headCX, headCY + headR * 0.32), headR * 0.18, happiness);

    // Cheeks
    canvas.drawCircle(
        Offset(headCX - headR * 0.5, headCY + headR * 0.25),
        headR * 0.14,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.55));
    canvas.drawCircle(
        Offset(headCX + headR * 0.5, headCY + headR * 0.25),
        headR * 0.14,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.55));
  }

  void _drawRabbitEar(Canvas canvas, Offset base, double width, double height,
      bool isLeft) {
    final outerPaint = Paint()..color = const Color(0xFFFFF0F5);
    final innerPaint = Paint()..color = const Color(0xFFFFB3C6);
    final tilt = isLeft ? -0.15 : 0.15;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, -height / 2), width: width, height: height),
        outerPaint);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, -height / 2),
            width: width * 0.5,
            height: height * 0.75),
        innerPaint);
    canvas.restore();
  }

  // -------------------------------------------------------------------------
  // Bear
  // -------------------------------------------------------------------------

  void _drawBearTail(Canvas canvas, Offset base, Color color) {
    canvas.drawCircle(base, 5, Paint()..color = color);
  }

  void _drawBear(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shakeX = excitedVal * 3;
    final bodyCX = w * 0.5 + shakeX;
    final bodyCY = h * 0.58 + bounceVal;
    final bodyRX = w * 0.30;
    final bodyRY = h * 0.23;

    // Legs
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.09, walkVal, const Color(0xFF8B6347));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.09, -walkVal, const Color(0xFF8B6347));
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.08, -walkVal * 0.7, const Color(0xFF8B6347));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.08, walkVal * 0.7, const Color(0xFF8B6347));

    // Body
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY),
          width: bodyRX * 2,
          height: bodyRY * 2),
      Paint()..color = const Color(0xFFA0714F),
    );

    // Belly
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY + bodyRY * 0.1),
          width: bodyRX * 1.1,
          height: bodyRY * 1.1),
      Paint()..color = const Color(0xFFD4A574),
    );

    // Tiny tail
    _drawBearTail(
        canvas, Offset(bodyCX + bodyRX * 0.95, bodyCY - bodyRY * 0.1), const Color(0xFFA0714F));

    // Head
    final headCX = bodyCX + eatVal * 4;
    final headCY = bodyCY - bodyRY - h * 0.13;
    final headR = w * 0.24;

    // Round ears
    canvas.drawCircle(Offset(headCX - headR * 0.7, headCY - headR * 0.65),
        headR * 0.28, Paint()..color = const Color(0xFFA0714F));
    canvas.drawCircle(Offset(headCX + headR * 0.7, headCY - headR * 0.65),
        headR * 0.28, Paint()..color = const Color(0xFFA0714F));
    canvas.drawCircle(Offset(headCX - headR * 0.7, headCY - headR * 0.65),
        headR * 0.16, Paint()..color = const Color(0xFFD4A574));
    canvas.drawCircle(Offset(headCX + headR * 0.7, headCY - headR * 0.65),
        headR * 0.16, Paint()..color = const Color(0xFFD4A574));

    // Head
    canvas.drawCircle(
        Offset(headCX, headCY), headR, Paint()..color = const Color(0xFFA0714F));

    // Muzzle
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(headCX, headCY + headR * 0.25),
          width: headR * 1.0,
          height: headR * 0.65),
      Paint()..color = const Color(0xFFD4A574),
    );

    // Eyes
    _drawEye(canvas, Offset(headCX - headR * 0.35, headCY - headR * 0.1),
        headR * 0.17, blinkVal);
    _drawEye(canvas, Offset(headCX + headR * 0.35, headCY - headR * 0.1),
        headR * 0.17, blinkVal);

    // Nose
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(headCX, headCY + headR * 0.15),
          width: headR * 0.28,
          height: headR * 0.18),
      Paint()..color = const Color(0xFF2D2D2D),
    );

    // Mouth
    _drawSmile(
        canvas, Offset(headCX, headCY + headR * 0.36), headR * 0.2, happiness);

    // Cheeks
    canvas.drawCircle(
        Offset(headCX - headR * 0.58, headCY + headR * 0.28),
        headR * 0.14,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.5));
    canvas.drawCircle(
        Offset(headCX + headR * 0.58, headCY + headR * 0.28),
        headR * 0.14,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.5));
  }

  // -------------------------------------------------------------------------
  // Fox
  // -------------------------------------------------------------------------

  void _drawFoxTail(Canvas canvas, Offset base, double wag, Color bodyColor) {
    // Big bushy tail
    final paint = Paint()
      ..color = bodyColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(base.dx, base.dy);
    path.quadraticBezierTo(
        base.dx + 25 + wag * 18, base.dy - 20, base.dx + 18 + wag * 28, base.dy - 50);
    canvas.drawPath(path, paint);
    // White tip
    canvas.drawCircle(
        Offset(base.dx + 18 + wag * 28, base.dy - 50), 8, Paint()..color = Colors.white);
  }

  void _drawFoxEar(Canvas canvas, Offset tip, double size, bool isLeft) {
    final outerPaint = Paint()..color = const Color(0xFFFF6B35);
    final innerPaint = Paint()..color = const Color(0xFFFFB3C6);
    final blackPaint = Paint()..color = const Color(0xFF2D2D2D);
    final dx = isLeft ? -size * 0.4 : size * 0.4;
    // Pointed ear
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx + dx - size * 0.35, tip.dy + size * 1.3)
      ..lineTo(tip.dx + dx + size * 0.35, tip.dy + size * 1.3)
      ..close();
    canvas.drawPath(path, blackPaint);
    final innerPath = Path()
      ..moveTo(tip.dx, tip.dy + size * 0.25)
      ..lineTo(tip.dx + dx - size * 0.18, tip.dy + size * 1.1)
      ..lineTo(tip.dx + dx + size * 0.18, tip.dy + size * 1.1)
      ..close();
    canvas.drawPath(innerPath, outerPaint);
    final innerInnerPath = Path()
      ..moveTo(tip.dx, tip.dy + size * 0.5)
      ..lineTo(tip.dx + dx - size * 0.08, tip.dy + size * 0.95)
      ..lineTo(tip.dx + dx + size * 0.08, tip.dy + size * 0.95)
      ..close();
    canvas.drawPath(innerInnerPath, innerPaint);
  }

  void _drawFox(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shakeX = excitedVal * 3;
    final bodyCX = w * 0.5 + shakeX;
    final bodyCY = h * 0.58 + bounceVal;
    final bodyRX = w * 0.27;
    final bodyRY = h * 0.21;

    // Legs
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.07, walkVal, const Color(0xFFE8621A));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.07, -walkVal, const Color(0xFFE8621A));
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.065, -walkVal * 0.7, const Color(0xFFE8621A));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.065, walkVal * 0.7, const Color(0xFFE8621A));

    // Body
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY),
          width: bodyRX * 2,
          height: bodyRY * 2),
      Paint()..color = const Color(0xFFFF6B35),
    );

    // Belly (white)
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY + bodyRY * 0.1),
          width: bodyRX * 0.9,
          height: bodyRY * 0.9),
      Paint()..color = Colors.white,
    );

    // Bushy tail
    _drawFoxTail(
        canvas, Offset(bodyCX + bodyRX * 0.9, bodyCY), tailVal, const Color(0xFFFF6B35));

    // Head
    final headCX = bodyCX + eatVal * 4;
    final headCY = bodyCY - bodyRY - h * 0.13;
    final headR = w * 0.22;

    // Pointed ears
    _drawFoxEar(
        canvas, Offset(headCX - headR * 0.6, headCY - headR * 0.75), headR * 0.35, true);
    _drawFoxEar(
        canvas, Offset(headCX + headR * 0.6, headCY - headR * 0.75), headR * 0.35, false);

    // Head
    canvas.drawCircle(
        Offset(headCX, headCY), headR, Paint()..color = const Color(0xFFFF6B35));

    // White face mask
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(headCX, headCY + headR * 0.15),
          width: headR * 1.2,
          height: headR * 0.9),
      Paint()..color = Colors.white,
    );

    // Eyes
    _drawEye(canvas, Offset(headCX - headR * 0.35, headCY - headR * 0.1),
        headR * 0.17, blinkVal);
    _drawEye(canvas, Offset(headCX + headR * 0.35, headCY - headR * 0.1),
        headR * 0.17, blinkVal);

    // Nose
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(headCX, headCY + headR * 0.18),
          width: headR * 0.22,
          height: headR * 0.15),
      Paint()..color = const Color(0xFF2D2D2D),
    );

    // Whiskers
    _drawWhiskers(canvas, Offset(headCX, headCY + headR * 0.18), headR);

    // Mouth
    _drawSmile(
        canvas, Offset(headCX, headCY + headR * 0.34), headR * 0.2, happiness);

    // Cheeks
    canvas.drawCircle(
        Offset(headCX - headR * 0.55, headCY + headR * 0.28),
        headR * 0.13,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.5));
    canvas.drawCircle(
        Offset(headCX + headR * 0.55, headCY + headR * 0.28),
        headR * 0.13,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.5));
  }

  // -------------------------------------------------------------------------
  // Dragon
  // -------------------------------------------------------------------------

  void _drawDragonTail(Canvas canvas, Offset base, double wag, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round;
    final path = Path();
    path.moveTo(base.dx, base.dy);
    path.cubicTo(
        base.dx + 20 + wag * 15, base.dy + 10,
        base.dx + 35 + wag * 20, base.dy - 20,
        base.dx + 25 + wag * 25, base.dy - 50);
    canvas.drawPath(path, paint);
    // Spiky tip
    final tipX = base.dx + 25 + wag * 25;
    final tipY = base.dy - 50;
    final spikePaint = Paint()..color = const Color(0xFF00CED1);
    final spikePath = Path()
      ..moveTo(tipX, tipY - 10)
      ..lineTo(tipX - 6, tipY + 5)
      ..lineTo(tipX + 6, tipY + 5)
      ..close();
    canvas.drawPath(spikePath, spikePaint);
  }

  void _drawDragonWing(Canvas canvas, Offset base, bool isLeft, double shake) {
    final wingColor = const Color(0xFF7B2FBE).withOpacity(0.8);
    final membraneColor = const Color(0xFF9B59B6).withOpacity(0.5);
    final dx = isLeft ? -1.0 : 1.0;
    final shakeOff = isLeft ? -shake * 2 : shake * 2;

    canvas.save();
    canvas.translate(base.dx + shakeOff, base.dy);

    // Wing bone
    final bonePath = Path()
      ..moveTo(0, 0)
      ..lineTo(dx * 28, -20)
      ..lineTo(dx * 38, -10);
    canvas.drawPath(
        bonePath,
        Paint()
          ..color = wingColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);

    // Wing membrane
    final membranePath = Path()
      ..moveTo(0, 0)
      ..lineTo(dx * 28, -20)
      ..lineTo(dx * 38, -10)
      ..lineTo(dx * 20, 10)
      ..close();
    canvas.drawPath(membranePath, Paint()..color = membraneColor);

    canvas.restore();
  }

  void _drawDragon(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shakeX = excitedVal * 3;
    final bodyCX = w * 0.5 + shakeX;
    final bodyCY = h * 0.58 + bounceVal;
    final bodyRX = w * 0.27;
    final bodyRY = h * 0.21;

    // Wings (behind body)
    _drawDragonWing(
        canvas, Offset(bodyCX - bodyRX * 0.5, bodyCY - bodyRY * 0.3), true, excitedVal);
    _drawDragonWing(
        canvas, Offset(bodyCX + bodyRX * 0.5, bodyCY - bodyRY * 0.3), false, excitedVal);

    // Legs
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.07, walkVal, const Color(0xFF6A0DAD));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.07, -walkVal, const Color(0xFF6A0DAD));
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.065, -walkVal * 0.7, const Color(0xFF6A0DAD));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.065, walkVal * 0.7, const Color(0xFF6A0DAD));

    // Body
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY),
          width: bodyRX * 2,
          height: bodyRY * 2),
      Paint()..color = const Color(0xFF7B2FBE),
    );

    // Belly scales (teal)
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY + bodyRY * 0.1),
          width: bodyRX * 0.9,
          height: bodyRY * 0.9),
      Paint()..color = const Color(0xFF00CED1),
    );

    // Tail
    _drawDragonTail(
        canvas, Offset(bodyCX + bodyRX * 0.9, bodyCY), tailVal, const Color(0xFF7B2FBE));

    // Head
    final headCX = bodyCX + eatVal * 4;
    final headCY = bodyCY - bodyRY - h * 0.13;
    final headR = w * 0.22;

    // Horns
    _drawDragonHorn(canvas, Offset(headCX - headR * 0.5, headCY - headR * 0.7), true);
    _drawDragonHorn(canvas, Offset(headCX + headR * 0.5, headCY - headR * 0.7), false);

    // Head
    canvas.drawCircle(
        Offset(headCX, headCY), headR, Paint()..color = const Color(0xFF7B2FBE));

    // Snout
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(headCX, headCY + headR * 0.3),
          width: headR * 0.9,
          height: headR * 0.55),
      Paint()..color = const Color(0xFF9B59B6),
    );

    // Eyes (slit pupils for dragon)
    _drawDragonEye(canvas, Offset(headCX - headR * 0.35, headCY - headR * 0.1),
        headR * 0.18, blinkVal);
    _drawDragonEye(canvas, Offset(headCX + headR * 0.35, headCY - headR * 0.1),
        headR * 0.18, blinkVal);

    // Nostrils
    canvas.drawCircle(Offset(headCX - headR * 0.12, headCY + headR * 0.22),
        headR * 0.06, Paint()..color = const Color(0xFF2D2D2D));
    canvas.drawCircle(Offset(headCX + headR * 0.12, headCY + headR * 0.22),
        headR * 0.06, Paint()..color = const Color(0xFF2D2D2D));

    // Mouth
    _drawSmile(
        canvas, Offset(headCX, headCY + headR * 0.38), headR * 0.22, happiness);
  }

  void _drawDragonHorn(Canvas canvas, Offset base, bool isLeft) {
    final paint = Paint()..color = const Color(0xFF00CED1);
    final dx = isLeft ? -4.0 : 4.0;
    final path = Path()
      ..moveTo(base.dx, base.dy - 16)
      ..lineTo(base.dx - dx, base.dy + 2)
      ..lineTo(base.dx + dx, base.dy + 2)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _drawDragonEye(Canvas canvas, Offset center, double radius, double blink) {
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFD700));
    // Slit pupil
    final pupilH = radius * 1.4 * (1 - blink * 0.95);
    canvas.drawOval(
      Rect.fromCenter(
          center: center, width: radius * 0.3, height: max(pupilH * 2, 1)),
      Paint()..color = const Color(0xFF1A0A2E),
    );
    if (blink < 0.5) {
      canvas.drawCircle(
        Offset(center.dx + radius * 0.2, center.dy - radius * 0.2),
        radius * 0.18,
        Paint()..color = Colors.white.withOpacity(0.7),
      );
    }
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF2D2D2D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  // -------------------------------------------------------------------------
  // Unicorn
  // -------------------------------------------------------------------------

  void _drawUnicornTail(Canvas canvas, Offset base, double wag) {
    final colors = [
      const Color(0xFFFF6B9D),
      const Color(0xFFFFD700),
      const Color(0xFF7EC8E3),
      const Color(0xFF98FB98),
    ];
    for (int i = 0; i < colors.length; i++) {
      final offset = i * 3.0;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round;
      final path = Path();
      path.moveTo(base.dx + offset, base.dy);
      path.cubicTo(
          base.dx + 20 + wag * 15 + offset, base.dy - 15,
          base.dx + 30 + wag * 20 + offset, base.dy - 35,
          base.dx + 15 + wag * 25 + offset, base.dy - 60);
      canvas.drawPath(path, paint);
    }
  }

  void _drawUnicornHorn(Canvas canvas, Offset base) {
    final colors = [
      const Color(0xFFFF6B9D),
      const Color(0xFFFFD700),
      const Color(0xFF7EC8E3),
    ];
    for (int i = 0; i < 3; i++) {
      final paint = Paint()..color = colors[i];
      final segH = 8.0;
      final segW = 5.0 - i * 1.2;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(base.dx, base.dy - i * segH - 4),
            width: segW * 2,
            height: segH),
        paint,
      );
    }
    // Tip
    final tipPath = Path()
      ..moveTo(base.dx, base.dy - 28)
      ..lineTo(base.dx - 3, base.dy - 18)
      ..lineTo(base.dx + 3, base.dy - 18)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = const Color(0xFFFFD700));
  }

  void _drawUnicornMane(Canvas canvas, Offset headCenter, double headR) {
    final colors = [
      const Color(0xFFFF6B9D),
      const Color(0xFFFFD700),
      const Color(0xFF7EC8E3),
      const Color(0xFF98FB98),
    ];
    for (int i = 0; i < colors.length; i++) {
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round;
      final path = Path();
      final startX = headCenter.dx - headR * 0.3 + i * 4.0;
      path.moveTo(startX, headCenter.dy - headR * 0.5);
      path.cubicTo(
          startX - 15, headCenter.dy,
          startX - 10, headCenter.dy + headR * 0.5,
          startX - 5, headCenter.dy + headR * 0.9);
      canvas.drawPath(path, paint);
    }
  }

  void _drawUnicorn(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shakeX = excitedVal * 3;
    final bodyCX = w * 0.5 + shakeX;
    final bodyCY = h * 0.58 + bounceVal;
    final bodyRX = w * 0.27;
    final bodyRY = h * 0.21;

    // Legs
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.065, walkVal, const Color(0xFFE8D5F0));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.5, bodyCY + bodyRY * 0.8),
        h * 0.18, w * 0.065, -walkVal, const Color(0xFFE8D5F0));
    _drawLeg(canvas, Offset(bodyCX - bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.06, -walkVal * 0.7, const Color(0xFFE8D5F0));
    _drawLeg(canvas, Offset(bodyCX + bodyRX * 0.3, bodyCY + bodyRY * 0.85),
        h * 0.16, w * 0.06, walkVal * 0.7, const Color(0xFFE8D5F0));

    // Body
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY),
          width: bodyRX * 2,
          height: bodyRY * 2),
      Paint()..color = Colors.white,
    );

    // Body shimmer
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY),
          width: bodyRX * 2,
          height: bodyRY * 2),
      Paint()
        ..color = const Color(0xFFE8D5F0).withOpacity(0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Rainbow tail
    _drawUnicornTail(
        canvas, Offset(bodyCX + bodyRX * 0.9, bodyCY - bodyRY * 0.1), tailVal);

    // Head
    final headCX = bodyCX + eatVal * 4;
    final headCY = bodyCY - bodyRY - h * 0.13;
    final headR = w * 0.21;

    // Mane
    _drawUnicornMane(canvas, Offset(headCX, headCY), headR);

    // Pointed ears
    _drawCatEar(
        canvas, Offset(headCX - headR * 0.55, headCY - headR * 0.65), headR * 0.3, true);
    _drawCatEar(
        canvas, Offset(headCX + headR * 0.55, headCY - headR * 0.65), headR * 0.3, false);

    // Head
    canvas.drawCircle(
        Offset(headCX, headCY), headR, Paint()..color = Colors.white);

    // Horn
    _drawUnicornHorn(canvas, Offset(headCX, headCY - headR * 0.85));

    // Face
    canvas.drawCircle(Offset(headCX, headCY + headR * 0.1), headR * 0.65,
        Paint()..color = const Color(0xFFF8F0FF));

    // Eyes (sparkly)
    _drawEye(canvas, Offset(headCX - headR * 0.32, headCY - headR * 0.05),
        headR * 0.17, blinkVal);
    _drawEye(canvas, Offset(headCX + headR * 0.32, headCY - headR * 0.05),
        headR * 0.17, blinkVal);

    // Nose
    canvas.drawCircle(Offset(headCX, headCY + headR * 0.2), headR * 0.07,
        Paint()..color = const Color(0xFFFFB3C6));

    // Mouth
    _drawSmile(
        canvas, Offset(headCX, headCY + headR * 0.32), headR * 0.18, happiness);

    // Cheeks (rainbow shimmer)
    canvas.drawCircle(
        Offset(headCX - headR * 0.52, headCY + headR * 0.25),
        headR * 0.14,
        Paint()..color = const Color(0xFFFF6B9D).withOpacity(0.45));
    canvas.drawCircle(
        Offset(headCX + headR * 0.52, headCY + headR * 0.25),
        headR * 0.14,
        Paint()..color = const Color(0xFF7EC8E3).withOpacity(0.45));
  }

  // -------------------------------------------------------------------------
  // Penguin
  // -------------------------------------------------------------------------

  void _drawPenguin(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shakeX = excitedVal * 3;
    final bodyCX = w * 0.5 + shakeX;
    final bodyCY = h * 0.58 + bounceVal;
    final bodyRX = w * 0.24;
    final bodyRY = h * 0.24;

    // Flippers (arms) instead of legs
    _drawFlipper(canvas, Offset(bodyCX - bodyRX * 0.9, bodyCY - bodyRY * 0.1),
        h * 0.18, w * 0.07, walkVal * 0.5, const Color(0xFF1A1A2E));
    _drawFlipper(canvas, Offset(bodyCX + bodyRX * 0.9, bodyCY - bodyRY * 0.1),
        h * 0.18, w * 0.07, -walkVal * 0.5, const Color(0xFF1A1A2E));

    // Feet
    _drawPenguinFoot(canvas, Offset(bodyCX - bodyRX * 0.35, bodyCY + bodyRY * 0.9),
        w * 0.1, walkVal);
    _drawPenguinFoot(canvas, Offset(bodyCX + bodyRX * 0.35, bodyCY + bodyRY * 0.9),
        w * 0.1, -walkVal);

    // Body (black)
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY),
          width: bodyRX * 2,
          height: bodyRY * 2),
      Paint()..color = const Color(0xFF1A1A2E),
    );

    // White belly
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(bodyCX, bodyCY + bodyRY * 0.05),
          width: bodyRX * 1.1,
          height: bodyRY * 1.2),
      Paint()..color = Colors.white,
    );

    // Head
    final headCX = bodyCX + eatVal * 3;
    final headCY = bodyCY - bodyRY - h * 0.10;
    final headR = w * 0.20;

    // Head (black)
    canvas.drawCircle(
        Offset(headCX, headCY), headR, Paint()..color = const Color(0xFF1A1A2E));

    // White face patch
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(headCX, headCY + headR * 0.15),
          width: headR * 1.1,
          height: headR * 0.9),
      Paint()..color = Colors.white,
    );

    // Eyes
    _drawEye(canvas, Offset(headCX - headR * 0.3, headCY - headR * 0.1),
        headR * 0.17, blinkVal);
    _drawEye(canvas, Offset(headCX + headR * 0.3, headCY - headR * 0.1),
        headR * 0.17, blinkVal);

    // Yellow beak
    _drawPenguinBeak(canvas, Offset(headCX, headCY + headR * 0.2), headR * 0.22);

    // Cheeks
    canvas.drawCircle(
        Offset(headCX - headR * 0.5, headCY + headR * 0.25),
        headR * 0.13,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.5));
    canvas.drawCircle(
        Offset(headCX + headR * 0.5, headCY + headR * 0.25),
        headR * 0.13,
        Paint()..color = const Color(0xFFFFB3C6).withOpacity(0.5));
  }

  void _drawFlipper(Canvas canvas, Offset top, double len, double width,
      double angle, Color color) {
    canvas.save();
    canvas.translate(top.dx, top.dy);
    canvas.rotate(angle);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(0, len / 2), width: width, height: len),
      Radius.circular(width / 2),
    );
    canvas.drawRRect(rrect, paint);
    canvas.restore();
  }

  void _drawPenguinFoot(Canvas canvas, Offset center, double size, double angle) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle * 0.3);
    final paint = Paint()..color = const Color(0xFFFFD700);
    // Three toes
    for (int i = -1; i <= 1; i++) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(i * size * 0.35, size * 0.2),
            width: size * 0.3,
            height: size * 0.5),
        paint,
      );
    }
    canvas.restore();
  }

  void _drawPenguinBeak(Canvas canvas, Offset center, double size) {
    final paint = Paint()..color = const Color(0xFFFFD700);
    final path = Path()
      ..moveTo(center.dx, center.dy - size * 0.3)
      ..lineTo(center.dx - size * 0.5, center.dy + size * 0.1)
      ..lineTo(center.dx + size * 0.5, center.dy + size * 0.1)
      ..close();
    canvas.drawPath(path, paint);
    // Lower beak
    final lowerPath = Path()
      ..moveTo(center.dx - size * 0.4, center.dy + size * 0.1)
      ..lineTo(center.dx, center.dy + size * 0.4)
      ..lineTo(center.dx + size * 0.4, center.dy + size * 0.1)
      ..close();
    canvas.drawPath(
        lowerPath, Paint()..color = const Color(0xFFE6B800));
  }
}
