// responsive.dart — Responsive utility cho mọi màn hình
// Dùng: final r = Responsive(context);
// Sau đó: r.sp(14) cho font, r.w(16) cho padding, r.isTablet, v.v.

import 'package:flutter/material.dart';

// ─── Breakpoints ──────────────────────────────────────────────────────────────
// phone:        width < 600
// tablet:       600 <= width < 900
// largeTablet:  width >= 900

class Responsive {
  final BuildContext context;
  final MediaQueryData _mq;

  Responsive(this.context) : _mq = MediaQuery.of(context);

  // ── Screen dimensions ─────────────────────────────────
  double get screenW => _mq.size.width;
  double get screenH => _mq.size.height;
  double get shortSide => _mq.size.shortestSide;
  double get pixelRatio => _mq.devicePixelRatio;

  // ── Device type ───────────────────────────────────────
  bool get isPhone       => shortSide < 600;
  bool get isTablet      => shortSide >= 600 && shortSide < 900;
  bool get isLargeTablet => shortSide >= 900;
  bool get isAnyTablet   => shortSide >= 600;

  // ── Orientation ───────────────────────────────────────
  bool get isPortrait  => _mq.orientation == Orientation.portrait;
  bool get isLandscape => _mq.orientation == Orientation.landscape;

  // ── Safe area ─────────────────────────────────────────
  EdgeInsets get safeArea => _mq.padding;
  double get topPadding    => _mq.padding.top;
  double get bottomPadding => _mq.padding.bottom;

  // ── Responsive font size ──────────────────────────────
  // sp() scale font theo màn hình, giữ tỉ lệ đẹp
  double sp(double size) {
    if (isLargeTablet) return size * 1.35;
    if (isTablet)      return size * 1.18;
    return size;
  }

  // ── Responsive spacing / padding ─────────────────────
  // w() scale theo chiều rộng màn hình
  double w(double size) {
    if (isLargeTablet) return size * 1.4;
    if (isTablet)      return size * 1.2;
    return size;
  }

  // ── Icon size ─────────────────────────────────────────
  double icon(double size) {
    if (isLargeTablet) return size * 1.3;
    if (isTablet)      return size * 1.15;
    return size;
  }

  // ── Border radius ─────────────────────────────────────
  double r(double radius) {
    if (isLargeTablet) return radius * 1.3;
    if (isTablet)      return radius * 1.15;
    return radius;
  }

  // ── Grid columns ─────────────────────────────────────
  // Tự động tính số cột phù hợp
  int gridCols({int phone = 2, int tablet = 3, int largeTablet = 4}) {
    if (isLargeTablet) return largeTablet;
    if (isTablet)      return tablet;
    return phone;
  }

  // ── Content max width (cho tablet layout) ────────────
  // Giới hạn nội dung không quá rộng trên tablet
  double get contentMaxWidth {
    if (isLargeTablet) return 900;
    if (isTablet)      return 700;
    return screenW;
  }

  // ── Horizontal padding ────────────────────────────────
  double get hPad {
    if (isLargeTablet) return 32;
    if (isTablet)      return 24;
    return 16;
  }

  // ── Vertical padding ──────────────────────────────────
  double get vPad {
    if (isLargeTablet) return 24;
    if (isTablet)      return 20;
    return 16;
  }

  // ── Card elevation ────────────────────────────────────
  double get cardElevation {
    if (isAnyTablet) return 3;
    return 1;
  }

  // ── Bottom nav height ─────────────────────────────────
  double get navBarHeight {
    if (isLargeTablet) return 80;
    if (isTablet)      return 72;
    return 64;
  }

  // ── AppBar height ─────────────────────────────────────
  double get appBarHeight {
    if (isLargeTablet) return 70;
    if (isTablet)      return 64;
    return 56;
  }

  // ── Avatar / image sizes ──────────────────────────────
  double avatar(double base) => w(base);

  // ── Convenience: pick value by device ────────────────
  T pick<T>({required T phone, required T tablet, T? largeTablet}) {
    if (isLargeTablet) return largeTablet ?? tablet;
    if (isTablet)      return tablet;
    return phone;
  }
}

// ─── Extension on BuildContext ────────────────────────────────────────────────
// Dùng: context.r.sp(14) hoặc context.responsive.isTablet

extension ResponsiveContext on BuildContext {
  Responsive get r => Responsive(this);
  Responsive get responsive => Responsive(this);
}

// ─── ResponsiveBuilder widget ─────────────────────────────────────────────────
// Dùng khi cần build khác nhau hoàn toàn theo device

class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, Responsive r) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, Responsive(context));
  }
}

// ─── ResponsiveLayout widget ──────────────────────────────────────────────────
// Dùng khi muốn layout hoàn toàn khác nhau

class ResponsiveLayout extends StatelessWidget {
  final Widget phone;
  final Widget? tablet;
  final Widget? largeTablet;

  const ResponsiveLayout({
    super.key,
    required this.phone,
    this.tablet,
    this.largeTablet,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    if (r.isLargeTablet && largeTablet != null) return largeTablet!;
    if (r.isAnyTablet   && tablet      != null) return tablet!;
    return phone;
  }
}

// ─── Centered content wrapper cho tablet ─────────────────────────────────────
// Tự động center + giới hạn width trên tablet

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const ResponsiveCenter({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    if (!r.isAnyTablet) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? r.contentMaxWidth,
        ),
        child: child,
      ),
    );
  }
}
