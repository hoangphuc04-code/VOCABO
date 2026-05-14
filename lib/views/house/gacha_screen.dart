import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/services/house_service.dart';

// ignore_for_file: library_private_types_in_public_api

// ─────────────────────────────────────────────────────────────────────────────
// GachaScreen — Pet Gacha / Rút thăm trúng thưởng
// ─────────────────────────────────────────────────────────────────────────────

class GachaScreen extends StatefulWidget {
  const GachaScreen({super.key});

  @override
  State<GachaScreen> createState() => _GachaScreenState();
}

class _GachaScreenState extends State<GachaScreen> with TickerProviderStateMixin {
  late AnimationController _shakeCtrl;
  late AnimationController _revealCtrl;
  late AnimationController _glowCtrl;
  late Animation<double> _shakeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;

  bool _pulling = false;
  bool _revealed = false;
  GachaResult? _lastResult;
  GachaBatchResult? _lastBatchResult;
  bool _isBatch = false;

  // Gacha costs
  static const _singleCoinCost = 200;
  static const _singleDiamondCost = 5;
  static const _batchCoinCost = 1800;   // x10 = 10% discount
  static const _batchDiamondCost = 45;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _revealCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);

    _shakeAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.easeInOut));

    _scaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.95), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _revealCtrl, curve: Curves.easeOut));

    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _revealCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _pull({required bool batch, required String currency}) async {
    if (_pulling) return;
    setState(() { _pulling = true; _revealed = false; _lastResult = null; _lastBatchResult = null; _isBatch = batch; });

    // Shake animation
    await _shakeCtrl.forward(from: 0);

    if (batch) {
      final cost = currency == 'coins' ? _batchCoinCost : _batchDiamondCost;
      final result = await HouseService.gachaPull10(cost: cost, currency: currency);
      setState(() { _lastBatchResult = result; _pulling = false; });
      if (result.success) {
        _revealCtrl.forward(from: 0);
        setState(() => _revealed = true);
      } else if (result.isFull) {
        _showFullDialog(result.errorMessage!);
      } else {
        _showError(result.errorMessage!);
      }
    } else {
      final cost = currency == 'coins' ? _singleCoinCost : _singleDiamondCost;
      final result = await HouseService.gachaPull(cost: cost, currency: currency);
      setState(() { _lastResult = result; _pulling = false; });
      if (result.success) {
        _revealCtrl.forward(from: 0);
        setState(() => _revealed = true);
      } else if (result.isFull) {
        _showFullDialog(result.errorMessage!);
      } else {
        _showError(result.errorMessage!);
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showFullDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: const Color(0xFFFFF8E1),
        title: const Text('�� Đã đầy pet!', textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏠', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF5C4033))),
            const SizedBox(height: 8),
            const Text('Vào nhà → chọn pet → Thả để giải phóng slot.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C69), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Vào nhà'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Top bar ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('✨ Rút thăm Pet',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    // Currency display
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                      builder: (context, snap) {
                        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
                        final coins = (data['coins'] ?? 0).toInt();
                        final diamonds = (data['diamonds'] ?? 0).toInt();
                        return Row(
                          children: [
                            _CurrencyChip(icon: '🪙', value: coins),
                            const SizedBox(width: 6),
                            _CurrencyChip(icon: '💎', value: diamonds),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // ── Rates info ───────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _RatesCard(),
              ),

              const SizedBox(height: 16),

              // ── Gacha egg / reveal area ──────────────────
              Expanded(
                child: Center(
                  child: _revealed
                      ? (_isBatch ? _BatchReveal(result: _lastBatchResult!) : _SingleReveal(result: _lastResult!, scaleAnim: _scaleAnim, glowAnim: _glowAnim))
                      : _GachaEgg(shakeAnim: _shakeAnim, pulling: _pulling, glowAnim: _glowAnim),
                ),
              ),

              // ── Pull buttons ─────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  children: [
                    // Pet slots indicator
                    StreamBuilder<HouseData>(
                      stream: HouseService.houseStream(),
                      builder: (context, snap) {
                        final house = snap.data ?? HouseData.defaultHouse();
                        return _PetSlotsBar(current: house.pets.length, max: kMaxPetsAbsolute);
                      },
                    ),
                    const SizedBox(height: 16),
                    // x1 pull row
                    Row(
                      children: [
                        Expanded(child: _PullButton(
                          label: 'Rút x1',
                          cost: '$_singleCoinCost 🪙',
                          color: const Color(0xFFFFB347),
                          loading: _pulling,
                          onTap: () => _pull(batch: false, currency: 'coins'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _PullButton(
                          label: 'Rút x1',
                          cost: '$_singleDiamondCost 💎',
                          color: const Color(0xFF7C4DFF),
                          loading: _pulling,
                          onTap: () => _pull(batch: false, currency: 'diamonds'),
                        )),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // x10 pull row
                    Row(
                      children: [
                        Expanded(child: _PullButton(
                          label: 'Rút x10',
                          cost: '$_batchCoinCost 🪙',
                          sublabel: 'Đảm bảo 1 Hiếm+',
                          color: const Color(0xFFFF6B35),
                          loading: _pulling,
                          onTap: () => _pull(batch: true, currency: 'coins'),
                        )),
                        const SizedBox(width: 10),
                        Expanded(child: _PullButton(
                          label: 'Rút x10',
                          cost: '$_batchDiamondCost 💎',
                          sublabel: 'Đảm bảo 1 Hiếm+',
                          color: const Color(0xFF5C6BC0),
                          loading: _pulling,
                          onTap: () => _pull(batch: true, currency: 'diamonds'),
                        )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Gacha Egg (idle / pulling state)
// ─────────────────────────────────────────────────────────────────────────────

class _GachaEgg extends StatelessWidget {
  final Animation<double> shakeAnim;
  final Animation<double> glowAnim;
  final bool pulling;
  const _GachaEgg({required this.shakeAnim, required this.glowAnim, required this.pulling});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([shakeAnim, glowAnim]),
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Glow ring
          Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFD700).withValues(alpha: glowAnim.value * 0.5),
                  blurRadius: 40, spreadRadius: 10,
                ),
              ],
            ),
            child: Transform.translate(
              offset: Offset(shakeAnim.value, 0),
              child: Center(
                child: Text(
                  pulling ? '🥚' : '🎁',
                  style: const TextStyle(fontSize: 100),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            pulling ? 'Đang rút thăm...' : 'Nhấn để rút thăm!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tỉ lệ: Thường 60% | Hiếm 25% | Sử thi 12% | Huyền thoại 3%',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single Reveal
// ─────────────────────────────────────────────────────────────────────────────

class _SingleReveal extends StatelessWidget {
  final GachaResult result;
  final Animation<double> scaleAnim;
  final Animation<double> glowAnim;
  const _SingleReveal({required this.result, required this.scaleAnim, required this.glowAnim});

  @override
  Widget build(BuildContext context) {
    if (!result.success || result.roll == null) return const SizedBox.shrink();
    final roll = result.roll!;
    final info = kPetSpecies[roll.species]!;
    final rarity = roll.rarity;

    return AnimatedBuilder(
      animation: Listenable.merge([scaleAnim, glowAnim]),
      builder: (_, __) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Rarity label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: rarity.color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: rarity.color, width: 1.5),
            ),
            child: Text(
              '${rarity.glowEmoji} ${rarity.label.toUpperCase()}',
              style: TextStyle(color: rarity.color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),
          // Pet with glow
          Transform.scale(
            scale: scaleAnim.value,
            child: Container(
              width: 140, height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: rarity.color.withValues(alpha: glowAnim.value * 0.7),
                    blurRadius: 40, spreadRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: Text(info.eggEmoji, style: const TextStyle(fontSize: 90)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(info.displayName,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(info.description,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text('🥚 Trứng đang ấp trong nhà của bạn!',
                style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Batch Reveal (x10)
// ─────────────────────────────────────────────────────────────────────────────

class _BatchReveal extends StatelessWidget {
  final GachaBatchResult result;
  const _BatchReveal({required this.result});

  @override
  Widget build(BuildContext context) {
    if (!result.success) return const SizedBox.shrink();
    final rolls = result.rolls;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '🎉 Kết quả x10',
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (result.addedCount < 10)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
            ),
            child: Text(
              'Chỉ thêm được ${result.addedCount}/10 pet (slot đầy)',
              style: const TextStyle(color: Colors.orange, fontSize: 12),
            ),
          ),
        const SizedBox(height: 16),
        // Grid of 10 results
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10, runSpacing: 10,
            alignment: WrapAlignment.center,
            children: rolls.asMap().entries.map((e) {
              final i = e.key;
              final roll = e.value;
              final info = kPetSpecies[roll.species]!;
              final added = i < result.addedCount;
              return _GachaResultCard(roll: roll, info: info, added: added);
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _GachaResultCard extends StatelessWidget {
  final GachaRollInfo roll;
  final PetSpeciesInfo info;
  final bool added;
  const _GachaResultCard({required this.roll, required this.info, required this.added});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: added ? 1.0 : 0.4,
      child: Container(
        width: 64, height: 80,
        decoration: BoxDecoration(
          color: roll.rarity.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: roll.rarity.color.withValues(alpha: 0.6), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(info.eggEmoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(roll.rarity.glowEmoji, style: const TextStyle(fontSize: 12)),
            if (!added)
              const Text('FULL', style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Rates Card
// ─────────────────────────────────────────────────────────────────────────────

class _RatesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _RateChip(rarity: GachaRarity.common, rate: '60%'),
          _RateChip(rarity: GachaRarity.rare, rate: '25%'),
          _RateChip(rarity: GachaRarity.epic, rate: '12%'),
          _RateChip(rarity: GachaRarity.legendary, rate: '3%'),
        ],
      ),
    );
  }
}

class _RateChip extends StatelessWidget {
  final GachaRarity rarity;
  final String rate;
  const _RateChip({required this.rarity, required this.rate});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(rarity.glowEmoji, style: const TextStyle(fontSize: 16)),
        const SizedBox(height: 2),
        Text(rarity.label, style: TextStyle(color: rarity.color, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(rate, style: const TextStyle(color: Colors.white70, fontSize: 10)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pet Slots Bar
// ─────────────────────────────────────────────────────────────────────────────

class _PetSlotsBar extends StatelessWidget {
  final int current;
  final int max;
  const _PetSlotsBar({required this.current, required this.max});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Text('🐾', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text('Slot pet:', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
          const SizedBox(width: 8),
          Row(
            children: List.generate(max, (i) => Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: i < current
                      ? const Color(0xFFFFB347).withValues(alpha: 0.8)
                      : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: i < current ? const Color(0xFFFFB347) : Colors.white24,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(i < current ? '🐾' : '➕',
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            )),
          ),
          const Spacer(),
          Text('$current/$max',
              style: TextStyle(
                color: current >= max ? Colors.red.shade300 : Colors.white70,
                fontSize: 13, fontWeight: FontWeight.bold,
              )),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pull Button
// ─────────────────────────────────────────────────────────────────────────────

class _PullButton extends StatelessWidget {
  final String label;
  final String cost;
  final String? sublabel;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _PullButton({
    required this.label,
    required this.cost,
    required this.color,
    required this.loading,
    required this.onTap,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.7)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: loading
            ? const Center(child: SizedBox(width: 20, height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(cost, style: const TextStyle(color: Colors.white, fontSize: 12)),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel!, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 10)),
                  ],
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Currency Chip
// ─────────────────────────────────────────────────────────────────────────────

class _CurrencyChip extends StatelessWidget {
  final String icon;
  final int value;
  const _CurrencyChip({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text('$value', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
