// character_creator_screen.dart — Màn hình tạo/chỉnh sửa nhân vật chibi
// ignore_for_file: library_private_types_in_public_api
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/character_model.dart';
import '../../data/services/character_service.dart';
import 'character_widget.dart';

class CharacterCreatorScreen extends StatefulWidget {
  final CharacterModel? initial;
  final bool isFirstTime;

  const CharacterCreatorScreen({
    super.key,
    this.initial,
    this.isFirstTime = false,
  });

  @override
  State<CharacterCreatorScreen> createState() => _CharacterCreatorScreenState();
}

class _CharacterCreatorScreenState extends State<CharacterCreatorScreen>
    with SingleTickerProviderStateMixin {
  late CharacterModel _char;
  late TabController _tabCtrl;
  bool _saving = false;

  static const _tabs = ['Cơ bản', 'Tóc', 'Trang phục', 'Phụ kiện'];

  @override
  void initState() {
    super.initState();
    _char = widget.initial ??
        (CharacterModel.defaultFemale);
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await CharacterService.saveCharacter(_char);
    if (mounted) {
      setState(() => _saving = false);
      if (widget.isFirstTime) {
        Navigator.pop(context, _char);
      } else {
        Navigator.pop(context, _char);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã lưu nhân vật!'),
            backgroundColor: Color(0xFF4CAF50),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: Column(
        children: [
          // ── Header ──────────────────────────────────────
          _Header(
            isFirstTime: widget.isFirstTime,
            onBack: () => Navigator.pop(context),
            onSave: _saving ? null : _save,
          ),

          // ── Preview nhân vật ────────────────────────────
          _CharPreview(character: _char),

          // ── Tab bar ─────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: const Color(0xFFFF8C69),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFFF8C69),
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: _tabs.map((t) => Tab(text: t)).toList(),
            ),
          ),

          // ── Tab content ─────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _BasicTab(
                  character: _char,
                  onChanged: (c) => setState(() => _char = c),
                ),
                _HairTab(
                  character: _char,
                  onChanged: (c) => setState(() => _char = c),
                ),
                _OutfitTab(
                  character: _char,
                  onChanged: (c) => setState(() => _char = c),
                ),
                _AccessoryTab(
                  character: _char,
                  onChanged: (c) => setState(() => _char = c),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final bool isFirstTime;
  final VoidCallback onBack;
  final VoidCallback? onSave;

  const _Header({
    required this.isFirstTime,
    required this.onBack,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFB347), Color(0xFFFF8C69)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              if (!isFirstTime)
                GestureDetector(
                  onTap: onBack,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 16),
                  ),
                ),
              if (!isFirstTime) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isFirstTime ? '✨ Tạo nhân vật của bạn' : '🎨 Chỉnh sửa nhân vật',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onSave,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: onSave == null
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFFFF8C69),
                          ),
                        )
                      : const Text(
                          'Lưu',
                          style: TextStyle(
                            color: Color(0xFFFF8C69),
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Character Preview ────────────────────────────────────────────────────────
class _CharPreview extends StatelessWidget {
  final CharacterModel character;
  const _CharPreview({required this.character});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFE0B2), Color(0xFFFFF8F0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Bóng tròn dưới chân
          Positioned(
            bottom: 20,
            child: Container(
              width: 80,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(40),
              ),
            ),
          ),
          // Nhân vật
          CharacterWidget(
            character: character,
            mode: CharAnimMode.idle,
            size: 110,
          ).animate().fadeIn(duration: 300.ms).scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 300.ms,
                curve: Curves.elasticOut,
              ),
          // Tên nhân vật
          Positioned(
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Text(
                character.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5C4033),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Basic Tab ────────────────────────────────────────────────────────────────
class _BasicTab extends StatelessWidget {
  final CharacterModel character;
  final ValueChanged<CharacterModel> onChanged;
  const _BasicTab({required this.character, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Tên nhân vật
        _SectionTitle(title: '📝 Tên nhân vật'),
        const SizedBox(height: 8),
        TextField(
          controller: TextEditingController(text: character.name)
            ..selection = TextSelection.collapsed(offset: character.name.length),
          decoration: InputDecoration(
            hintText: 'Nhập tên nhân vật...',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (v) => onChanged(character.copyWith(name: v)),
        ),
        const SizedBox(height: 20),

        // Giới tính
        _SectionTitle(title: '👤 Giới tính'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _GenderCard(
                label: '👧 Nữ',
                selected: character.gender == CharGender.female,
                onTap: () => onChanged(character.copyWith(gender: CharGender.female)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GenderCard(
                label: '👦 Nam',
                selected: character.gender == CharGender.male,
                onTap: () => onChanged(character.copyWith(gender: CharGender.male)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Màu da
        _SectionTitle(title: '🎨 Màu da'),
        const SizedBox(height: 10),
        _ColorPicker(
          colors: kSkinColors,
          selectedIndex: character.skinColorIndex,
          onSelected: (i) => onChanged(character.copyWith(skinColorIndex: i)),
        ),
      ],
    );
  }
}

// ─── Hair Tab ─────────────────────────────────────────────────────────────────
class _HairTab extends StatelessWidget {
  final CharacterModel character;
  final ValueChanged<CharacterModel> onChanged;
  const _HairTab({required this.character, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle(title: '💇 Kiểu tóc'),
        const SizedBox(height: 10),
        _HairStylePicker(
          selected: character.hairStyle,
          onSelected: (s) => onChanged(character.copyWith(hairStyle: s)),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: '🎨 Màu tóc'),
        const SizedBox(height: 10),
        _ColorPicker(
          colors: kHairColors,
          selectedIndex: character.hairColorIndex,
          onSelected: (i) => onChanged(character.copyWith(hairColorIndex: i)),
          size: 36,
        ),
      ],
    );
  }
}

// ─── Outfit Tab ───────────────────────────────────────────────────────────────
class _OutfitTab extends StatelessWidget {
  final CharacterModel character;
  final ValueChanged<CharacterModel> onChanged;
  const _OutfitTab({required this.character, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle(title: '👗 Kiểu trang phục'),
        const SizedBox(height: 10),
        _OutfitPicker(
          selected: character.outfit,
          onSelected: (o) => onChanged(character.copyWith(outfit: o)),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: '🎨 Màu trang phục'),
        const SizedBox(height: 10),
        _ColorPicker(
          colors: kOutfitColors,
          selectedIndex: character.outfitColorIndex,
          onSelected: (i) => onChanged(character.copyWith(outfitColorIndex: i)),
          size: 36,
        ),
      ],
    );
  }
}

// ─── Accessory Tab ────────────────────────────────────────────────────────────
class _AccessoryTab extends StatelessWidget {
  final CharacterModel character;
  final ValueChanged<CharacterModel> onChanged;
  const _AccessoryTab({required this.character, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _SectionTitle(title: '🕶️ Kính'),
        const SizedBox(height: 10),
        _ToggleCard(
          label: 'Đeo kính',
          emoji: '��️',
          value: character.hasGlasses,
          onChanged: (v) => onChanged(character.copyWith(hasGlasses: v)),
        ),
        const SizedBox(height: 20),
        _SectionTitle(title: '🎩 Mũ'),
        const SizedBox(height: 10),
        _ToggleCard(
          label: 'Đội mũ',
          emoji: '🎩',
          value: character.hasHat,
          onChanged: (v) => onChanged(character.copyWith(hasHat: v)),
        ),
        if (character.hasHat) ...[
          const SizedBox(height: 12),
          _SectionTitle(title: '🎨 Màu mũ'),
          const SizedBox(height: 8),
          _ColorPicker(
            colors: kOutfitColors,
            selectedIndex: character.hatColorIndex,
            onSelected: (i) => onChanged(character.copyWith(hatColorIndex: i)),
            size: 36,
          ),
        ],
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF5C4033),
      ),
    );
  }
}

class _GenderCard extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _GenderCard({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFFF8C69) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFFFF8C69) : Colors.grey.shade200,
            width: 2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF8C69).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: selected ? Colors.white : const Color(0xFF5C4033),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final List<Color> colors;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double size;

  const _ColorPicker({
    required this.colors,
    required this.selectedIndex,
    required this.onSelected,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(colors.length, (i) {
        final sel = i == selectedIndex;
        return GestureDetector(
          onTap: () => onSelected(i),
          child: AnimatedContainer(
            duration: 150.ms,
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: colors[i],
              shape: BoxShape.circle,
              border: Border.all(
                color: sel ? const Color(0xFFFF8C69) : Colors.white,
                width: sel ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: colors[i].withValues(alpha: 0.4),
                  blurRadius: sel ? 10 : 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: sel
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : null,
          ),
        );
      }),
    );
  }
}

class _HairStylePicker extends StatelessWidget {
  final CharHairStyle selected;
  final ValueChanged<CharHairStyle> onSelected;
  const _HairStylePicker({required this.selected, required this.onSelected});

  static const _labels = {
    CharHairStyle.short: ('✂️', 'Ngắn'),
    CharHairStyle.medium: ('💆', 'Vừa'),
    CharHairStyle.long: ('👱', 'Dài'),
    CharHairStyle.ponytail: ('🎀', 'Đuôi ngựa'),
    CharHairStyle.twintail: ('🎎', 'Hai bím'),
    CharHairStyle.curly: ('🌀', 'Xoăn'),
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: CharHairStyle.values.map((style) {
        final sel = style == selected;
        final (emoji, label) = _labels[style]!;
        return GestureDetector(
          onTap: () => onSelected(style),
          child: AnimatedContainer(
            duration: 150.ms,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFFF8C69) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? const Color(0xFFFF8C69) : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF8C69).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : const Color(0xFF5C4033),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _OutfitPicker extends StatelessWidget {
  final CharOutfit selected;
  final ValueChanged<CharOutfit> onSelected;
  const _OutfitPicker({required this.selected, required this.onSelected});

  static const _labels = {
    CharOutfit.casual: ('👕', 'Thường ngày'),
    CharOutfit.school: ('🎒', 'Học sinh'),
    CharOutfit.sport: ('🏃', 'Thể thao'),
    CharOutfit.formal: ('👔', 'Lịch sự'),
    CharOutfit.cute: ('🌸', 'Dễ thương'),
    CharOutfit.cool: ('😎', 'Ngầu'),
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: CharOutfit.values.map((outfit) {
        final sel = outfit == selected;
        final (emoji, label) = _labels[outfit]!;
        return GestureDetector(
          onTap: () => onSelected(outfit),
          child: AnimatedContainer(
            duration: 150.ms,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: sel ? const Color(0xFFFF8C69) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? const Color(0xFFFF8C69) : Colors.grey.shade200,
                width: 1.5,
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF8C69).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : const Color(0xFF5C4033),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final String label;
  final String emoji;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleCard({
    required this.label,
    required this.emoji,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: value ? const Color(0xFFFF8C69).withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: value ? const Color(0xFFFF8C69) : Colors.grey.shade200,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5C4033),
                ),
              ),
            ),
            Switch(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFFF8C69),
            ),
          ],
        ),
      ),
    );
  }
}
