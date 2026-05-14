// character_model.dart — Mô hình nhân vật chibi của user
import 'package:flutter/material.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum CharGender { male, female }

enum CharHairStyle {
  short,      // tóc ngắn
  medium,     // tóc vừa
  long,       // tóc dài
  ponytail,   // đuôi ngựa
  twintail,   // hai bím
  curly,      // xoăn
}

enum CharOutfit {
  casual,     // thường ngày
  school,     // đồng phục học sinh
  sport,      // thể thao
  formal,     // lịch sự
  cute,       // dễ thương
  cool,       // ngầu
}

enum CharExpression {
  happy,
  neutral,
  excited,
  sleepy,
  studying,
}

// ─── Colour Palettes ──────────────────────────────────────────────────────────

const kSkinColors = <Color>[
  Color(0xFFFFDBAC), // sáng
  Color(0xFFF1C27D), // vàng nhạt
  Color(0xFFE0AC69), // nâu nhạt
  Color(0xFFC68642), // nâu trung
  Color(0xFF8D5524), // nâu đậm
  Color(0xFFFFCBA4), // hồng nhạt
];

const kHairColors = <Color>[
  Color(0xFF1A1A1A), // đen
  Color(0xFF3D2B1F), // nâu đậm
  Color(0xFF8B6343), // nâu
  Color(0xFFD4A96A), // vàng nâu
  Color(0xFFFFD700), // vàng
  Color(0xFFFF6B6B), // đỏ
  Color(0xFFFF8FAB), // hồng
  Color(0xFF9B59B6), // tím
  Color(0xFF3498DB), // xanh dương
  Color(0xFF2ECC71), // xanh lá
  Color(0xFFFFFFFF), // trắng
  Color(0xFF808080), // xám
];

const kOutfitColors = <Color>[
  Color(0xFF6BAED6), // xanh dương nhạt
  Color(0xFFFF8FAB), // hồng
  Color(0xFF4CAF50), // xanh lá
  Color(0xFFFFD700), // vàng
  Color(0xFF9B59B6), // tím
  Color(0xFFFF6B35), // cam
  Color(0xFF2C2C2C), // đen
  Color(0xFFFFFFFF), // trắng
  Color(0xFFE74C3C), // đỏ
  Color(0xFF1ABC9C), // ngọc
];

// ─── CharacterModel ───────────────────────────────────────────────────────────

class CharacterModel {
  final CharGender gender;
  final int skinColorIndex;
  final int hairColorIndex;
  final CharHairStyle hairStyle;
  final CharOutfit outfit;
  final int outfitColorIndex;
  final bool hasGlasses;
  final bool hasHat;
  final int hatColorIndex;
  final String name;

  const CharacterModel({
    this.gender = CharGender.female,
    this.skinColorIndex = 0,
    this.hairColorIndex = 0,
    this.hairStyle = CharHairStyle.medium,
    this.outfit = CharOutfit.casual,
    this.outfitColorIndex = 0,
    this.hasGlasses = false,
    this.hasHat = false,
    this.hatColorIndex = 0,
    this.name = 'Nhân vật',
  });

  Color get skinColor => kSkinColors[skinColorIndex.clamp(0, kSkinColors.length - 1)];
  Color get hairColor => kHairColors[hairColorIndex.clamp(0, kHairColors.length - 1)];
  Color get outfitColor => kOutfitColors[outfitColorIndex.clamp(0, kOutfitColors.length - 1)];
  Color get hatColor => kOutfitColors[hatColorIndex.clamp(0, kOutfitColors.length - 1)];

  static const defaultFemale = CharacterModel(
    gender: CharGender.female,
    skinColorIndex: 0,
    hairColorIndex: 0,
    hairStyle: CharHairStyle.long,
    outfit: CharOutfit.casual,
    outfitColorIndex: 1,
  );

  static const defaultMale = CharacterModel(
    gender: CharGender.male,
    skinColorIndex: 0,
    hairColorIndex: 0,
    hairStyle: CharHairStyle.short,
    outfit: CharOutfit.casual,
    outfitColorIndex: 0,
  );

  CharacterModel copyWith({
    CharGender? gender,
    int? skinColorIndex,
    int? hairColorIndex,
    CharHairStyle? hairStyle,
    CharOutfit? outfit,
    int? outfitColorIndex,
    bool? hasGlasses,
    bool? hasHat,
    int? hatColorIndex,
    String? name,
  }) =>
      CharacterModel(
        gender: gender ?? this.gender,
        skinColorIndex: skinColorIndex ?? this.skinColorIndex,
        hairColorIndex: hairColorIndex ?? this.hairColorIndex,
        hairStyle: hairStyle ?? this.hairStyle,
        outfit: outfit ?? this.outfit,
        outfitColorIndex: outfitColorIndex ?? this.outfitColorIndex,
        hasGlasses: hasGlasses ?? this.hasGlasses,
        hasHat: hasHat ?? this.hasHat,
        hatColorIndex: hatColorIndex ?? this.hatColorIndex,
        name: name ?? this.name,
      );

  factory CharacterModel.fromMap(Map<String, dynamic> m) => CharacterModel(
        gender: m['gender'] == 'male' ? CharGender.male : CharGender.female,
        skinColorIndex: (m['skinColorIndex'] ?? 0).toInt(),
        hairColorIndex: (m['hairColorIndex'] ?? 0).toInt(),
        hairStyle: CharHairStyle.values.firstWhere(
          (e) => e.name == (m['hairStyle'] ?? 'medium'),
          orElse: () => CharHairStyle.medium,
        ),
        outfit: CharOutfit.values.firstWhere(
          (e) => e.name == (m['outfit'] ?? 'casual'),
          orElse: () => CharOutfit.casual,
        ),
        outfitColorIndex: (m['outfitColorIndex'] ?? 0).toInt(),
        hasGlasses: m['hasGlasses'] == true,
        hasHat: m['hasHat'] == true,
        hatColorIndex: (m['hatColorIndex'] ?? 0).toInt(),
        name: m['name'] ?? 'Nhân vật',
      );

  Map<String, dynamic> toMap() => {
        'gender': gender.name,
        'skinColorIndex': skinColorIndex,
        'hairColorIndex': hairColorIndex,
        'hairStyle': hairStyle.name,
        'outfit': outfit.name,
        'outfitColorIndex': outfitColorIndex,
        'hasGlasses': hasGlasses,
        'hasHat': hasHat,
        'hatColorIndex': hatColorIndex,
        'name': name,
      };
}
