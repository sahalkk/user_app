import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

// ─────────────────────────────────────────────
//  Skeleton loaders with a diagonal shimmer sweep
// ─────────────────────────────────────────────
//
// Every loading state in the app uses these instead of a spinner:
//  • [SkeletonBox]   — grey placeholder shape for content that's still loading
//  • [ShimmerSweep]  — light band swept over real UI that's busy (buttons,
//                      tiles mid-action) without replacing it
//  • [ShimmerText]   — status label with the band running through the glyphs
//
// All of them share one clock, and [SkeletonBox] paints its gradient in
// screen space, so every box on screen shows a slice of the same diagonal
// band — it reads as one sweep across the whole layout, not many tiny ones.

const Color kSkeletonBase = Color(0xFFECEEF1);
const Color kSkeletonHighlight = Color(0xFFF9FAFB);

const Duration _kPeriod = Duration(milliseconds: 1600);

/// Fraction of each period spent sweeping; the rest is a short rest so the
/// band doesn't feel like it loops frantically.
const double _kSweepFraction = 0.8;

/// Tilt of the band's travel direction (≈22°), which makes it diagonal.
const double _kAngle = 0.38;

/// Shared animation clock. Ticks only while at least one shimmer is listening.
class _ShimmerClock extends ChangeNotifier {
  final Stopwatch _stopwatch = Stopwatch()..start();
  Ticker? _ticker;
  int _listeners = 0;

  /// Eased 0→1 progress of the band across its travel range.
  double get progress {
    final raw = (_stopwatch.elapsedMilliseconds % _kPeriod.inMilliseconds) /
        _kPeriod.inMilliseconds;
    return Curves.easeInOutSine
        .transform((raw / _kSweepFraction).clamp(0.0, 1.0));
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    if (_listeners++ == 0) {
      _ticker = Ticker((_) => notifyListeners())..start();
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (--_listeners == 0) {
      _ticker?.dispose();
      _ticker = null;
    }
  }
}

final _ShimmerClock _clock = _ShimmerClock();

/// Diagonal base→highlight→base gradient whose band sits at [progress] of
/// its travel across [area], expressed in [area]'s coordinate space.
Shader _bandShader({
  required Rect area,
  required double progress,
  required List<Color> colors,
}) {
  final dir = Offset(math.cos(_kAngle), math.sin(_kAngle));
  // How far the band must travel (projected onto [dir]) to cross [area].
  final extent = area.width * dir.dx + area.height * dir.dy;
  final halfBand = (area.shortestSide * 0.6).clamp(40.0, 160.0);
  final centre = -halfBand + (extent + halfBand * 2) * progress;
  final from = area.topLeft + dir * (centre - halfBand);
  final to = area.topLeft + dir * (centre + halfBand);
  return ui.Gradient.linear(from, to, colors, const [0.0, 0.5, 1.0]);
}

// ── SkeletonBox ───────────────────────────────

/// A grey placeholder shape that shimmers. Sizes itself to [width]/[height]
/// when given, otherwise fills its constraints (so it drops straight into
/// image placeholders, `Expanded`, `AspectRatio`, etc.).
class SkeletonBox extends LeafRenderObjectWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  final bool circle;

  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  }) : circle = false;

  const SkeletonBox.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = BorderRadius.zero,
        circle = true;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderSkeletonBox(
        width: width,
        height: height,
        borderRadius: borderRadius,
        circle: circle,
        screen: MediaQuery.sizeOf(context),
      );

  @override
  void updateRenderObject(
      BuildContext context, RenderSkeletonBox renderObject) {
    renderObject
      ..width = width
      ..height = height
      ..borderRadius = borderRadius
      ..circle = circle
      ..screen = MediaQuery.sizeOf(context);
  }
}

class RenderSkeletonBox extends RenderBox {
  RenderSkeletonBox({
    required double? width,
    required double? height,
    required BorderRadius borderRadius,
    required bool circle,
    required Size screen,
  })  : _width = width,
        _height = height,
        _borderRadius = borderRadius,
        _circle = circle,
        _screen = screen;

  double? _width;
  set width(double? v) {
    if (v == _width) return;
    _width = v;
    markNeedsLayout();
  }

  double? _height;
  set height(double? v) {
    if (v == _height) return;
    _height = v;
    markNeedsLayout();
  }

  BorderRadius _borderRadius;
  set borderRadius(BorderRadius v) {
    if (v == _borderRadius) return;
    _borderRadius = v;
    markNeedsPaint();
  }

  bool _circle;
  set circle(bool v) {
    if (v == _circle) return;
    _circle = v;
    markNeedsPaint();
  }

  Size _screen;
  set screen(Size v) {
    if (v == _screen) return;
    _screen = v;
    markNeedsPaint();
  }

  // Repaints every frame, so keep that from dirtying whatever it sits in.
  @override
  bool get isRepaintBoundary => true;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _clock.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _clock.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    double resolve(double? want, double max) =>
        want ?? (max.isFinite ? max : 0);
    size = constraints.constrain(Size(
      resolve(_width, constraints.maxWidth),
      resolve(_height, constraints.maxHeight),
    ));
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    double resolve(double? want, double max) =>
        want ?? (max.isFinite ? max : 0);
    return constraints.constrain(Size(
      resolve(_width, constraints.maxWidth),
      resolve(_height, constraints.maxHeight),
    ));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (size.isEmpty) return;
    // Place the band in screen space, then shift it into this box's canvas.
    final global = localToGlobal(Offset.zero);
    final screenRect = (Offset.zero & _screen).shift(offset - global);
    final paint = Paint()
      ..shader = _bandShader(
        area: screenRect,
        progress: _clock.progress,
        colors: const [kSkeletonBase, kSkeletonHighlight, kSkeletonBase],
      );
    final rect = offset & size;
    final canvas = context.canvas;
    if (_circle) {
      canvas.drawOval(rect, paint);
    } else {
      canvas.drawRRect(_borderRadius.toRRect(rect), paint);
    }
  }
}

/// [Image.network] `loadingBuilder` that shows a shimmering skeleton until
/// the image has bytes.
Widget skeletonImageLoadingBuilder(
        BuildContext context, Widget child, ImageChunkEvent? progress) =>
    progress == null ? child : const SkeletonBox(borderRadius: BorderRadius.zero);

/// [CachedNetworkImage] `placeholder` that shows a shimmering skeleton.
Widget skeletonImagePlaceholder(BuildContext context, String url) =>
    const SkeletonBox(borderRadius: BorderRadius.zero);

// ── ShimmerSweep ──────────────────────────────

/// Sweeps a soft diagonal highlight across [child] while [active] — the
/// "working on it" signal for UI that stays visible while busy (a button
/// mid-submit, a row being applied). Doesn't block taps; callers already
/// disable their own controls.
class ShimmerSweep extends StatelessWidget {
  final bool active;
  final BorderRadius borderRadius;
  final Color color;
  final Widget child;

  const ShimmerSweep({
    super.key,
    required this.active,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.color = const Color(0x73FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    // Painter swaps in/out rather than the tree, so [child] keeps its state.
    return CustomPaint(
      foregroundPainter:
          active ? _SweepPainter(borderRadius: borderRadius, color: color) : null,
      child: child,
    );
  }
}

class _SweepPainter extends CustomPainter {
  final BorderRadius borderRadius;
  final Color color;

  _SweepPainter({required this.borderRadius, required this.color})
      : super(repaint: _clock);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.clipRRect(borderRadius.toRRect(rect));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = _bandShader(
          area: rect,
          progress: _clock.progress,
          colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)],
        ),
    );
  }

  @override
  bool shouldRepaint(_SweepPainter old) =>
      old.borderRadius != borderRadius || old.color != color;
}

// ── ShimmerText ───────────────────────────────

/// A status label (e.g. "Checking delivery availability…") with the
/// diagonal band running through its glyphs.
class ShimmerText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextAlign textAlign;
  final Color baseColor;
  final Color highlightColor;

  const ShimmerText(
    this.text, {
    super.key,
    required this.style,
    this.textAlign = TextAlign.center,
    this.baseColor = const Color(0xFF8A8A8A),
    this.highlightColor = const Color(0xFFDADADA),
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => _bandShader(
            area: bounds,
            progress: _clock.progress,
            colors: [baseColor, highlightColor, baseColor],
          ),
          child: child,
        ),
        child: Text(text, textAlign: textAlign, style: style),
      ),
    );
  }
}

/// Centered loading status: a shimmering icon badge over a [ShimmerText]
/// label. For waits that are about a *process* (checking, locating) rather
/// than content, where there's no layout to sketch with skeletons.
class ShimmerStatus extends StatelessWidget {
  final IconData icon;
  final String label;

  const ShimmerStatus({
    super.key,
    required this.label,
    this.icon = Icons.location_on_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShimmerSweep(
          active: true,
          borderRadius: BorderRadius.circular(32),
          color: const Color(0xA6FFFFFF),
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9), shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF3DAA5C), size: 30),
          ),
        ),
        const SizedBox(height: 18),
        ShimmerText(
          label,
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ── Composite skeletons ───────────────────────

/// Placeholder for a [ProductGrid]: same column math, product-card shapes
/// (square image, two title lines, price).
class ProductGridSkeleton extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  const ProductGridSkeleton({
    super.key,
    this.crossAxisCount = 3,
    this.itemCount = 9,
    this.crossAxisSpacing = 12,
    this.mainAxisSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth -
              crossAxisSpacing * (crossAxisCount - 1)) /
          crossAxisCount;
      return Wrap(
        spacing: crossAxisSpacing,
        runSpacing: mainAxisSpacing,
        children: List.generate(
          itemCount,
          (_) => SizedBox(
            width: itemWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AspectRatio(
                  aspectRatio: 1,
                  child: SkeletonBox(
                      borderRadius: BorderRadius.all(Radius.circular(16))),
                ),
                const SizedBox(height: 10),
                SkeletonBox(width: itemWidth * 0.9, height: 10),
                const SizedBox(height: 6),
                SkeletonBox(width: itemWidth * 0.6, height: 10),
                const SizedBox(height: 10),
                SkeletonBox(width: itemWidth * 0.4, height: 12),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Placeholder rows for list content: leading thumbnail + two text lines.
/// Covers search results, place suggestions and saved-address lists.
class ListTileSkeleton extends StatelessWidget {
  final int count;
  final double leadingSize;
  final bool circleLeading;
  final EdgeInsetsGeometry padding;

  /// Wrap each row in a white rounded card (saved-address style).
  final bool card;

  const ListTileSkeleton({
    super.key,
    this.count = 3,
    this.leadingSize = 40,
    this.circleLeading = false,
    this.padding = const EdgeInsets.symmetric(vertical: 10),
    this.card = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget row() {
      final content = Row(
        children: [
          circleLeading
              ? SkeletonBox.circle(size: leadingSize)
              : SkeletonBox(
                  width: leadingSize,
                  height: leadingSize,
                  borderRadius: BorderRadius.circular(10)),
          const SizedBox(width: 14),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: c.maxWidth * 0.45, height: 12),
                  const SizedBox(height: 8),
                  SkeletonBox(width: c.maxWidth * 0.85, height: 10),
                ],
              ),
            ),
          ),
        ],
      );
      if (!card) return Padding(padding: padding, child: content);
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: content,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (_) => row()),
    );
  }
}
