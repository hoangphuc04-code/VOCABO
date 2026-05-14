import 'dart:math';
import 'package:flutter/material.dart';
import 'character_animations.dart';

/// CustomPainter vẽ nhân vật Meow 2D kiểu game
/// Sử dụng skeleton-based rendering: mỗi bộ phận xoay theo pivot riêng
class MeowPainter extends CustomPainter {
  final SkeletonPose pose;
  final CharacterState state;
  final double eyeBlink; // 0 = mở, 1 = nhắm
  final Color primaryColor;
  final Color skinColor;
  final Color accentColor;

  const MeowPainter({
    required this.pose,
    required this.state,
    this.eyeBlink = 0,
    this.primaryColor = const Color(0xFF6C63FF),
    this.skinColor = const Color(0xFFFFD0A0),
    this.accentColor = const Color(0xFFFF6584),
  });

  // ─── Kích thước skeleton ────────────────────────────────────────────────
  static const double _headR = 26.0;        // Đầu to hơn — chibi
  static const double _bodyW = 30.0;        // Thân rộng hơn
  static const double _bodyH = 26.0;        // Thân ngắn hơn — chibi
  static const double _upperArmLen = 14.0;  // Tay ngắn hơn
  static const double _forearmLen = 12.0;   // Cẳng tay ngắn
  static const double _thighLen = 14.0;     // Chân ngắn — chibi
  static const double _shinLen = 12.0;      // Cẳng chân ngắn
  static const double _handR = 6.0;         // Bàn tay tròn hơn
  static const double _footW = 12.0;        // Bàn chân rộng hơn
  static const double _footH = 7.0;         // Bàn chân dày hơn

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Dịch tâm lên trên ~15% để đầu không bị clip (đầu chibi to hơn thân)
    final cy = size.height * 0.55 + pose.bodyOffsetY;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(pose.bodyRotation);

    // Thứ tự vẽ: chân trước → thân → tay sau → đầu → tay trước
    // (tạo cảm giác depth 2.5D đơn giản)

    _drawLeg(canvas, isLeft: true, isBack: false);
    _drawLeg(canvas, isLeft: false, isBack: false);
    _drawTail(canvas);
    _drawBody(canvas);
    _drawArm(canvas, isLeft: true, isBack: true);
    _drawArm(canvas, isLeft: false, isBack: true);
    _drawHead(canvas);
    _drawArm(canvas, isLeft: true, isBack: false);
    _drawArm(canvas, isLeft: false, isBack: false);

    canvas.restore();
  }

  // ─── Vẽ đầu ────────────────────────────────────────────────────────────
  void _drawHead(Canvas canvas) {
    final headY = -_bodyH / 2 - _headR + 4;

    canvas.save();
    canvas.translate(0, headY);
    canvas.rotate(pose.headTilt);

    // Tai mèo (trước đầu)
    _drawEar(canvas, isLeft: true);
    _drawEar(canvas, isLeft: false);

    // Đầu
    final headPaint = Paint()..color = primaryColor;
    canvas.drawCircle(Offset.zero, _headR, headPaint);

    // Mặt sáng hơn
    final facePaint = Paint()..color = primaryColor.withValues(alpha: 0.85);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 3), width: 30, height: 26),
      facePaint,
    );

    // Mắt
    _drawEyes(canvas);

    // Mũi
    _drawNose(canvas);

    // Miệng
    _drawMouth(canvas);

    // Ria mèo
    _drawWhiskers(canvas);

    canvas.restore();
  }

  void _drawEar(Canvas canvas, {required bool isLeft}) {
    final x = isLeft ? -_headR * 0.55 : _headR * 0.55;
    final earPaint = Paint()..color = primaryColor;
    final innerEarPaint = Paint()..color = accentColor.withValues(alpha: 0.7);

    final path = Path();
    path.moveTo(x - 8, -8);
    path.lineTo(x, -_headR - 10);
    path.lineTo(x + 8, -8);
    path.close();
    canvas.drawPath(path, earPaint);

    final innerPath = Path();
    innerPath.moveTo(x - 4, -8);
    innerPath.lineTo(x, -_headR - 5);
    innerPath.lineTo(x + 4, -8);
    innerPath.close();
    canvas.drawPath(innerPath, innerEarPaint);
  }

  void _drawEyes(Canvas canvas) {
    const eyeY = -2.0;
    const eyeX = 8.0;

    for (final sign in [-1.0, 1.0]) {
      final ex = sign * eyeX;

      if (eyeBlink > 0.7) {
        // Nhắm mắt - vẽ đường cong
        final blinkPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawArc(
          Rect.fromCenter(center: Offset(ex, eyeY), width: 12, height: 8),
          pi, pi,
          false, blinkPaint,
        );
      } else {
        // Mở mắt - vòng trắng
        final eyeWhitePaint = Paint()..color = Colors.white;
        canvas.drawOval(
          Rect.fromCenter(center: Offset(ex, eyeY), width: 12, height: 10),
          eyeWhitePaint,
        );

        // Con ngươi
        final pupilPaint = Paint()..color = const Color(0xFF2D2D2D);
        canvas.drawCircle(Offset(ex + sign * 0.5, eyeY + 0.5), 3.5, pupilPaint);

        // Highlight
        final hlPaint = Paint()..color = Colors.white;
        canvas.drawCircle(Offset(ex + sign * 1.5, eyeY - 1), 1.2, hlPaint);

        // Sparkle khi excited
        if (state == CharacterState.excited) {
          final sparkPaint = Paint()
            ..color = const Color(0xFFFFD700)
            ..strokeWidth = 1;
          for (int i = 0; i < 4; i++) {
            final angle = i * pi / 2;
            canvas.drawLine(
              Offset(ex + cos(angle) * 6, eyeY + sin(angle) * 6),
              Offset(ex + cos(angle) * 9, eyeY + sin(angle) * 9),
              sparkPaint,
            );
          }
        }
      }
    }
  }

  void _drawNose(Canvas canvas) {
    final nosePaint = Paint()..color = accentColor;
    final nosePath = Path();
    nosePath.moveTo(-3, 7);
    nosePath.lineTo(3, 7);
    nosePath.lineTo(0, 10);
    nosePath.close();
    canvas.drawPath(nosePath, nosePaint);
  }

  void _drawMouth(Canvas canvas) {
    final mouthPaint = Paint()
      ..color = const Color(0xFF2D2D2D)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Kiểu miệng theo state
    if (state == CharacterState.excited || state == CharacterState.waving) {
      // Miệng cười to
      canvas.drawArc(
        const Rect.fromLTWH(-7, 9, 14, 8),
        0, pi, false, mouthPaint,
      );
    } else if (state == CharacterState.thinking) {
      // Miệng chữ U nhỏ ngẫm nghĩ
      canvas.drawArc(
        const Rect.fromLTWH(-4, 10, 8, 5),
        0.2, pi - 0.4, false, mouthPaint,
      );
    } else {
      // Miệng mèo w-shape
      final wp = Path();
      wp.moveTo(-6, 10);
      wp.quadraticBezierTo(-3, 13, 0, 10);
      wp.quadraticBezierTo(3, 13, 6, 10);
      canvas.drawPath(wp, mouthPaint);
    }
  }

  void _drawWhiskers(Canvas canvas) {
    final whiskerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round;

    // Trái
    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(-5, 8 + i * 3.0),
        Offset(-_headR - 4, 7 + i * 2.5),
        whiskerPaint,
      );
    }
    // Phải
    for (int i = -1; i <= 1; i++) {
      canvas.drawLine(
        Offset(5, 8 + i * 3.0),
        Offset(_headR + 4, 7 + i * 2.5),
        whiskerPaint,
      );
    }
  }

  // ─── Vẽ thân ────────────────────────────────────────────────────────────
  void _drawBody(Canvas canvas) {
    final bodyPaint = Paint()..color = primaryColor;
    final clothPaint = Paint()..color = accentColor;

    // Thân chính
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, 0), width: _bodyW, height: _bodyH),
      const Radius.circular(14),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // Cổ áo / chi tiết
    final neckRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: const Offset(0, -_bodyH / 2 + 7), width: 20, height: 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(neckRect, clothPaint.copyWith(color: accentColor.withValues(alpha: 0.8)));

    // Nút áo
    final buttonPaint = Paint()..color = Colors.white.withValues(alpha: 0.7);
    for (int i = 0; i < 3; i++) {
      canvas.drawCircle(Offset(0, -4 + i * 7.0), 1.8, buttonPaint);
    }
  }

  // ─── Vẽ tay ─────────────────────────────────────────────────────────────
  void _drawArm(Canvas canvas, {required bool isLeft, required bool isBack}) {
    final sign = isLeft ? -1.0 : 1.0;
    final shoulderX = sign * (_bodyW / 2 - 2);
    final shoulderY = -_bodyH / 2 + 8;
    final angle = isLeft ? pose.leftArmAngle : pose.rightArmAngle;
    final foreAngle = isLeft ? pose.leftForearmAngle : pose.rightForearmAngle;

    // Chỉ vẽ tay "sau" khi isBack=true và tay "trước" khi isBack=false
    // Tay trái là tay "sau" (phía sau người), tay phải là "trước"
    final shouldDraw = isLeft ? isBack : !isBack;
    if (!shouldDraw) return;

    final limbPaint = Paint()
      ..color = isBack
          ? primaryColor.withValues(alpha: 0.7)
          : primaryColor
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final jointPaint = Paint()
      ..color = isBack
          ? primaryColor.withValues(alpha: 0.7)
          : primaryColor;

    canvas.save();
    canvas.translate(shoulderX, shoulderY);
    canvas.rotate(angle);

    // Cánh tay trên
    canvas.drawLine(Offset.zero, Offset(0, _upperArmLen), limbPaint);
    canvas.drawCircle(Offset.zero, 4, jointPaint);

    // Cẳng tay
    canvas.translate(0, _upperArmLen);
    canvas.rotate(foreAngle);
    canvas.drawLine(Offset.zero, Offset(0, _forearmLen), limbPaint);

    // Bàn tay
    final handPaint = Paint()
      ..color = isBack ? skinColor.withValues(alpha: 0.7) : skinColor;
    canvas.drawCircle(Offset(0, _forearmLen), _handR, handPaint);

    canvas.restore();
  }

  // ─── Vẽ chân ────────────────────────────────────────────────────────────
  void _drawLeg(Canvas canvas, {required bool isLeft, required bool isBack}) {
    final sign = isLeft ? -1.0 : 1.0;
    final hipX = sign * (_bodyW / 2 - 8);
    final hipY = _bodyH / 2 - 4;
    final thighAngle = isLeft ? pose.leftThighAngle : pose.rightThighAngle;
    final shinAngle = isLeft ? pose.leftShinAngle : pose.rightShinAngle;

    final legPaint = Paint()
      ..color = primaryColor.withValues(alpha: isLeft ? 0.75 : 1.0)
      ..strokeWidth = 9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final footPaint = Paint()
      ..color = isLeft
          ? primaryColor.withValues(alpha: 0.75)
          : primaryColor;

    canvas.save();
    canvas.translate(hipX, hipY);
    canvas.rotate(thighAngle);

    // Đùi
    canvas.drawLine(Offset.zero, Offset(0, _thighLen), legPaint);

    // Cẳng chân
    canvas.translate(0, _thighLen);
    canvas.rotate(shinAngle);
    canvas.drawLine(Offset.zero, Offset(0, _shinLen), legPaint);

    // Bàn chân (hình oval)
    final footRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(sign * 2, _shinLen + _footH / 2),
        width: _footW,
        height: _footH,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(footRect, footPaint);

    canvas.restore();
  }

  // ─── Vẽ đuôi ────────────────────────────────────────────────────────────
  void _drawTail(Canvas canvas) {
    final tailPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.85)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final startX = _bodyW / 2 - 2;
    final startY = _bodyH / 2 - 8;
    final ctrl1X = startX + 30;
    final ctrl1Y = startY - 20 + pose.tailCurve * 30;
    final ctrl2X = startX + 20;
    final ctrl2Y = startY - 50 + pose.tailCurve * 20;
    final endX = startX + 5;
    final endY = startY - 60;

    final path = Path();
    path.moveTo(startX, startY);
    path.cubicTo(ctrl1X, ctrl1Y, ctrl2X, ctrl2Y, endX, endY);

    canvas.drawPath(path, tailPaint);

    // Đầu đuôi tròn hơn
    final tipPaint = Paint()..color = accentColor.withValues(alpha: 0.9);
    canvas.drawCircle(Offset(endX, endY), 5, tipPaint);
  }

  @override
  bool shouldRepaint(MeowPainter old) =>
      old.pose != pose || old.eyeBlink != eyeBlink || old.state != state;
}

// Extension để copy Paint với màu khác
extension _PaintCopy on Paint {
  Paint copyWith({Color? color}) => Paint()
    ..color = color ?? this.color
    ..strokeWidth = strokeWidth
    ..strokeCap = strokeCap
    ..style = style;
}
