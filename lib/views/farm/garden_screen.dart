// ignore_for_file: library_private_types_in_public_api
import 'dart:async' show Timer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/farm_service.dart';
import '../../data/services/game_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// GardenScreen – "Khu Vườn Trên Mây"
// ═══════════════════════════════════════════════════════════════════════════

class GardenScreen extends StatefulWidget {
  const GardenScreen({super.key});

  @override
  State<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends State<GardenScreen>
    with TickerProviderStateMixin {
  // 🧑 Character position
  double _charFracX = 0.5;
  double _charFracY = 0.55;

  // ☁️ Cloud positions — chỉ dùng trong AnimatedBuilder, KHÔNG setState
  final List<double> _cloudX = [0.05, 0.38, 0.68, 0.85, 0.22];
  final List<double> _cloudY = [0.06, 0.03, 0.08, 0.05, 0.12];
  final List<double> _cloudSize = [36.0, 48.0, 32.0, 42.0, 28.0];

  // 🎬 Animation controllers
  late AnimationController _cloudCtrl;   // chỉ dùng trong RepaintBoundary
  late AnimationController _sunCtrl;
  late Animation<double> _sunRotate;
  late AnimationController _sparkleCtrl;
  late Animation<double> _sparkleAnim;

  // 🌾 Harvest particles
  final List<_ParticleData> _harvestParticles = [];
  late AnimationController _particleCtrl;

  final _rng = Random();

  @override
  void initState() {
    super.initState();

    // Cloud drift — KHÔNG addListener setState, chỉ dùng AnimatedBuilder
    _cloudCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    // Sun slow rotation
    _sunCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _sunRotate = Tween<double>(begin: 0, end: 2 * pi).animate(_sunCtrl);

    // Sparkle blink for ready crops
    _sparkleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _sparkleAnim = Tween<double>(begin: 0.2, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleCtrl, curve: Curves.easeInOut),
    );

    // Particle controller
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() => _harvestParticles.clear());
        }
      });
  }

  @override
  void dispose() {
    _cloudCtrl.dispose();
    _sunCtrl.dispose();
    _sparkleCtrl.dispose();
    _particleCtrl.dispose();
    super.dispose();
  }

  void _spawnHarvestParticles(Offset origin) {
    setState(() {
      _harvestParticles.clear();
      for (int i = 0; i < 10; i++) {
        _harvestParticles.add(_ParticleData(
          x: origin.dx + (_rng.nextDouble() - 0.5) * 60,
          y: origin.dy,
          vx: (_rng.nextDouble() - 0.5) * 3.5,
          vy: -(_rng.nextDouble() * 3 + 2),
          emoji: ['🌟', '✨', '🌾', '🍎', '🌱', '⭐'][_rng.nextInt(6)],
        ));
      }
    });
    _particleCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Chưa đăng nhập')),
      );
    }

    return StreamBuilder<FarmData>(
      stream: FarmService.farmStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF87CEEB),
            body: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }
        final farm = snap.data ?? FarmData.defaultFarm();
        return _buildScene(context, farm);
      },
    );
  }

  Widget _buildScene(BuildContext context, FarmData farm) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF87CEEB),
      body: GestureDetector(
        onTapDown: (d) {
          // Move character only outside HUD area
          if (d.localPosition.dy > size.height * 0.16 &&
              d.localPosition.dy < size.height * 0.78) {
            setState(() {
              _charFracX =
                  (d.localPosition.dx / size.width).clamp(0.05, 0.95);
              _charFracY =
                  (d.localPosition.dy / size.height).clamp(0.18, 0.78);
            });
          }
        },
        child: Stack(
          children: [
            // ☀️ 1. Sky gradient background
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF6EC6F5), // sky blue
                      Color(0xFFB8D9F8), // light blue
                      Color(0xFFD8C8F0), // lavender
                      Color(0xFFF5D0E8), // blush pink
                    ],
                    stops: [0.0, 0.35, 0.65, 1.0],
                  ),
                ),
              ),
            ),

            // 🌈 2. Rainbow — static, no animation needed
            Positioned(
              top: size.height * 0.04,
              left: -size.width * 0.15,
              child: Opacity(
                opacity: 0.12,
                child: Text(
                  '🌈',
                  style: TextStyle(fontSize: size.width * 0.65),
                ),
              ),
            ),

            // ⭐ 3. Twinkling stars — wrapped in RepaintBoundary
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _sparkleAnim,
                builder: (_, __) => Stack(
                  children: List.generate(8, (i) {
                    const positions = [
                      [0.08, 0.04], [0.22, 0.02], [0.45, 0.05],
                      [0.60, 0.03], [0.75, 0.07], [0.88, 0.02],
                      [0.15, 0.10], [0.55, 0.09],
                    ];
                    final opacity = i % 2 == 0
                        ? _sparkleAnim.value
                        : 1.0 - _sparkleAnim.value + 0.2;
                    return Positioned(
                      left: positions[i][0] * size.width,
                      top: positions[i][1] * size.height,
                      child: Opacity(
                        opacity: opacity.clamp(0.1, 1.0),
                        child: const Text('⭐',
                            style: TextStyle(fontSize: 11)),
                      ),
                    );
                  }),
                ),
              ),
            ),

            // ☁️ 4. Drifting clouds — RepaintBoundary + AnimatedBuilder
            // KHÔNG dùng setState, chỉ rebuild layer này
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _cloudCtrl,
                builder: (_, __) {
                  final t = _cloudCtrl.value; // 0.0 → 1.0
                  return Stack(
                    children: List.generate(_cloudX.length, (i) {
                      final drift = ((_cloudX[i] + t * 0.35 * (i % 3 + 1)) % 1.25);
                      return Positioned(
                        left: drift * size.width - _cloudSize[i] / 2,
                        top: _cloudY[i] * size.height,
                        child: Opacity(
                          opacity: 0.82,
                          child: Text(
                            '☁️',
                            style: TextStyle(fontSize: _cloudSize[i]),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),

            // ☀️ 5. Sun — RepaintBoundary
            Positioned(
              top: 18,
              right: 22,
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _sunRotate,
                  builder: (_, __) => Transform.rotate(
                    angle: _sunRotate.value,
                    child: const Text('☀️',
                        style: TextStyle(fontSize: 44)),
                  ),
                ),
              ),
            ),

            // ☁️ 6. Cloud island (CustomPainter)
            Positioned(
              top: size.height * 0.26,
              left: 0,
              right: 0,
              height: size.height * 0.56,
              child: Stack(
                children: [
                  // Cloud body
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CloudPlatformPainter(),
                    ),
                  ),
                  // Grass on island
                  Positioned(
                    top: size.height * 0.56 * 0.28,
                    left: 0,
                    right: 0,
                    height: 22,
                    child: CustomPaint(
                      painter: _IslandGrassPainter(),
                    ),
                  ),
                ],
              ),
            ),

            // 🌱 7. Plot grid on island
            Positioned(
              top: size.height * 0.38,
              left: 0,
              right: 0,
              bottom: 0,
              child: _PlotGrid(
                farm: farm,
                sparkleAnim: _sparkleAnim,
                onHarvest: _spawnHarvestParticles,
              ),
            ),

            // 🧑 8. Character (animated position)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              left: _charFracX * size.width - 20,
              top: _charFracY * size.height - 42,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🧑', style: TextStyle(fontSize: 36)),
                  Container(
                    width: 22,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),

            // ✨ 9. Harvest particles
            if (_harvestParticles.isNotEmpty)
              AnimatedBuilder(
                animation: _particleCtrl,
                builder: (_, __) {
                  final t = _particleCtrl.value;
                  return Stack(
                    children: _harvestParticles.map((p) {
                      final px = p.x + p.vx * t * 80;
                      final py = p.y + p.vy * t * 80;
                      return Positioned(
                        left: px,
                        top: py,
                        child: Opacity(
                          opacity: (1.0 - t).clamp(0.0, 1.0),
                          child: Text(
                            p.emoji,
                            style: TextStyle(
                              fontSize: 18 + (1 - t) * 8,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),

            // 🎮 10. Top HUD
            SafeArea(
              child: _TopHud(
                farm: farm,
                onBack: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Particle Data
// ═══════════════════════════════════════════════════════════════════════════

class _ParticleData {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final String emoji;

  const _ParticleData({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.emoji,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
// _CloudPlatformPainter – vẽ đảo mây trắng bồng bềnh
// ═══════════════════════════════════════════════════════════════════════════

class _CloudPlatformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shadow layer
    final shadowPaint = Paint()
      ..color = const Color(0xFF9BB8D4).withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);

    // Main white cloud paint
    final cloudPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..style = PaintingStyle.fill;

    // Subtle lavender tint at bottom
    final tintPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          const Color(0xFFE8D5FF).withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromLTWH(0, h * 0.5, w, h * 0.5));

    // Build cloud island path with bumpy top edge
    final path = Path();
    path.moveTo(0, h * 0.55);

    // Left bumps
    path.quadraticBezierTo(w * 0.04, h * 0.18, w * 0.10, h * 0.38);
    path.quadraticBezierTo(w * 0.14, h * 0.08, w * 0.22, h * 0.30);
    path.quadraticBezierTo(w * 0.27, -h * 0.04, w * 0.34, h * 0.22);
    // Center peak
    path.quadraticBezierTo(w * 0.40, h * 0.02, w * 0.50, h * 0.18);
    path.quadraticBezierTo(w * 0.56, -h * 0.02, w * 0.62, h * 0.20);
    // Right bumps
    path.quadraticBezierTo(w * 0.68, h * 0.04, w * 0.74, h * 0.28);
    path.quadraticBezierTo(w * 0.80, h * 0.06, w * 0.87, h * 0.32);
    path.quadraticBezierTo(w * 0.93, h * 0.14, w, h * 0.48);

    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    // Draw shadow first
    canvas.drawPath(path, shadowPaint);
    // Draw cloud body
    canvas.drawPath(path, cloudPaint);
    // Draw tint overlay
    canvas.drawPath(path, tintPaint);

    // Extra small cloud puffs on the sides for depth
    _drawPuff(canvas, Offset(w * 0.05, h * 0.52), 28, 0.7);
    _drawPuff(canvas, Offset(w * 0.92, h * 0.50), 32, 0.65);
    _drawPuff(canvas, Offset(w * 0.50, h * 0.16), 22, 0.5);
  }

  void _drawPuff(Canvas canvas, Offset center, double radius, double opacity) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);
    canvas.drawCircle(
        center.translate(-radius * 0.6, radius * 0.2), radius * 0.7, paint);
    canvas.drawCircle(
        center.translate(radius * 0.6, radius * 0.2), radius * 0.7, paint);
  }

  @override
  bool shouldRepaint(_CloudPlatformPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// _IslandGrassPainter – vẽ dải cỏ xanh trên đảo
// ═══════════════════════════════════════════════════════════════════════════

class _IslandGrassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final grassPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF6DBF67), Color(0xFF4CAF50)],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, h * 0.5);

    // Wavy grass top
    double x = 0;
    const step = 18.0;
    bool up = true;
    while (x < w) {
      final nx = (x + step).clamp(0.0, w);
      final ny = up ? 0.0 : h * 0.5;
      path.quadraticBezierTo(x + step / 2, ny, nx, h * 0.25);
      x = nx;
      up = !up;
    }

    path.lineTo(w, h);
    path.lineTo(0, h);
    path.close();

    canvas.drawPath(path, grassPaint);

    // Grass highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final hlPath = Path();
    hlPath.moveTo(0, h * 0.1);
    hlPath.lineTo(w, h * 0.1);
    hlPath.lineTo(w, h * 0.4);
    hlPath.lineTo(0, h * 0.4);
    hlPath.close();
    canvas.drawPath(hlPath, highlightPaint);
  }

  @override
  bool shouldRepaint(_IslandGrassPainter old) => false;
}

// ═══════════════════════════════════════════════════════════════════════════
// _PlotGrid – lưới ô đất 3 cột
// ═══════════════════════════════════════════════════════════════════════════

class _PlotGrid extends StatelessWidget {
  final FarmData farm;
  final Animation<double> sparkleAnim;
  final void Function(Offset) onHarvest;

  const _PlotGrid({
    required this.farm,
    required this.sparkleAnim,
    required this.onHarvest,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
        ),
        itemCount: farm.unlockedPlots,
        itemBuilder: (context, i) {
          final plot = i < farm.plots.length
              ? farm.plots[i]
              : PlotData(plotId: 'plot_$i');
          return _PlotTile(
            plot: plot,
            sparkleAnim: sparkleAnim,
            onHarvest: onHarvest,
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _PlotTile – ô đất với animation
// ═══════════════════════════════════════════════════════════════════════════

class _PlotTile extends StatefulWidget {
  final PlotData plot;
  final Animation<double> sparkleAnim;
  final void Function(Offset) onHarvest;

  const _PlotTile({
    required this.plot,
    required this.sparkleAnim,
    required this.onHarvest,
  });

  @override
  State<_PlotTile> createState() => _PlotTileState();
}

class _PlotTileState extends State<_PlotTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _tapCtrl;
  late Animation<double> _tapScale;
  final GlobalKey _tileKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tapScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.25)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.25, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
    ]).animate(_tapCtrl);
  }

  @override
  void dispose() {
    _tapCtrl.dispose();
    super.dispose();
  }

  void _onTap(BuildContext context) {
    final plot = widget.plot.withComputedStage();
    if (plot.stage == 'empty') {
      _showPlantSheet(context);
    } else if (plot.isReady) {
      _harvest(context);
    } else {
      _showGrowingInfo(context, plot);
    }
  }

  void _harvest(BuildContext context) async {
    _tapCtrl.forward(from: 0);

    // Get tile center position for particles
    final box =
        _tileKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) {
      final pos = box.localToGlobal(
          Offset(box.size.width / 2, box.size.height / 2));
      widget.onHarvest(pos);
    }

    final ok = await FarmService.harvestCrop(widget.plot.plotId);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không thể thu hoạch lúc này'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showGrowingInfo(BuildContext context, PlotData plot) {
    final info = kCrops[plot.cropType];
    if (info == null) return;
    final remaining = plot.timeRemaining;
    final h = remaining.inHours;
    final m = remaining.inMinutes % 60;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: const Color(0xFFF8F4FF),
        title: Row(
          children: [
            Text(info.emoji,
                style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 8),
            Text(info.type,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A148C))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tiến độ tăng trưởng:',
                style: TextStyle(
                    fontSize: 12, color: Color(0xFF7B1FA2))),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: plot.growthProgress,
                backgroundColor:
                    const Color(0xFFE1BEE7),
                valueColor: const AlwaysStoppedAnimation(
                    Color(0xFF9C27B0)),
                minHeight: 12,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Text('⏰ ',
                    style: TextStyle(fontSize: 14)),
                Text(
                  h > 0
                      ? 'Còn ${h}h ${m}m nữa'
                      : 'Còn ${m}m nữa',
                  style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6A1B9A),
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(color: Color(0xFF9C27B0))),
          ),
        ],
      ),
    );
  }

  void _showPlantSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PlantSheet(plotId: widget.plot.plotId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plot = widget.plot.withComputedStage();
    final info =
        plot.cropType != null ? kCrops[plot.cropType!] : null;

    return GestureDetector(
      key: _tileKey,
      onTap: () => _onTap(context),
      child: ScaleTransition(
        scale: _tapScale,
        child: _buildTileDecoration(plot, info),
      ),
    );
  }

  Widget _buildTileDecoration(PlotData plot, CropInfo? info) {
    Color borderColor;
    Color bgColor;
    List<BoxShadow> shadows;

    if (plot.stage == 'empty') {
      borderColor = const Color(0xFFB39DDB).withValues(alpha: 0.6);
      bgColor = const Color(0xFFF3EAD3);
      shadows = [
        BoxShadow(
          color: Colors.brown.withValues(alpha: 0.12),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ];
    } else if (plot.isReady) {
      borderColor = const Color(0xFFFFD700);
      bgColor = const Color(0xFFFFF9E6);
      shadows = [
        BoxShadow(
          color: const Color(0xFFFFD700).withValues(alpha: 0.4),
          blurRadius: 14,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: Colors.orange.withValues(alpha: 0.15),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ];
    } else {
      borderColor = const Color(0xFF81C784).withValues(alpha: 0.7);
      bgColor = const Color(0xFFEDF7ED);
      shadows = [
        BoxShadow(
          color: Colors.green.withValues(alpha: 0.12),
          blurRadius: 6,
          offset: const Offset(0, 3),
        ),
      ];
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor,
          width: plot.isReady ? 2.5 : 1.5,
        ),
        boxShadow: shadows,
      ),
      child: _buildTileContent(plot, info),
    );
  }

  Widget _buildTileContent(PlotData plot, CropInfo? info) {
    if (plot.stage == 'empty') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF4CAF50).withValues(alpha: 0.5),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: Color(0xFF388E3C),
              size: 20,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Trồng cây',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF5D4037),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (plot.isReady) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: widget.sparkleAnim,
            builder: (_, __) => Transform.scale(
              scale: 0.9 + widget.sparkleAnim.value * 0.15,
              child: Text(
                info?.emoji ?? '🌱',
                style: const TextStyle(fontSize: 30),
              ),
            ),
          ),
          const SizedBox(height: 2),
          AnimatedBuilder(
            animation: widget.sparkleAnim,
            builder: (_, __) => Opacity(
              opacity: widget.sparkleAnim.value,
              child: const Text('✨', style: TextStyle(fontSize: 10)),
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8F00), Color(0xFFFFCA28)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
            child: const Text(
              'Thu hoạch!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    }

    // Growing stage
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            info?.emoji ?? '🌱',
            style: const TextStyle(fontSize: 26),
          ),
          const SizedBox(height: 4),
          // Thin linear bar — nhẹ hơn CircularProgressIndicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: plot.growthProgress,
                backgroundColor: const Color(0xFFE1BEE7),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF66BB6A)),
                minHeight: 5,
              ),
            ),
          ),
          const SizedBox(height: 3),
          // Countdown text — không quay vòng
          _CountdownText(timeRemaining: plot.timeRemaining),
        ],
      ),
    );
  }

}

// ═══════════════════════════════════════════════════════════════════════════
// _PlantSheet – bottom sheet chọn cây trồng
// ═══════════════════════════════════════════════════════════════════════════

class _PlantSheet extends StatelessWidget {
  final String plotId;
  const _PlantSheet({required this.plotId});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.42,
      maxChildSize: 0.90,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2D1B4E),
              Color(0xFF1E0A3C),
              Color(0xFF0D0520),
            ],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.purple.shade300.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🌱', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                const Text(
                  'Chọn loại cây',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('🌿', style: TextStyle(fontSize: 20)),
              ],
            ),

            // Coin display
            const SizedBox(height: 8),
            StreamBuilder<int>(
              stream: GameService.coinsStream(),
              builder: (context, snap) {
                final coins = snap.data ?? 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCA28).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFFFCA28).withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🪙',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 5),
                      Text(
                        '$coins coin',
                        style: const TextStyle(
                          color: Color(0xFFFFCA28),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 14),
            const Divider(
                color: Color(0xFF4A2080), height: 1),
            const SizedBox(height: 8),

            // Crop grid
            Expanded(
              child: StreamBuilder<int>(
                stream: GameService.coinsStream(),
                builder: (context, coinSnap) {
                  final coins = coinSnap.data ?? 0;
                  final crops = kCrops.values.toList();

                  return GridView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
                    ),
                    itemCount: crops.length,
                    itemBuilder: (context, i) {
                      final info = crops[i];
                      final canAfford = coins >= info.seedCost;
                      final h = info.growTime.inHours;
                      final m = info.growTime.inMinutes % 60;
                      final timeStr = h > 0
                          ? '${h}h${m > 0 ? ' ${m}m' : ''}'
                          : '${m}m';

                      return GestureDetector(
                        onTap: canAfford
                            ? () async {
                                Navigator.pop(context);
                                final ok = await FarmService.plantCrop(
                                    plotId, info.type);
                                if (!ok && context.mounted) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Không đủ coin (cần ${info.seedCost} 🪙)'),
                                      behavior:
                                          SnackBarBehavior.floating,
                                      backgroundColor:
                                          const Color(0xFF6A1B9A),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            gradient: canAfford
                                ? const LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF4A2080),
                                      Color(0xFF3D1A6E),
                                    ],
                                  )
                                : null,
                            color: canAfford
                                ? null
                                : const Color(0xFF1A1A2E),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: canAfford
                                  ? const Color(0xFFB39DDB)
                                      .withValues(alpha: 0.7)
                                  : Colors.grey.withValues(alpha: 0.2),
                              width: 1.5,
                            ),
                            boxShadow: canAfford
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF9C27B0)
                                          .withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              children: [
                                // Emoji
                                Text(
                                  info.emoji,
                                  style: TextStyle(
                                    fontSize: canAfford ? 30 : 24,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Name
                                Text(
                                  info.type,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: canAfford
                                        ? Colors.white
                                        : Colors.grey.shade500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                // Time
                                Text(
                                  '⏱ $timeStr',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: canAfford
                                        ? Colors.purple.shade200
                                        : Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Seed cost badge
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: canAfford
                                        ? const Color(0xFFFFCA28)
                                            .withValues(alpha: 0.2)
                                        : Colors.grey
                                            .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                      color: canAfford
                                          ? const Color(0xFFFFCA28)
                                              .withValues(alpha: 0.6)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text('🪙',
                                          style:
                                              TextStyle(fontSize: 10)),
                                      const SizedBox(width: 3),
                                      Text(
                                        '${info.seedCost}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                          color: canAfford
                                              ? const Color(0xFFFFD700)
                                              : Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _TopHud – HUD trên cùng
// ═══════════════════════════════════════════════════════════════════════════

class _TopHud extends StatelessWidget {
  final FarmData farm;
  final VoidCallback onBack;

  const _TopHud({required this.farm, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C27B0).withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF9C27B0).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF9C27B0).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: Color(0xFF7B1FA2),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Title
          const Text(
            '☁️ Vườn Trên Mây',
            style: TextStyle(
              color: Color(0xFF4A148C),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.3,
            ),
          ),

          const Spacer(),

          // Coin counter (stream)
          StreamBuilder<int>(
            stream: GameService.coinsStream(),
            builder: (context, snap) {
              final coins = snap.data ?? 0;
              return _HudBadge(
                icon: '🪙',
                label: '$coins',
                color: const Color(0xFFFF8F00),
              );
            },
          ),
          const SizedBox(width: 6),

          // Warehouse badge
          _HudBadge(
            icon: '🏠',
            label: '${farm.warehouseUsed}/${farm.warehouseCapacity}',
            color: const Color(0xFF7B1FA2),
          ),
          const SizedBox(width: 6),

          // Ready crops badge
          if (farm.readyCrops > 0)
            _HudBadge(
              icon: '✅',
              label: '${farm.readyCrops}',
              color: const Color(0xFF2E7D32),
            ),
        ],
      ),
    );
  }
}

class _HudBadge extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;

  const _HudBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _HarvestParticle – animation thu hoạch (confetti bay lên)
// ═══════════════════════════════════════════════════════════════════════════

class _HarvestParticle extends StatefulWidget {
  final Offset origin;
  final String emoji;
  final double vx;
  final double vy;

  const _HarvestParticle({
    required this.origin,
    required this.emoji,
    required this.vx,
    required this.vy,
  });

  @override
  State<_HarvestParticle> createState() => _HarvestParticleState();
}

class _HarvestParticleState extends State<_HarvestParticle>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..forward();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final t = _anim.value;
        final x = widget.origin.dx + widget.vx * t * 90;
        final y = widget.origin.dy + widget.vy * t * 90 + 0.5 * 9.8 * t * t * 20;
        return Positioned(
          left: x,
          top: y,
          child: Opacity(
            opacity: (1.0 - t).clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: t * pi * 2 * (widget.vx > 0 ? 1 : -1),
              child: Text(
                widget.emoji,
                style: TextStyle(fontSize: 16 + (1 - t) * 8),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _CountdownText — hiển thị đếm ngược thời gian trồng cây
// Dùng Timer.periodic riêng, KHÔNG rebuild parent widget
// ═══════════════════════════════════════════════════════════════════════════

class _CountdownText extends StatefulWidget {
  final Duration timeRemaining;
  const _CountdownText({required this.timeRemaining});

  @override
  State<_CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<_CountdownText> {
  late Duration _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.timeRemaining;
    if (_remaining.inSeconds > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _remaining = _remaining - const Duration(seconds: 1);
          if (_remaining.isNegative) {
            _remaining = Duration.zero;
            _timer?.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _fmt(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds % 60}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _remaining.inSeconds <= 0 ? '✅ Xong!' : _fmt(_remaining),
      style: const TextStyle(
        fontSize: 9,
        color: Color(0xFF5D4037),
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
