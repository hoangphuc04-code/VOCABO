// ignore_for_file: library_private_types_in_public_api
// house_screen.dart — Adorable Home 2D Room v4 (SVG-based)
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/house_service.dart';
import '../../data/services/character_service.dart';
import '../../data/models/character_model.dart';
import '../character/character_widget.dart';
import 'house_shop_screen.dart';
import 'gacha_screen.dart';
import 'pet_screen.dart';
import 'visit_friends_screen.dart';
import '../farm/farm_hub_screen.dart';

// ─── SVG Assets ───────────────────────────────────────────────────────────────

// Tuong + san phong khach (background layer)
const _svgRoom = '''
<svg viewBox="0 0 800 500" xmlns="http://www.w3.org/2000/svg">
  <!-- Tuong kem -->
  <rect width="800" height="320" fill="#F5EFE0"/>
  <!-- San go -->
  <rect y="320" width="800" height="180" fill="#D4A96A"/>
  <rect y="340" width="800" height="8" fill="#C49A5A" opacity="0.5"/>
  <rect y="360" width="800" height="8" fill="#C49A5A" opacity="0.5"/>
  <rect y="380" width="800" height="8" fill="#C49A5A" opacity="0.5"/>
  <rect y="400" width="800" height="8" fill="#C49A5A" opacity="0.5"/>
  <rect y="420" width="800" height="8" fill="#C49A5A" opacity="0.5"/>
  <rect y="440" width="800" height="8" fill="#C49A5A" opacity="0.5"/>
  <rect y="460" width="800" height="8" fill="#C49A5A" opacity="0.5"/>
  <!-- Chan tuong -->
  <rect y="316" width="800" height="8" fill="#C8A882" rx="2"/>
  <!-- Cua so trai -->
  <rect x="20" y="60" width="130" height="200" fill="#B8D8F0" rx="6"/>
  <rect x="20" y="60" width="130" height="200" fill="none" stroke="#D4B896" stroke-width="8" rx="6"/>
  <rect x="20" y="155" width="130" height="4" fill="#D4B896"/>
  <rect x="84" y="60" width="4" height="200" fill="#D4B896"/>
  <!-- Canh quan cua so: bau troi -->
  <rect x="24" y="64" width="56" height="87" fill="#87CEEB" rx="2"/>
  <rect x="84" y="64" width="62" height="87" fill="#87CEEB" rx="2"/>
  <!-- Canh quan cua so: cay xanh -->
  <rect x="24" y="159" width="56" height="97" fill="#6DB56D" rx="2"/>
  <rect x="84" y="159" width="62" height="97" fill="#5A9E5A" rx="2"/>
  <!-- Cau thang goc phai -->
  <rect x="680" y="0" width="120" height="320" fill="#E8DCC8" rx="0"/>
  <rect x="680" y="220" width="120" height="20" fill="#C8A882"/>
  <rect x="700" y="240" width="100" height="20" fill="#C8A882"/>
  <rect x="720" y="260" width="80" height="20" fill="#C8A882"/>
  <rect x="740" y="280" width="60" height="20" fill="#C8A882"/>
  <rect x="760" y="300" width="40" height="20" fill="#C8A882"/>
  <!-- Thanh doc cau thang -->
  <line x1="680" y1="0" x2="800" y2="220" stroke="#B8A080" stroke-width="6"/>
  <line x1="720" y1="0" x2="800" y2="160" stroke="#B8A080" stroke-width="4"/>
</svg>
''';

// TV treo tuong
const _svgTV = '''
<svg viewBox="0 0 260 180" xmlns="http://www.w3.org/2000/svg">
  <!-- Vien TV -->
  <rect width="260" height="165" fill="#1A1A2E" rx="10"/>
  <!-- Man hinh -->
  <rect x="8" y="8" width="244" height="149" fill="#0A0A1E" rx="6"/>
  <!-- Noi dung: bau troi xanh -->
  <rect x="8" y="8" width="244" height="80" fill="#4A90D9" rx="6"/>
  <!-- Mat troi -->
  <circle cx="80" cy="45" r="22" fill="#FFD700" opacity="0.9"/>
  <circle cx="180" cy="38" r="16" fill="#FFD700" opacity="0.7"/>
  <!-- Bien/dat -->
  <rect x="8" y="88" width="244" height="69" fill="#1A3A5C" rx="0"/>
  <ellipse cx="130" cy="88" rx="100" ry="12" fill="#2A5A8C"/>
  <!-- Chan TV -->
  <rect x="115" y="165" width="30" height="15" fill="#1A1A2E"/>
</svg>
''';

// Tu dung duoi TV
const _svgTVStand = '''
<svg viewBox="0 0 280 90" xmlns="http://www.w3.org/2000/svg">
  <rect width="280" height="75" fill="#8B6343" rx="6"/>
  <!-- 3 ngan -->
  <rect x="6" y="6" width="82" height="63" fill="#6B4423" rx="4"/>
  <rect x="99" y="6" width="82" height="63" fill="#6B4423" rx="4"/>
  <rect x="192" y="6" width="82" height="63" fill="#6B4423" rx="4"/>
  <!-- Tay cam -->
  <circle cx="47" cy="37" r="5" fill="#C8A882"/>
  <circle cx="140" cy="37" r="5" fill="#C8A882"/>
  <circle cx="233" cy="37" r="5" fill="#C8A882"/>
  <!-- Chan tu -->
  <rect x="20" y="75" width="12" height="15" fill="#6B4423" rx="2"/>
  <rect x="248" y="75" width="12" height="15" fill="#6B4423" rx="2"/>
</svg>
''';

// Ke sach lon goc phai
const _svgBookshelf = '''
<svg viewBox="0 0 200 280" xmlns="http://www.w3.org/2000/svg">
  <!-- Khung ke -->
  <rect width="200" height="280" fill="#8B6343" rx="6"/>
  <!-- 3 hang x 2 cot = 6 ngan -->
  <!-- Hang 1 trai -->
  <rect x="6" y="6" width="88" height="82" fill="#5C3A1E" rx="3"/>
  <!-- Sach hang 1 trai -->
  <rect x="10" y="15" width="14" height="65" fill="#E74C3C" rx="2"/>
  <rect x="26" y="20" width="12" height="60" fill="#3498DB" rx="2"/>
  <rect x="40" y="12" width="16" height="68" fill="#2ECC71" rx="2"/>
  <rect x="58" y="18" width="12" height="62" fill="#F39C12" rx="2"/>
  <rect x="72" y="22" width="14" height="58" fill="#9B59B6" rx="2"/>
  <!-- Hang 1 phai -->
  <rect x="106" y="6" width="88" height="82" fill="#5C3A1E" rx="3"/>
  <!-- Do vat hang 1 phai: binh -->
  <ellipse cx="150" cy="55" rx="22" ry="28" fill="#7EB8D4"/>
  <rect x="128" y="78" width="44" height="6" fill="#5A9AB8"/>
  <!-- Hang 2 trai -->
  <rect x="6" y="100" width="88" height="82" fill="#5C3A1E" rx="3"/>
  <!-- Sach hang 2 trai -->
  <rect x="10" y="108" width="12" height="66" fill="#E67E22" rx="2"/>
  <rect x="24" y="112" width="14" height="62" fill="#1ABC9C" rx="2"/>
  <rect x="40" y="106" width="12" height="68" fill="#E91E63" rx="2"/>
  <rect x="54" y="114" width="16" height="60" fill="#FF5722" rx="2"/>
  <rect x="72" y="110" width="14" height="64" fill="#607D8B" rx="2"/>
  <!-- Hang 2 phai: con meo ngoi -->
  <rect x="106" y="100" width="88" height="82" fill="#5C3A1E" rx="3"/>
  <ellipse cx="150" cy="155" rx="18" ry="16" fill="#E8A87C"/>
  <circle cx="150" cy="133" r="12" fill="#E8A87C"/>
  <polygon points="140,124 136,114 146,122" fill="#E8A87C"/>
  <polygon points="160,124 164,114 154,122" fill="#E8A87C"/>
  <circle cx="146" cy="132" r="2.5" fill="#2C2C2C"/>
  <circle cx="154" cy="132" r="2.5" fill="#2C2C2C"/>
  <!-- Hang 3 trai -->
  <rect x="6" y="194" width="88" height="80" fill="#5C3A1E" rx="3"/>
  <rect x="10" y="202" width="14" height="64" fill="#8BC34A" rx="2"/>
  <rect x="26" y="206" width="12" height="60" fill="#FF9800" rx="2"/>
  <rect x="40" y="200" width="16" height="66" fill="#00BCD4" rx="2"/>
  <rect x="58" y="204" width="12" height="62" fill="#F44336" rx="2"/>
  <rect x="72" y="208" width="14" height="58" fill="#9C27B0" rx="2"/>
  <!-- Hang 3 phai: tui xach -->
  <rect x="106" y="194" width="88" height="80" fill="#5C3A1E" rx="3"/>
  <rect x="122" y="210" width="52" height="48" fill="#4A4A6A" rx="6"/>
  <path d="M134 210 Q150 198 166 210" fill="none" stroke="#4A4A6A" stroke-width="5"/>
</svg>
''';

// Sofa xam
const _svgSofa = '''
<svg viewBox="0 0 420 160" xmlns="http://www.w3.org/2000/svg">
  <!-- Tua lung -->
  <rect x="10" y="0" width="400" height="80" fill="#4B5563" rx="14"/>
  <!-- Dem ngoi -->
  <rect x="10" y="65" width="400" height="70" fill="#6B7280" rx="10"/>
  <!-- Dem ngoi sang hon -->
  <rect x="14" y="68" width="392" height="60" fill="#9CA3AF" rx="8"/>
  <!-- Duong phan cach dem -->
  <rect x="208" y="68" width="4" height="60" fill="#6B7280"/>
  <!-- Tay vit trai -->
  <rect x="0" y="10" width="22" height="100" fill="#374151" rx="10"/>
  <!-- Tay vit phai -->
  <rect x="398" y="10" width="22" height="100" fill="#374151" rx="10"/>
  <!-- Chan sofa -->
  <rect x="30" y="130" width="14" height="30" fill="#374151" rx="4"/>
  <rect x="376" y="130" width="14" height="30" fill="#374151" rx="4"/>
  <!-- Goi tua -->
  <rect x="30" y="8" width="80" height="65" fill="#6B7280" rx="10"/>
  <rect x="310" y="8" width="80" height="65" fill="#6B7280" rx="10"/>
</svg>
''';

// Ban ca phe oval
const _svgCoffeeTable = '''
<svg viewBox="0 0 300 100" xmlns="http://www.w3.org/2000/svg">
  <!-- Mat ban oval -->
  <ellipse cx="150" cy="40" rx="145" ry="35" fill="#F5EFE0"/>
  <ellipse cx="150" cy="40" rx="145" ry="35" fill="none" stroke="#C8A882" stroke-width="4"/>
  <!-- Chan ban trung tam -->
  <rect x="140" y="72" width="20" height="28" fill="#D4A96A" rx="4"/>
  <!-- De chan -->
  <ellipse cx="150" cy="98" rx="40" ry="8" fill="#C8A882"/>
</svg>
''';

// Cay canh lon
const _svgPlant = '''
<svg viewBox="0 0 120 220" xmlns="http://www.w3.org/2000/svg">
  <!-- Chau -->
  <ellipse cx="60" cy="200" rx="38" ry="12" fill="#C8A882"/>
  <path d="M28 170 Q22 200 38 208 Q60 215 82 208 Q98 200 92 170 Z" fill="#D4956A"/>
  <ellipse cx="60" cy="170" rx="32" ry="10" fill="#C8A882"/>
  <!-- Than cay -->
  <rect x="56" y="80" width="8" height="92" fill="#5D4037"/>
  <!-- Canh trai -->
  <line x1="60" y1="130" x2="30" y2="100" stroke="#5D4037" stroke-width="5"/>
  <line x1="60" y1="110" x2="20" y2="90" stroke="#5D4037" stroke-width="4"/>
  <!-- Canh phai -->
  <line x1="60" y1="130" x2="90" y2="100" stroke="#5D4037" stroke-width="5"/>
  <line x1="60" y1="110" x2="100" y2="90" stroke="#5D4037" stroke-width="4"/>
  <!-- La (cum tron) -->
  <circle cx="60" cy="72" r="32" fill="#388E3C"/>
  <circle cx="38" cy="88" r="24" fill="#4CAF50"/>
  <circle cx="82" cy="88" r="24" fill="#4CAF50"/>
  <circle cx="28" cy="72" r="20" fill="#388E3C"/>
  <circle cx="92" cy="72" r="20" fill="#388E3C"/>
  <circle cx="60" cy="55" r="26" fill="#4CAF50"/>
  <circle cx="44" cy="62" r="18" fill="#66BB6A"/>
  <circle cx="76" cy="62" r="18" fill="#66BB6A"/>
  <circle cx="60" cy="48" r="20" fill="#81C784"/>
</svg>
''';

// Den san
const _svgFloorLamp = '''
<svg viewBox="0 0 80 200" xmlns="http://www.w3.org/2000/svg">
  <!-- De den -->
  <ellipse cx="40" cy="192" rx="28" ry="8" fill="#D4A96A"/>
  <rect x="34" y="180" width="12" height="14" fill="#C8A882" rx="3"/>
  <!-- Cot den -->
  <rect x="37" y="60" width="6" height="122" fill="#D4A96A"/>
  <!-- Cong den -->
  <path d="M40 60 Q70 50 72 30" fill="none" stroke="#D4A96A" stroke-width="6" stroke-linecap="round"/>
  <!-- Bong den -->
  <circle cx="72" cy="28" r="18" fill="#FFF9C4"/>
  <circle cx="72" cy="28" r="18" fill="none" stroke="#F59E0B" stroke-width="3"/>
  <!-- Anh sang glow -->
  <circle cx="72" cy="28" r="30" fill="#FFF9C4" opacity="0.3"/>
  <circle cx="72" cy="28" r="42" fill="#FFF9C4" opacity="0.12"/>
</svg>
''';

// Tham oval
const _svgRug = '''
<svg viewBox="0 0 360 120" xmlns="http://www.w3.org/2000/svg">
  <ellipse cx="180" cy="60" rx="175" ry="55" fill="#E8D5B0"/>
  <ellipse cx="180" cy="60" rx="155" ry="45" fill="none" stroke="#C8A882" stroke-width="3"/>
  <ellipse cx="180" cy="60" rx="120" ry="32" fill="none" stroke="#C8A882" stroke-width="2"/>
</svg>
''';

// Ke sach nho goc trai
const _svgSmallShelf = '''
<svg viewBox="0 0 110 240" xmlns="http://www.w3.org/2000/svg">
  <rect width="110" height="240" fill="#8B6343" rx="5"/>
  <!-- 4 hang -->
  <rect x="5" y="5" width="100" height="52" fill="#5C3A1E" rx="3"/>
  <rect x="8" y="10" width="12" height="42" fill="#E74C3C" rx="2"/>
  <rect x="22" y="12" width="10" height="40" fill="#3498DB" rx="2"/>
  <rect x="34" y="8" width="14" height="44" fill="#2ECC71" rx="2"/>
  <rect x="50" y="11" width="10" height="41" fill="#F39C12" rx="2"/>
  <rect x="62" y="9" width="12" height="43" fill="#9B59B6" rx="2"/>
  <rect x="76" y="13" width="10" height="39" fill="#E67E22" rx="2"/>
  <rect x="88" y="10" width="12" height="42" fill="#1ABC9C" rx="2"/>

  <rect x="5" y="63" width="100" height="52" fill="#5C3A1E" rx="3"/>
  <rect x="8" y="68" width="14" height="42" fill="#FF5722" rx="2"/>
  <rect x="24" y="70" width="10" height="40" fill="#607D8B" rx="2"/>
  <rect x="36" y="66" width="12" height="44" fill="#8BC34A" rx="2"/>
  <rect x="50" y="69" width="14" height="41" fill="#FF9800" rx="2"/>
  <rect x="66" y="67" width="10" height="43" fill="#00BCD4" rx="2"/>
  <rect x="78" y="71" width="12" height="39" fill="#F44336" rx="2"/>
  <rect x="92" y="68" width="10" height="42" fill="#9C27B0" rx="2"/>

  <rect x="5" y="121" width="100" height="52" fill="#5C3A1E" rx="3"/>
  <rect x="8" y="126" width="12" height="42" fill="#4CAF50" rx="2"/>
  <rect x="22" y="128" width="14" height="40" fill="#FF4081" rx="2"/>
  <rect x="38" y="124" width="10" height="44" fill="#00ACC1" rx="2"/>
  <rect x="50" y="127" width="12" height="41" fill="#FFC107" rx="2"/>
  <rect x="64" y="125" width="14" height="43" fill="#7C4DFF" rx="2"/>
  <rect x="80" y="129" width="10" height="39" fill="#FF6D00" rx="2"/>
  <rect x="92" y="126" width="12" height="42" fill="#00BFA5" rx="2"/>

  <rect x="5" y="179" width="100" height="56" fill="#5C3A1E" rx="3"/>
  <rect x="8" y="184" width="14" height="46" fill="#E53935" rx="2"/>
  <rect x="24" y="186" width="10" height="44" fill="#1E88E5" rx="2"/>
  <rect x="36" y="182" width="12" height="48" fill="#43A047" rx="2"/>
  <rect x="50" y="185" width="14" height="45" fill="#FB8C00" rx="2"/>
  <rect x="66" y="183" width="10" height="47" fill="#8E24AA" rx="2"/>
  <rect x="78" y="187" width="12" height="43" fill="#00897B" rx="2"/>
  <rect x="92" y="184" width="12" height="46" fill="#F4511E" rx="2"/>
</svg>
''';

// Ban an + ghe goc phai
const _svgDiningArea = '''
<svg viewBox="0 0 200 140" xmlns="http://www.w3.org/2000/svg">
  <!-- Mat ban -->
  <rect x="10" y="20" width="180" height="80" fill="white" rx="6"/>
  <rect x="10" y="20" width="180" height="80" fill="none" stroke="#CCCCCC" stroke-width="3" rx="6"/>
  <!-- Chan ban -->
  <rect x="20" y="98" width="10" height="30" fill="#AAAAAA" rx="3"/>
  <rect x="170" y="98" width="10" height="30" fill="#AAAAAA" rx="3"/>
  <!-- Do vat tren ban -->
  <rect x="30" y="32" width="60" height="44" fill="#FFD700" rx="4"/>
  <ellipse cx="148" cy="54" rx="26" ry="26" fill="#87CEEB"/>
  <!-- Ghe -->
  <rect x="0" y="0" width="50" height="16" fill="#E0E0E0" rx="4"/>
  <rect x="150" y="0" width="50" height="16" fill="#E0E0E0" rx="4"/>
</svg>
''';

// ─── Pet SVG theo loai ────────────────────────────────────────────────────────
String _petSvg(String species, String stage, int happiness) {
  if (stage == 'egg') {
    return '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
      <ellipse cx="40" cy="52" rx="30" ry="38" fill="#FFF9C4"/>
      <ellipse cx="40" cy="52" rx="30" ry="38" fill="none" stroke="#FFD700" stroke-width="3"/>
      <ellipse cx="30" cy="36" rx="6" ry="4" fill="white" opacity="0.7"/>
    </svg>''';
  }
  final mouth = happiness >= 50
      ? '<path d="M34 62 Q40 68 46 62" fill="none" stroke="#2C2C2C" stroke-width="2" stroke-linecap="round"/>'
      : '<path d="M34 66 Q40 60 46 66" fill="none" stroke="#2C2C2C" stroke-width="2" stroke-linecap="round"/>';

  switch (species) {
    case 'cat':
    case 'fox':
      final bodyC = species == 'fox' ? '#E8622A' : '#E8A87C';
      return '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="40" cy="72" rx="26" ry="22" fill="$bodyC"/>
        <circle cx="40" cy="42" r="22" fill="$bodyC"/>
        <polygon points="22,28 16,10 32,24" fill="$bodyC"/>
        <polygon points="58,28 64,10 48,24" fill="$bodyC"/>
        <polygon points="22,28 18,14 30,24" fill="#FFB6C1"/>
        <polygon points="58,28 62,14 50,24" fill="#FFB6C1"/>
        <circle cx="33" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="47" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="34" cy="39" r="1.5" fill="white"/>
        <circle cx="48" cy="39" r="1.5" fill="white"/>
        <ellipse cx="40" cy="48" rx="5" ry="3.5" fill="#FFB6C1"/>
        $mouth
        <path d="M60 68 Q75 55 72 45" fill="none" stroke="$bodyC" stroke-width="6" stroke-linecap="round"/>
        <rect x="28" y="88" width="8" height="12" fill="$bodyC" rx="4"/>
        <rect x="44" y="88" width="8" height="12" fill="$bodyC" rx="4"/>
      </svg>''';
    case 'dog':
      return '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="40" cy="72" rx="26" ry="22" fill="#D4956A"/>
        <circle cx="40" cy="42" r="22" fill="#D4956A"/>
        <ellipse cx="24" cy="36" rx="10" ry="16" fill="#C07A50"/>
        <ellipse cx="56" cy="36" rx="10" ry="16" fill="#C07A50"/>
        <circle cx="33" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="47" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="34" cy="39" r="1.5" fill="white"/>
        <circle cx="48" cy="39" r="1.5" fill="white"/>
        <ellipse cx="40" cy="50" rx="8" ry="6" fill="#C07A50"/>
        <ellipse cx="40" cy="50" rx="5" ry="3.5" fill="#FFB6C1"/>
        $mouth
        <path d="M62 70 Q78 60 74 48" fill="none" stroke="#D4956A" stroke-width="6" stroke-linecap="round"/>
        <rect x="28" y="88" width="8" height="12" fill="#D4956A" rx="4"/>
        <rect x="44" y="88" width="8" height="12" fill="#D4956A" rx="4"/>
      </svg>''';
    case 'rabbit':
      return '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="40" cy="72" rx="26" ry="22" fill="#F5F5F5"/>
        <circle cx="40" cy="42" r="22" fill="#F5F5F5"/>
        <rect x="26" y="6" width="10" height="30" fill="#F5F5F5" rx="5"/>
        <rect x="44" y="6" width="10" height="30" fill="#F5F5F5" rx="5"/>
        <rect x="28" y="8" width="6" height="24" fill="#FFB6C1" rx="3"/>
        <rect x="46" y="8" width="6" height="24" fill="#FFB6C1" rx="3"/>
        <circle cx="33" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="47" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="34" cy="39" r="1.5" fill="white"/>
        <circle cx="48" cy="39" r="1.5" fill="white"/>
        <ellipse cx="40" cy="48" rx="5" ry="3.5" fill="#FFB6C1"/>
        $mouth
        <rect x="28" y="88" width="8" height="12" fill="#F5F5F5" rx="4"/>
        <rect x="44" y="88" width="8" height="12" fill="#F5F5F5" rx="4"/>
      </svg>''';
    case 'hamster':
      return '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="40" cy="68" rx="30" ry="26" fill="#FFD5A8"/>
        <circle cx="40" cy="40" r="26" fill="#FFD5A8"/>
        <ellipse cx="22" cy="52" rx="12" ry="10" fill="#FFBF80"/>
        <ellipse cx="58" cy="52" rx="12" ry="10" fill="#FFBF80"/>
        <circle cx="33" cy="38" r="4" fill="#2C2C2C"/>
        <circle cx="47" cy="38" r="4" fill="#2C2C2C"/>
        <circle cx="34" cy="37" r="1.5" fill="white"/>
        <circle cx="48" cy="37" r="1.5" fill="white"/>
        <ellipse cx="40" cy="46" rx="5" ry="3.5" fill="#FFB6C1"/>
        $mouth
        <rect x="30" y="88" width="8" height="10" fill="#FFD5A8" rx="4"/>
        <rect x="42" y="88" width="8" height="10" fill="#FFD5A8" rx="4"/>
      </svg>''';
    case 'bear':
      return '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="40" cy="72" rx="28" ry="24" fill="#8B6343"/>
        <circle cx="40" cy="42" r="24" fill="#8B6343"/>
        <circle cx="24" cy="26" r="12" fill="#8B6343"/>
        <circle cx="56" cy="26" r="12" fill="#8B6343"/>
        <circle cx="24" cy="26" r="7" fill="#6B4423"/>
        <circle cx="56" cy="26" r="7" fill="#6B4423"/>
        <ellipse cx="40" cy="52" rx="12" ry="9" fill="#6B4423"/>
        <circle cx="33" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="47" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="34" cy="39" r="1.5" fill="white"/>
        <circle cx="48" cy="39" r="1.5" fill="white"/>
        <ellipse cx="40" cy="50" rx="5" ry="3.5" fill="#FFB6C1"/>
        $mouth
        <rect x="26" y="90" width="10" height="10" fill="#8B6343" rx="4"/>
        <rect x="44" y="90" width="10" height="10" fill="#8B6343" rx="4"/>
      </svg>''';
    case 'penguin':
      return '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="40" cy="70" rx="24" ry="26" fill="#2C2C2C"/>
        <ellipse cx="40" cy="65" rx="16" ry="20" fill="white"/>
        <circle cx="40" cy="38" r="22" fill="#2C2C2C"/>
        <circle cx="40" cy="38" r="14" fill="white"/>
        <circle cx="33" cy="36" r="4" fill="#2C2C2C"/>
        <circle cx="47" cy="36" r="4" fill="#2C2C2C"/>
        <circle cx="34" cy="35" r="1.5" fill="white"/>
        <circle cx="48" cy="35" r="1.5" fill="white"/>
        <ellipse cx="40" cy="44" rx="6" ry="4" fill="#FF9800"/>
        $mouth
        <ellipse cx="18" cy="68" rx="8" ry="14" fill="#2C2C2C"/>
        <ellipse cx="62" cy="68" rx="8" ry="14" fill="#2C2C2C"/>
        <rect x="30" y="92" width="10" height="8" fill="#FF9800" rx="2"/>
        <rect x="40" y="92" width="10" height="8" fill="#FF9800" rx="2"/>
      </svg>''';
    case 'dragon':
      return '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="40" cy="72" rx="26" ry="22" fill="#4CAF50"/>
        <circle cx="40" cy="42" r="22" fill="#4CAF50"/>
        <polygon points="28,22 22,4 36,18" fill="#388E3C"/>
        <polygon points="52,22 58,4 44,18" fill="#388E3C"/>
        <polygon points="28,22 24,8 34,18" fill="#A5D6A7"/>
        <polygon points="52,22 56,8 46,18" fill="#A5D6A7"/>
        <circle cx="33" cy="40" r="4" fill="#1A1A1A"/>
        <circle cx="47" cy="40" r="4" fill="#1A1A1A"/>
        <circle cx="34" cy="39" r="2" fill="#FFD700"/>
        <circle cx="48" cy="39" r="2" fill="#FFD700"/>
        <ellipse cx="40" cy="48" rx="5" ry="3.5" fill="#A5D6A7"/>
        $mouth
        <path d="M62 68 Q80 50 76 36" fill="none" stroke="#388E3C" stroke-width="8" stroke-linecap="round"/>
        <polygon points="76,36 84,28 72,30" fill="#388E3C"/>
        <rect x="28" y="88" width="8" height="12" fill="#4CAF50" rx="4"/>
        <rect x="44" y="88" width="8" height="12" fill="#4CAF50" rx="4"/>
      </svg>''';
    default: // unicorn, phoenix, default
      final c = species == 'phoenix' ? '#FF6B35' : '#E8A0D0';
      return '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
        <ellipse cx="40" cy="72" rx="26" ry="22" fill="$c"/>
        <circle cx="40" cy="42" r="22" fill="$c"/>
        <polygon points="40,8 36,24 44,24" fill="#FFD700"/>
        <circle cx="33" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="47" cy="40" r="4" fill="#2C2C2C"/>
        <circle cx="34" cy="39" r="1.5" fill="white"/>
        <circle cx="48" cy="39" r="1.5" fill="white"/>
        <ellipse cx="40" cy="48" rx="5" ry="3.5" fill="#FFB6C1"/>
        $mouth
        <rect x="28" y="88" width="8" height="12" fill="$c" rx="4"/>
        <rect x="44" y="88" width="8" height="12" fill="$c" rx="4"/>
      </svg>''';
  }
}

// ─── HouseScreen ─────────────────────────────────────────────────────────────
class HouseScreen extends StatefulWidget {
  final String? ownerUid;
  const HouseScreen({super.key, this.ownerUid});

  @override
  State<HouseScreen> createState() => _HouseScreenState();
}

class _HouseScreenState extends State<HouseScreen>
    with TickerProviderStateMixin {
  late AnimationController _petBounceCtrl;
  late Animation<double> _petBounce;

  bool get _isOwner =>
      widget.ownerUid == null ||
      widget.ownerUid == FirebaseAuth.instance.currentUser?.uid;

  String get _targetUid =>
      widget.ownerUid ?? FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _petBounceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _petBounce = Tween<double>(begin: 0, end: -7).animate(
      CurvedAnimation(parent: _petBounceCtrl, curve: Curves.easeInOut),
    );
    if (!_isOwner && widget.ownerUid != null) {
      HouseService.visitHouse(widget.ownerUid!);
    }
  }

  @override
  void dispose() {
    _petBounceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EFE0),
      body: StreamBuilder<HouseData>(
        stream: HouseService.houseStream(_targetUid),
        builder: (context, snap) {
          final house = snap.data ?? HouseData.defaultHouse();
          return StreamBuilder<CharacterModel?>(
            stream: CharacterService.characterStream(),
            builder: (context, charSnap) {
              final character = charSnap.data;
              return _RoomView(
                house: house,
                isOwner: _isOwner,
                petBounce: _petBounce,
                character: character,
                onShop: _isOwner
                    ? () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const HouseShopScreen()))
                    : null,
                onPet: (pet) => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (_) => PetScreen(pet: pet, isOwner: _isOwner))),
                onVisitFriends: _isOwner
                    ? () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const VisitFriendsScreen()))
                    : null,
                onFarm: _isOwner
                    ? () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const FarmHubScreen()))
                    : null,
                onGacha: _isOwner
                    ? () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const GachaScreen()))
                    : null,
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Room View ────────────────────────────────────────────────────────────────
class _RoomView extends StatelessWidget {
  final HouseData house;
  final bool isOwner;
  final Animation<double> petBounce;
  final CharacterModel? character;
  final VoidCallback? onShop;
  final void Function(PetData) onPet;
  final VoidCallback? onVisitFriends;
  final VoidCallback? onFarm;
  final VoidCallback? onGacha;

  const _RoomView({
    required this.house,
    required this.isOwner,
    required this.petBounce,
    required this.onPet,
    this.character,
    this.onShop,
    this.onVisitFriends,
    this.onFarm,
    this.onGacha,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final h = constraints.maxHeight;
      // Ty le: tuong chiem 64% chieu cao, san 36%
      final floorY = h * 0.62;

      return Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Background phong (SVG) ─────────────────────
          Positioned.fill(
            child: SvgPicture.string(
              _svgRoom,
              fit: BoxFit.fill,
            ),
          ),

          // ── 2. Ke sach nho goc trai ───────────────────────
          Positioned(
            left: 0,
            top: floorY - h * 0.48,
            width: w * 0.14,
            height: h * 0.48,
            child: SvgPicture.string(_svgSmallShelf, fit: BoxFit.fill),
          ),

          // ── 3. TV treo tuong (giua) ───────────────────────
          Positioned(
            left: w * 0.28,
            top: h * 0.04,
            width: w * 0.28,
            height: h * 0.26,
            child: SvgPicture.string(_svgTV, fit: BoxFit.fill),
          ),

          // ── 4. Tu dung duoi TV ────────────────────────────
          Positioned(
            left: w * 0.26,
            top: h * 0.30,
            width: w * 0.32,
            height: h * 0.14,
            child: SvgPicture.string(_svgTVStand, fit: BoxFit.fill),
          ),

          // ── 5. Ke sach lon goc phai ───────────────────────
          Positioned(
            right: w * 0.16,
            top: h * 0.02,
            width: w * 0.22,
            height: h * 0.58,
            child: SvgPicture.string(_svgBookshelf, fit: BoxFit.fill),
          ),

          // ── 6. Cau thang + ban an goc phai ────────────────
          Positioned(
            right: 0,
            top: floorY - h * 0.18,
            width: w * 0.18,
            height: h * 0.18,
            child: SvgPicture.string(_svgDiningArea, fit: BoxFit.fill),
          ),

          // ── 7. Cay canh lon ───────────────────────────────
          Positioned(
            left: w * 0.14,
            top: floorY - h * 0.32,
            width: w * 0.12,
            height: h * 0.32,
            child: SvgPicture.string(_svgPlant, fit: BoxFit.fill),
          ),

          // ── 8. Tham oval ──────────────────────────────────
          Positioned(
            left: w * 0.22,
            top: floorY - h * 0.06,
            width: w * 0.42,
            height: h * 0.10,
            child: SvgPicture.string(_svgRug, fit: BoxFit.fill),
          ),

          // ── 9. Sofa ───────────────────────────────────────
          Positioned(
            left: w * 0.18,
            top: floorY - h * 0.22,
            width: w * 0.48,
            height: h * 0.22,
            child: SvgPicture.string(_svgSofa, fit: BoxFit.fill),
          ),

          // ── 10. Nhan vat ngoi tren sofa ───────────────────
          Positioned(
            left: w * 0.26,
            top: floorY - h * 0.22,
            width: w * 0.32,
            height: h * 0.20,
            child: _SofaCharacters(character: character),
          ),

          // ── 11. Ban ca phe ────────────────────────────────
          Positioned(
            left: w * 0.26,
            top: floorY - h * 0.05,
            width: w * 0.34,
            height: h * 0.08,
            child: SvgPicture.string(_svgCoffeeTable, fit: BoxFit.fill),
          ),

          // ── 12. Den san ───────────────────────────────────
          Positioned(
            left: w * 0.62,
            top: floorY - h * 0.22,
            width: w * 0.08,
            height: h * 0.22,
            child: SvgPicture.string(_svgFloorLamp, fit: BoxFit.fill),
          ),

          // ── 13. Thu cung di lai ───────────────────────────
          ..._buildPets(context, w, h, floorY),

          // ── 14. Top bar ───────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: _TopBar(
                isOwner: isOwner,
                house: house,
                onShop: onShop,
                onGacha: onGacha,
              ),
            ),
          ),

          // ── 15. Bottom bar ────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomBar(
              isOwner: isOwner,
              house: house,
              onShop: onShop,
              onVisitFriends: onVisitFriends,
              onFarm: onFarm,
              onGacha: onGacha,
              onPet: onPet,
            ),
          ),
        ],
      );
    });
  }

  List<Widget> _buildPets(
      BuildContext context, double w, double h, double floorY) {
    return house.pets.asMap().entries.map((entry) {
      final idx = entry.key;
      final pet = entry.value;
      final baseX = w * (0.12 + idx * 0.18).clamp(0.08, 0.68);
      final baseY = floorY + h * 0.02;

      return _WalkingPet(
        key: ValueKey(pet.id),
        pet: pet,
        bounceAnim: petBounce,
        startX: baseX,
        floorY: baseY,
        roomWidth: w,
        facingRight: idx.isEven,
        onTap: () => onPet(pet),
      );
    }).toList();
  }
}

// ─── Sofa Characters (2 nguoi ngoi) ──────────────────────────────────────────
class _SofaCharacters extends StatelessWidget {
  final CharacterModel? character;
  const _SofaCharacters({this.character});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Nhân vật user (ngồi)
        if (character != null)
          CharacterWidget(
            character: character!,
            mode: CharAnimMode.sit,
            size: 70,
          )
        else
          // Placeholder nếu chưa tạo nhân vật
          _DefaultSitPerson(
            hairColor: const Color(0xFF3D2B1F),
            shirtColor: const Color(0xFFFF8FAB),
          ),
        const SizedBox(width: 16),
        // Nhân vật thứ 2 (mặc định)
        _DefaultSitPerson(
          hairColor: const Color(0xFF1A1A1A),
          shirtColor: const Color(0xFF6BAED6),
        ),
      ],
    );
  }
}

class _DefaultSitPerson extends StatelessWidget {
  final Color hairColor;
  final Color shirtColor;
  const _DefaultSitPerson({required this.hairColor, required this.shirtColor});

  @override
  Widget build(BuildContext context) {
    final skin = '#FFD5A8';
    final hair = '#${hairColor.r.round().toRadixString(16).padLeft(2,'0')}${hairColor.g.round().toRadixString(16).padLeft(2,'0')}${hairColor.b.round().toRadixString(16).padLeft(2,'0')}';
    final shirt = '#${shirtColor.r.round().toRadixString(16).padLeft(2,'0')}${shirtColor.g.round().toRadixString(16).padLeft(2,'0')}${shirtColor.b.round().toRadixString(16).padLeft(2,'0')}';
    final svg = '''<svg viewBox="0 0 80 100" xmlns="http://www.w3.org/2000/svg">
      <rect x="20" y="52" width="40" height="36" fill="$shirt" rx="8"/>
      <circle cx="40" cy="36" r="20" fill="$skin"/>
      <path d="M22 36 Q20 18 40 14 Q60 18 58 36 Q54 26 40 24 Q26 26 22 36 Z" fill="$hair"/>
      <circle cx="33" cy="34" r="3.5" fill="#2C2C2C"/>
      <circle cx="47" cy="34" r="3.5" fill="#2C2C2C"/>
      <circle cx="34" cy="33" r="1.2" fill="white"/>
      <circle cx="48" cy="33" r="1.2" fill="white"/>
      <path d="M35 44 Q40 49 45 44" fill="none" stroke="#C07A50" stroke-width="1.5" stroke-linecap="round"/>
      <ellipse cx="28" cy="40" r="5" fill="#FFB6C1" opacity="0.4"/>
      <ellipse cx="52" cy="40" r="5" fill="#FFB6C1" opacity="0.4"/>
    </svg>''';
    return SvgPicture.string(svg, width: 60, height: 75);
  }
}

// ─── Walking Pet ──────────────────────────────────────────────────────────────
class _WalkingPet extends StatefulWidget {
  final PetData pet;
  final Animation<double> bounceAnim;
  final double startX;
  final double floorY;
  final double roomWidth;
  final bool facingRight;
  final VoidCallback onTap;

  const _WalkingPet({
    super.key,
    required this.pet,
    required this.bounceAnim,
    required this.startX,
    required this.floorY,
    required this.roomWidth,
    required this.facingRight,
    required this.onTap,
  });

  @override
  State<_WalkingPet> createState() => _WalkingPetState();
}

class _WalkingPetState extends State<_WalkingPet>
    with SingleTickerProviderStateMixin {
  late AnimationController _walkCtrl;
  late Animation<double> _xAnim;
  late bool _facingRight;
  final _rng = Random();

  @override
  void initState() {
    super.initState();
    _facingRight = widget.facingRight;
    _walkCtrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: 3 + _rng.nextInt(3)),
    );
    // Khoi tao vi tri ban dau truoc khi goi _startWalk
    _xAnim = AlwaysStoppedAnimation<double>(widget.startX);
    _startWalk();
    _walkCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) setState(() => _facingRight = !_facingRight);
        _startWalk();
      }
    });
  }

  void _startWalk() {
    final minX = widget.roomWidth * 0.06;
    final maxX = widget.roomWidth * 0.70;
    final currentX = _xAnim.value;
    final delta = widget.roomWidth * (0.08 + _rng.nextDouble() * 0.18);
    final targetX = _facingRight ? currentX + delta : currentX - delta;
    final clamped = targetX.clamp(minX, maxX);

    _xAnim = Tween<double>(begin: currentX, end: clamped).animate(
      CurvedAnimation(parent: _walkCtrl, curve: Curves.easeInOut),
    );
    _walkCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _walkCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const petSize = 64.0;
    return AnimatedBuilder(
      animation: Listenable.merge([_walkCtrl, widget.bounceAnim]),
      builder: (_, child) {
        return Positioned(
          left: _xAnim.value - petSize / 2,
          top: widget.floorY + widget.bounceAnim.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.diagonal3Values(
                  _facingRight ? 1.0 : -1.0, 1.0, 1.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.string(
                    _petSvg(widget.pet.species, widget.pet.stage,
                        widget.pet.happiness),
                    width: petSize,
                    height: petSize,
                  ),
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      widget.pet.isEgg ? '🥚' : widget.pet.name,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF5C4033),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool isOwner;
  final HouseData house;
  final VoidCallback? onShop;
  final VoidCallback? onGacha;

  const _TopBar({
    required this.isOwner,
    required this.house,
    this.onShop,
    this.onGacha,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _CircleBtn(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Color(0xFF5C4033), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🏠', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    isOwner ? 'Nhà của tôi' : 'Nhà bạn bè',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5C4033),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Lv.${house.houseLevel}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isOwner && onGacha != null) ...[
            const SizedBox(width: 8),
            _CircleBtn(
              onTap: onGacha!,
              child: const Text('🎰', style: TextStyle(fontSize: 16)),
            ),
          ],
          if (isOwner && onShop != null) ...[
            const SizedBox(width: 6),
            _CircleBtn(
              onTap: onShop!,
              child: const Text('🛒', style: TextStyle(fontSize: 16)),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bottom Bar ───────────────────────────────────────────────────────────────
class _BottomBar extends StatelessWidget {
  final bool isOwner;
  final HouseData house;
  final VoidCallback? onShop;
  final VoidCallback? onVisitFriends;
  final VoidCallback? onFarm;
  final VoidCallback? onGacha;
  final void Function(PetData) onPet;

  const _BottomBar({
    required this.isOwner,
    required this.house,
    required this.onPet,
    this.onShop,
    this.onVisitFriends,
    this.onFarm,
    this.onGacha,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PetSlotsRow(house: house, onPet: onPet),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (isOwner && onShop != null)
                _ActionBtn(
                  emoji: '🛒',
                  label: 'Cửa hàng',
                  color: const Color(0xFFFFBE0B),
                  onTap: onShop!,
                ),
              if (isOwner && onGacha != null)
                _ActionBtn(
                  emoji: '🎰',
                  label: 'Rút thăm',
                  color: const Color(0xFF7C4DFF),
                  onTap: onGacha!,
                ),
              if (isOwner && onVisitFriends != null)
                _ActionBtn(
                  emoji: '👥',
                  label: 'Thăm bạn',
                  color: const Color(0xFF06D6A0),
                  onTap: onVisitFriends!,
                ),
              if (isOwner && onFarm != null)
                _ActionBtn(
                  emoji: '🌾',
                  label: 'Nông trại',
                  color: const Color(0xFF8BC34A),
                  onTap: onFarm!,
                ),
              if (!isOwner)
                _ActionBtn(
                  emoji: '👋',
                  label: 'Rời đi',
                  color: const Color(0xFFFF8C69),
                  onTap: () => Navigator.pop(context),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PetSlotsRow extends StatelessWidget {
  final HouseData house;
  final void Function(PetData) onPet;
  const _PetSlotsRow({required this.house, required this.onPet});

  @override
  Widget build(BuildContext context) {
    final maxPets = house.maxPets;
    return Row(
      children: [
        const Text('🐾', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 6),
        Text(
          'Thú cưng (${house.pets.length}/$maxPets)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5C4033),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(maxPets, (i) {
                final hasPet = i < house.pets.length;
                final pet = hasPet ? house.pets[i] : null;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: pet != null ? () => onPet(pet) : null,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: hasPet
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hasPet
                              ? const Color(0xFFF59E0B).withValues(alpha: 0.5)
                              : Colors.grey.shade300,
                          width: 1.5,
                        ),
                      ),
                      child: hasPet
                          ? Padding(
                              padding: const EdgeInsets.all(4),
                              child: SvgPicture.string(
                                _petSvg(pet!.species, pet.stage, pet.happiness),
                              ),
                            )
                          : const Center(
                              child: Text('➕',
                                  style: TextStyle(fontSize: 16))),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────
class _CircleBtn extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  const _CircleBtn({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.emoji,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: color.withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
