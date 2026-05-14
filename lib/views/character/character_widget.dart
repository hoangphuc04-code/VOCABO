// character_widget.dart — Nhân vật chibi SVG layered với animation
// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/character_model.dart';

// ─── Animation Mode ───────────────────────────────────────────────────────────
enum CharAnimMode { idle, sit, walk, wave, study }

// ─── Main Widget ──────────────────────────────────────────────────────────────
class CharacterWidget extends StatelessWidget {
  final CharacterModel character;
  final CharAnimMode mode;
  final double size;
  final bool facingRight;

  const CharacterWidget({
    super.key,
    required this.character,
    this.mode = CharAnimMode.idle,
    this.size = 120,
    this.facingRight = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget body = SizedBox(
      width: size,
      height: size * 1.4,
      child: _CharacterSvgStack(character: character, mode: mode),
    );

    // Mirror nếu đi trái
    if (!facingRight) {
      body = Transform(
        alignment: Alignment.center,
        transform: Matrix4.diagonal3Values(-1, 1, 1),
        child: body,
      );
    }

    // Animation theo mode
    switch (mode) {
      case CharAnimMode.idle:
        return body
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -4, duration: 1200.ms, curve: Curves.easeInOut);
      case CharAnimMode.sit:
        return body; // tĩnh khi ngồi
      case CharAnimMode.walk:
        return body
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -3, duration: 400.ms, curve: Curves.easeInOut);
      case CharAnimMode.wave:
        return body
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -6, duration: 800.ms, curve: Curves.easeInOut);
      case CharAnimMode.study:
        return body
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -2, duration: 2000.ms, curve: Curves.easeInOut);
    }
  }
}

// ─── SVG Stack (layers) ───────────────────────────────────────────────────────
class _CharacterSvgStack extends StatelessWidget {
  final CharacterModel character;
  final CharAnimMode mode;

  const _CharacterSvgStack({required this.character, required this.mode});

  @override
  Widget build(BuildContext context) {
    final svg = _buildCharacterSvg(character, mode);
    return SvgPicture.string(svg, fit: BoxFit.contain);
  }
}

// ─── SVG Builder ─────────────────────────────────────────────────────────────
String _buildCharacterSvg(CharacterModel c, CharAnimMode mode) {
  final skin = _colorHex(c.skinColor);
  final hair = _colorHex(c.hairColor);
  final outfit = _colorHex(c.outfitColor);
  final outfitDark = _colorHex(_darken(c.outfitColor, 0.15));
  final skinDark = _colorHex(_darken(c.skinColor, 0.12));
  final isFemale = c.gender == CharGender.female;
  final isSitting = mode == CharAnimMode.sit;

  // Legs/body position thay đổi khi ngồi
  final bodyY = isSitting ? 95 : 85;
  final legSvg = isSitting ? _sittingLegs(skin, skinDark, outfit, outfitDark) : _standingLegs(skin, skinDark, outfit, outfitDark);
  final armSvg = mode == CharAnimMode.wave ? _wavingArms(skin, skinDark, outfit, outfitDark, isFemale) : _normalArms(skin, skinDark, outfit, outfitDark, isFemale);

  return '''<svg viewBox="0 0 120 168" xmlns="http://www.w3.org/2000/svg">
  <!-- Shadow -->
  <ellipse cx="60" cy="162" rx="28" ry="5" fill="#00000018"/>

  <!-- === LEGS === -->
  $legSvg

  <!-- === BODY === -->
  ${_body(skin, skinDark, outfit, outfitDark, isFemale, bodyY)}

  <!-- === ARMS === -->
  $armSvg

  <!-- === HEAD === -->
  ${_head(skin, skinDark, hair, c.hairStyle, isFemale)}

  <!-- === FACE === -->
  ${_face(skin, c.hairColor)}

  <!-- === ACCESSORIES === -->
  ${c.hasGlasses ? _glasses() : ''}
  ${c.hasHat ? _hat(_colorHex(c.hatColor), hair) : ''}
</svg>''';
}

// ─── Body Parts ───────────────────────────────────────────────────────────────

String _body(String skin, String skinDark, String outfit, String outfitDark,
    bool isFemale, int y) {
  if (isFemale) {
    return '''
  <!-- Neck -->
  <rect x="53" y="${y - 8}" width="14" height="12" fill="$skin" rx="4"/>
  <!-- Torso (dress/top) -->
  <path d="M32 $y Q28 ${y + 10} 30 ${y + 45} Q60 ${y + 52} 90 ${y + 45} Q92 ${y + 10} 88 $y Q74 ${y - 6} 60 ${y - 4} Q46 ${y - 6} 32 $y Z" fill="$outfit"/>
  <!-- Dress flare -->
  <path d="M30 ${y + 45} Q20 ${y + 55} 22 ${y + 62} Q60 ${y + 70} 98 ${y + 62} Q100 ${y + 55} 90 ${y + 45} Q60 ${y + 52} 30 ${y + 45} Z" fill="$outfit"/>
  <!-- Collar detail -->
  <path d="M46 $y Q60 ${y + 8} 74 $y" fill="none" stroke="$outfitDark" stroke-width="1.5"/>
  <!-- Waist ribbon -->
  <rect x="38" y="${y + 38}" width="44" height="5" fill="$outfitDark" rx="2"/>
  ''';
  } else {
    return '''
  <!-- Neck -->
  <rect x="53" y="${y - 8}" width="14" height="12" fill="$skin" rx="4"/>
  <!-- Shirt -->
  <path d="M34 $y Q30 ${y + 8} 32 ${y + 48} Q60 ${y + 54} 88 ${y + 48} Q90 ${y + 8} 86 $y Q74 ${y - 6} 60 ${y - 4} Q46 ${y - 6} 34 $y Z" fill="$outfit"/>
  <!-- Collar -->
  <path d="M48 $y L60 ${y + 10} L72 $y" fill="none" stroke="$outfitDark" stroke-width="2"/>
  <!-- Shirt pocket -->
  <rect x="38" y="${y + 14}" width="14" height="12" fill="$outfitDark" rx="2" opacity="0.5"/>
  <!-- Pants -->
  <rect x="34" y="${y + 44}" width="52" height="8" fill="$outfitDark" rx="2"/>
  ''';
  }
}

String _standingLegs(String skin, String skinDark, String outfit, String outfitDark) {
  return '''
  <!-- Left leg -->
  <rect x="40" y="138" width="16" height="22" fill="$outfit" rx="6"/>
  <rect x="38" y="156" width="20" height="8" fill="$skinDark" rx="4"/>
  <!-- Right leg -->
  <rect x="64" y="138" width="16" height="22" fill="$outfit" rx="6"/>
  <rect x="62" y="156" width="20" height="8" fill="$skinDark" rx="4"/>
  ''';
}

String _sittingLegs(String skin, String skinDark, String outfit, String outfitDark) {
  return '''
  <!-- Left leg (bent forward) -->
  <path d="M40 140 Q36 148 30 152 Q28 158 36 160 Q44 162 46 156 Q50 148 48 140 Z" fill="$outfit"/>
  <ellipse cx="33" cy="158" rx="8" ry="4" fill="$skinDark"/>
  <!-- Right leg (bent forward) -->
  <path d="M72 140 Q76 148 82 152 Q84 158 76 160 Q68 162 66 156 Q62 148 64 140 Z" fill="$outfit"/>
  <ellipse cx="79" cy="158" rx="8" ry="4" fill="$skinDark"/>
  ''';
}

String _normalArms(String skin, String skinDark, String outfit, String outfitDark, bool isFemale) {
  return '''
  <!-- Left arm -->
  <path d="M34 88 Q22 96 20 110 Q22 116 28 114 Q34 112 36 100 Q38 92 34 88 Z" fill="$outfit"/>
  <ellipse cx="24" cy="114" rx="7" ry="5" fill="$skin"/>
  <!-- Right arm -->
  <path d="M86 88 Q98 96 100 110 Q98 116 92 114 Q86 112 84 100 Q82 92 86 88 Z" fill="$outfit"/>
  <ellipse cx="96" cy="114" rx="7" ry="5" fill="$skin"/>
  ''';
}

String _wavingArms(String skin, String skinDark, String outfit, String outfitDark, bool isFemale) {
  return '''
  <!-- Left arm (down) -->
  <path d="M34 88 Q22 96 20 110 Q22 116 28 114 Q34 112 36 100 Q38 92 34 88 Z" fill="$outfit"/>
  <ellipse cx="24" cy="114" rx="7" ry="5" fill="$skin"/>
  <!-- Right arm (raised/waving) -->
  <path d="M86 88 Q100 76 104 62 Q102 56 96 58 Q90 60 88 74 Q84 84 86 88 Z" fill="$outfit"/>
  <ellipse cx="102" cy="58" rx="7" ry="5" fill="$skin"/>
  ''';
}

String _head(String skin, String skinDark, String hair, CharHairStyle style, bool isFemale) {
  final hairSvg = _hairSvg(hair, style, isFemale);
  return '''
  <!-- Back hair (behind head) -->
  ${_backHair(hair, style, isFemale)}
  <!-- Head -->
  <ellipse cx="60" cy="52" rx="30" ry="32" fill="$skin"/>
  <!-- Cheeks blush -->
  <ellipse cx="38" cy="58" rx="7" ry="5" fill="#FFB6C1" opacity="0.5"/>
  <ellipse cx="82" cy="58" rx="7" ry="5" fill="#FFB6C1" opacity="0.5"/>
  <!-- Ear left -->
  <ellipse cx="30" cy="52" rx="5" ry="7" fill="$skin"/>
  <ellipse cx="30" cy="52" rx="3" ry="5" fill="$skinDark" opacity="0.3"/>
  <!-- Ear right -->
  <ellipse cx="90" cy="52" rx="5" ry="7" fill="$skin"/>
  <ellipse cx="90" cy="52" rx="3" ry="5" fill="$skinDark" opacity="0.3"/>
  <!-- Front hair -->
  $hairSvg
  ''';
}

String _backHair(String hair, CharHairStyle style, bool isFemale) {
  switch (style) {
    case CharHairStyle.long:
      return '<path d="M30 40 Q20 80 28 120 Q60 130 92 120 Q100 80 90 40" fill="$hair" opacity="0.9"/>';
    case CharHairStyle.ponytail:
      return '<path d="M82 36 Q96 60 94 100 Q90 110 86 108 Q82 106 84 96 Q86 70 80 40 Z" fill="$hair"/>';
    case CharHairStyle.twintail:
      return '''
        <path d="M30 40 Q16 60 18 90 Q22 100 28 98 Q34 96 32 80 Q30 60 34 44 Z" fill="$hair"/>
        <path d="M90 40 Q104 60 102 90 Q98 100 92 98 Q86 96 88 80 Q90 60 86 44 Z" fill="$hair"/>
      ''';
    default:
      return '';
  }
}

String _hairSvg(String hair, CharHairStyle style, bool isFemale) {
  switch (style) {
    case CharHairStyle.short:
      return '''
        <path d="M30 44 Q30 18 60 16 Q90 18 90 44 Q84 36 60 34 Q36 36 30 44 Z" fill="$hair"/>
        <path d="M30 44 Q28 52 30 56 Q32 50 34 48 Z" fill="$hair"/>
        <path d="M90 44 Q92 52 90 56 Q88 50 86 48 Z" fill="$hair"/>
      ''';
    case CharHairStyle.medium:
      return '''
        <path d="M30 44 Q28 20 60 16 Q92 20 90 44 Q84 34 60 32 Q36 34 30 44 Z" fill="$hair"/>
        <path d="M30 44 Q24 58 26 70 Q30 66 32 60 Q34 52 34 46 Z" fill="$hair"/>
        <path d="M90 44 Q96 58 94 70 Q90 66 88 60 Q86 52 86 46 Z" fill="$hair"/>
      ''';
    case CharHairStyle.long:
      return '''
        <path d="M30 44 Q28 18 60 14 Q92 18 90 44 Q84 32 60 30 Q36 32 30 44 Z" fill="$hair"/>
        <path d="M30 44 Q24 56 26 68 Q30 64 32 58 Z" fill="$hair"/>
        <path d="M90 44 Q96 56 94 68 Q90 64 88 58 Z" fill="$hair"/>
      ''';
    case CharHairStyle.ponytail:
      return '''
        <path d="M30 44 Q28 18 60 14 Q92 18 90 44 Q84 32 60 30 Q36 32 30 44 Z" fill="$hair"/>
        <path d="M82 28 Q90 24 92 32 Q90 36 86 34 Z" fill="$hair"/>
      ''';
    case CharHairStyle.twintail:
      return '''
        <path d="M30 44 Q28 18 60 14 Q92 18 90 44 Q84 32 60 30 Q36 32 30 44 Z" fill="$hair"/>
        <circle cx="28" cy="42" r="6" fill="$hair"/>
        <circle cx="92" cy="42" r="6" fill="$hair"/>
      ''';
    case CharHairStyle.curly:
      return '''
        <path d="M30 44 Q28 18 60 14 Q92 18 90 44 Q84 32 60 30 Q36 32 30 44 Z" fill="$hair"/>
        <circle cx="34" cy="26" r="8" fill="$hair"/>
        <circle cx="48" cy="20" r="9" fill="$hair"/>
        <circle cx="60" cy="18" r="9" fill="$hair"/>
        <circle cx="72" cy="20" r="9" fill="$hair"/>
        <circle cx="86" cy="26" r="8" fill="$hair"/>
        <circle cx="28" cy="38" r="7" fill="$hair"/>
        <circle cx="92" cy="38" r="7" fill="$hair"/>
      ''';
  }
}

String _face(String skin, Color hairColor) {
  // Màu mắt dựa trên màu tóc (tương phản)
  final eyeColor = hairColor.computeLuminance() > 0.3 ? '#2C2C2C' : '#4A3728';
  return '''
  <!-- Eyes -->
  <ellipse cx="46" cy="52" rx="6" ry="7" fill="white"/>
  <ellipse cx="74" cy="52" rx="6" ry="7" fill="white"/>
  <circle cx="47" cy="53" r="4.5" fill="$eyeColor"/>
  <circle cx="75" cy="53" r="4.5" fill="$eyeColor"/>
  <!-- Eye shine -->
  <circle cx="49" cy="51" r="1.8" fill="white"/>
  <circle cx="77" cy="51" r="1.8" fill="white"/>
  <circle cx="45" cy="55" r="1" fill="white" opacity="0.6"/>
  <circle cx="73" cy="55" r="1" fill="white" opacity="0.6"/>
  <!-- Eyelashes top -->
  <path d="M40 47 Q46 44 52 47" fill="none" stroke="#2C2C2C" stroke-width="1.5" stroke-linecap="round"/>
  <path d="M68 47 Q74 44 80 47" fill="none" stroke="#2C2C2C" stroke-width="1.5" stroke-linecap="round"/>
  <!-- Nose -->
  <ellipse cx="60" cy="62" rx="3" ry="2" fill="$skin" stroke="#D4956A" stroke-width="1" opacity="0.6"/>
  <!-- Mouth (smile) -->
  <path d="M52 70 Q60 77 68 70" fill="none" stroke="#C07A50" stroke-width="2" stroke-linecap="round"/>
  <path d="M54 70 Q60 74 66 70" fill="#FF8FAB" opacity="0.4"/>
  ''';
}

String _glasses() {
  return '''
  <!-- Glasses -->
  <rect x="36" y="47" width="18" height="14" fill="none" stroke="#4A4A4A" stroke-width="2" rx="4"/>
  <rect x="66" y="47" width="18" height="14" fill="none" stroke="#4A4A4A" stroke-width="2" rx="4"/>
  <line x1="54" y1="53" x2="66" y2="53" stroke="#4A4A4A" stroke-width="2"/>
  <line x1="22" y1="51" x2="36" y2="51" stroke="#4A4A4A" stroke-width="1.5"/>
  <line x1="84" y1="51" x2="98" y2="51" stroke="#4A4A4A" stroke-width="1.5"/>
  <!-- Lens tint -->
  <rect x="37" y="48" width="16" height="12" fill="#87CEEB" rx="3" opacity="0.2"/>
  <rect x="67" y="48" width="16" height="12" fill="#87CEEB" rx="3" opacity="0.2"/>
  ''';
}

String _hat(String hatColor, String hair) {
  return '''
  <!-- Hat brim -->
  <ellipse cx="60" cy="26" rx="36" ry="7" fill="$hatColor"/>
  <!-- Hat top -->
  <path d="M30 26 Q32 4 60 2 Q88 4 90 26 Z" fill="$hatColor"/>
  <!-- Hat band -->
  <rect x="30" y="22" width="60" height="5" fill="$hair" opacity="0.6" rx="2"/>
  ''';
}

// ─── Helpers ──────────────────────────────────────────────────────────────────
String _colorHex(Color c) {
  return '#${c.r.round().toRadixString(16).padLeft(2, '0')}${c.g.round().toRadixString(16).padLeft(2, '0')}${c.b.round().toRadixString(16).padLeft(2, '0')}';
}

Color _darken(Color c, double amount) {
  return Color.fromARGB(
    c.alpha.round(),
    (c.r * (1 - amount)).round().clamp(0, 255),
    (c.g * (1 - amount)).round().clamp(0, 255),
    (c.b * (1 - amount)).round().clamp(0, 255),
  );
}
