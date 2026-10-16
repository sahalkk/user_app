import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/auth_bloc/auth_bloc.dart';
import '../../blocs/auth_bloc/auth_state.dart';
import '../../shared/utils/bloc_ready.dart';
import '../home/blocs/home_bloc.dart';
import '../main_wrapper.dart';

const _logoAsset = 'assets/icon/icon_foreground.png';
const _logoAspect = 1024 / 683; // icon_foreground.png pixel size
const _bagYellow = Color(0xFFFFC107);
const _shineGold = Color(0xFFFFCA28);
const _wordmark = 'Beeyo';

/// How long the "still loading" charge creeps for before it flattens out.
/// The charge isn't drawn; it brightens the glow, which builds toward ~88%
/// while loading and surges to full just before launch.
const _chargeLoadSeconds = 40;

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Phase 1: fly in from bottom-left.
  late final _entrance = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700));
  // Phase 2: endless hover loop. Every idle effect is a whole-number
  // multiple of this period, so wrapping around never jumps.
  late final _hover = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800));
  // Wordmark and rings easing in once the bee has landed.
  late final _settle = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  late final _chargeLoad = AnimationController(
      vsync: this, duration: const Duration(seconds: _chargeLoadSeconds));
  late final _chargeFinish = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 380));
  // Phase 3: anticipation + launch off the top-right.
  late final _exit = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));
  // Reduced-motion path: a plain fade in and out.
  late final _fade = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 300));

  late final _motion = _SplashMotion(
    entrance: _entrance,
    hover: _hover,
    settle: _settle,
    chargeLoad: _chargeLoad,
    chargeFinish: _chargeFinish,
    exit: _exit,
  );

  late final Future<void> _ready;
  bool _started = false;
  bool _reduceMotion = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Trigger Data Fetch
    context.read<HomeBloc>().add(LoadHomeData());

    _ready = _waitUntilReady();
    _exit.addListener(_navigateWhenBeeIsAway);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion = MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    _run(precacheImage(const AssetImage(_logoAsset), context));
  }

  /// MainWrapper (and everything under it — see its Orders tab guard) trusts
  /// AuthBloc's state synchronously, with no "still loading" case of its
  /// own. That's only safe if AuthBloc has already left its transient
  /// AuthInitial state by the time MainWrapper exists — so this is the one
  /// place that guarantee gets enforced, instead of every future screen
  /// that reads auth state needing to re-derive it.
  Future<void> _waitUntilReady() async {
    await Future.wait([
      context
          .read<HomeBloc>()
          .firstWhereReady((s) => s is HomeLoaded || s is HomeError),
      context.read<AuthBloc>().firstWhereReady((s) => s is! AuthInitial),
    ]);
  }

  /// Plays the phases in order. Navigation only ever happens after
  /// [_ready] resolves, whichever path runs.
  Future<void> _run(Future<void> logoPrecached) async {
    try {
      // Don't start the entrance on a frame where the logo isn't decoded yet.
      await logoPrecached;
      // Android 12+ cross-fades its (white) system splash over our first
      // ~300ms of frames; hold the fly-in until that has cleared so it
      // isn't played underneath it.
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      // Even an instant load gets the entrance plus one hover beat.
      final minShown = Future<void>.delayed(const Duration(milliseconds: 1200));

      if (_reduceMotion) {
        await _fade.forward().orCancel;
        await Future.wait([_ready, minShown]);
        if (!mounted) return;
        await _fade.reverse().orCancel;
        _goHome();
        return;
      }

      _chargeLoad.forward();
      await _entrance.forward().orCancel;
      _hover.repeat();
      _settle.forward();

      await Future.wait([_ready, minShown]);
      if (!mounted) return;
      _motion.beginFinish();
      _chargeLoad.stop();
      await _chargeFinish.forward().orCancel;
      // Launch the moment the glow hits full charge.
      _exit.forward();
    } on TickerCanceled {
      // Disposed mid-animation; nothing left to do.
    }
  }

  /// Starts the route fade while the bee is still streaking out, so the
  /// launch and the hand-off read as one motion.
  void _navigateWhenBeeIsAway() {
    if (_exit.value >= 0.85) _goHome();
  }

  void _goHome() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const MainWrapper(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved =
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _entrance.dispose();
    _hover.dispose();
    _settle.dispose();
    _chargeLoad.dispose();
    _chargeFinish.dispose();
    _exit.dispose();
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    // Brand-green background — white status bar icons here, overriding
    // the app-wide dark-icon default set in MaterialApp.builder.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: colorScheme.primary,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final layout = _Layout(constraints.biggest);
            return _reduceMotion
                ? _buildStatic(layout)
                : _buildAnimated(layout);
          },
        ),
      ),
    );
  }

  Widget _buildAnimated(_Layout layout) {
    final logo = Image.asset(
      _logoAsset,
      width: layout.logoW,
      height: layout.logoH,
      filterQuality: FilterQuality.medium,
    );

    return Stack(
      children: [
        Positioned.fill(
          child: CustomPaint(painter: _EnergyPainter(_motion, layout)),
        ),
        Positioned.fromRect(
          rect: layout.logoRect,
          child: AnimatedBuilder(
            animation: _motion.listenable,
            child: logo,
            builder: (context, child) {
              final pose = _motion.pose(layout);
              Widget bee = child!;
              if (pose.blur > 0.05) {
                bee = ImageFiltered(
                  imageFilter:
                      ui.ImageFilter.blur(sigmaX: pose.blur, sigmaY: pose.blur),
                  child: bee,
                );
              }
              return Transform.translate(
                offset: pose.offset,
                child: Transform.rotate(
                  angle: pose.rotation,
                  child: Transform.scale(
                    scaleX: pose.scaleX,
                    scaleY: pose.scaleY,
                    child: Opacity(opacity: pose.opacity, child: bee),
                  ),
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: layout.wordmarkTop,
          child: AnimatedBuilder(
            animation: Listenable.merge([_settle, _hover, _exit]),
            builder: (context, _) => _AnimatedWordmark(
              reveal: _settle.value,
              fadeOut: _motion.uiFadeOut,
              shine: const Interval(0.1, 0.6, curve: Curves.easeInOut)
                  .transform(_hover.value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatic(_Layout layout) {
    return FadeTransition(
      opacity: _fade,
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: layout.logoRect,
            child: Image.asset(_logoAsset, filterQuality: FilterQuality.medium),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: layout.wordmarkTop,
            child: const _AnimatedWordmark(reveal: 1, fadeOut: 0),
          ),
        ],
      ),
    );
  }
}

/// Screen-relative geometry shared by the widgets and the painter.
class _Layout {
  _Layout(this.screen) : logoW = math.min(screen.width * 0.48, 300.0);

  final Size screen;
  final double logoW;

  double get logoH => logoW / _logoAspect;
  Offset get center => Offset(screen.width / 2, screen.height * 0.42);
  Rect get logoRect =>
      Rect.fromCenter(center: center, width: logoW, height: logoH);
  double get wordmarkTop => center.dy + logoH / 2 + 28;

  @override
  bool operator ==(Object other) => other is _Layout && other.screen == screen;

  @override
  int get hashCode => screen.hashCode;
}

/// Where the bee is and how it's drawn on a given frame, relative to
/// [_Layout.center].
class _Pose {
  const _Pose({
    required this.offset,
    required this.scaleX,
    required this.scaleY,
    required this.rotation,
    required this.opacity,
    required this.blur,
    required this.trailDir,
    required this.trail,
    required this.trailLength,
  });

  final Offset offset;
  final double scaleX;
  final double scaleY;
  final double rotation;
  final double opacity;
  final double blur;

  /// Unit vector of travel; speed streaks are drawn opposite to it.
  final Offset trailDir;

  /// 0..1 streak opacity.
  final double trail;
  final double trailLength;
}

/// All the per-frame maths, derived from the controllers so the bee widget
/// and the painter always agree on where the bee is.
class _SplashMotion {
  _SplashMotion({
    required this.entrance,
    required this.hover,
    required this.settle,
    required this.chargeLoad,
    required this.chargeFinish,
    required this.exit,
  }) : listenable = Listenable.merge(
            [entrance, hover, settle, chargeLoad, chargeFinish, exit]);

  final Animation<double> entrance;
  final Animation<double> hover;
  final Animation<double> settle;
  final Animation<double> chargeLoad;
  final Animation<double> chargeFinish;
  final Animation<double> exit;
  final Listenable listenable;

  bool _finishing = false;
  double _chargeFrom = 0;

  /// Time-based ease that keeps slowing as it approaches ~88%, so a slow
  /// network reads as "almost there" rather than stuck.
  double get _loadingCharge {
    final seconds = chargeLoad.value * _chargeLoadSeconds;
    return 0.88 * (1 - math.exp(-seconds / 1.8));
  }

  double get charge => _finishing
      ? _chargeFrom +
          (1 - _chargeFrom) * Curves.easeOutCubic.transform(chargeFinish.value)
      : _loadingCharge;

  void beginFinish() {
    _chargeFrom = _loadingCharge;
    _finishing = true;
  }

  /// Wordmark and bar clear out quickly at the start of the launch.
  double get uiFadeOut => const Interval(0, 0.35).transform(exit.value);

  _Pose pose(_Layout l) {
    final w = l.screen.width;

    // Entrance: a quadratic Bézier from off-screen bottom-left that ends at
    // the origin. easeOutBack pushes t past 1, giving the overshoot.
    final e = entrance.value;
    final t = Curves.easeOutBack.transform(e);
    final start = Offset(-w / 2 - l.logoW, l.logoH * 1.4);
    final control = Offset(-w * 0.3, -l.logoH * 0.25);
    final u = 1 - t;
    var offset = start * (u * u) + control * (2 * u * t);
    final tangent = (control - start) * (2 * u) - control * (2 * t);
    var scale = 0.6 + 0.4 * t;
    var scaleX = 1.0;
    var scaleY = 1.0;
    var rotation = -0.16 * (1 - Curves.easeOut.transform(e));
    final opacity = const Interval(0, 0.35).transform(e);
    final blur =
        6 * (1 - const Interval(0, 0.6, curve: Curves.easeOut).transform(e));
    var trailDir = _unit(tangent);
    var trail = 1 - Curves.easeOutCubic.transform(e);
    var trailLength = l.logoW * 0.55 * trail;

    // Hover: bob (900ms), drift and tilt (1800ms), wing buzz (60ms).
    final h = hover.value * 2 * math.pi;
    offset += Offset(
      5 * math.sin(h),
      -9 * math.sin(2 * h) + 1.2 * math.sin(30 * h),
    );
    rotation += 0.06 * math.sin(h); // ~±3.4°

    // Exit: dip and squash, spring back, then launch top-right.
    final x = exit.value;
    if (x > 0) {
      final dip = const Interval(0, 0.23, curve: Curves.easeOut).transform(x);
      final release =
          const Interval(0.23, 0.45, curve: Curves.easeOut).transform(x);
      final squash = dip * (1 - release);
      final shoot =
          const Interval(0.23, 1, curve: Curves.easeInExpo).transform(x);
      final reach = w / 2 + l.logoW * 1.1;
      final launch = Offset(reach, -reach * 0.42);

      offset += const Offset(-3, 6) * squash + launch * shoot;
      scaleX *= 1 + 0.08 * squash;
      scaleY *= 1 - 0.08 * squash;
      scale *= 1 + 0.25 * shoot;
      rotation -=
          0.24 * const Interval(0.23, 0.6, curve: Curves.easeOut).transform(x);
      trailDir = _unit(launch);
      trail = const Interval(0.3, 1, curve: Curves.easeIn).transform(x);
      trailLength = (launch * shoot).distance + l.logoW * 0.6 * trail;
    }

    return _Pose(
      offset: offset,
      scaleX: scale * scaleX,
      scaleY: scale * scaleY,
      rotation: rotation,
      opacity: opacity,
      blur: blur,
      trailDir: trailDir,
      trail: trail * opacity,
      trailLength: trailLength,
    );
  }

  static Offset _unit(Offset v) =>
      v.distance == 0 ? const Offset(1, 0) : v / v.distance;
}

/// Glow, charge ripples and speed streaks, all drawn behind the bee.
class _EnergyPainter extends CustomPainter {
  _EnergyPainter(this.motion, this.layout) : super(repaint: motion.listenable);

  final _SplashMotion motion;
  final _Layout layout;

  @override
  void paint(Canvas canvas, Size size) {
    final center = layout.center;
    final logoW = layout.logoW;
    final x = motion.exit.value;
    final h = motion.hover.value * 2 * math.pi;

    final landed = const Interval(0.5, 1).transform(motion.entrance.value);
    final pulse = 0.5 + 0.5 * math.sin(h);
    final flash = math.sin(math.pi * const Interval(0.15, 0.85).transform(x));
    final idleOut = 1 - const Interval(0.4, 1).transform(x);

    // Glow: brighter as the charge builds, flashes on launch.
    final glow =
        (landed * (0.28 + 0.35 * motion.charge + 0.17 * pulse) * idleOut +
                0.85 * flash)
            .clamp(0.0, 1.0);
    if (glow > 0) {
      final radius = logoW * (0.72 + 0.05 * pulse + 0.5 * flash);
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              Colors.white.withValues(alpha: 0.55 * glow),
              _bagYellow.withValues(alpha: 0.35 * glow),
              _bagYellow.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(rect),
      );
    }

    // Two ripples, half a hover cycle apart, so one leaves with every bob.
    final ringsIn = const Interval(0, 0.4).transform(motion.settle.value) *
        (1 - const Interval(0, 0.4).transform(x));
    if (ringsIn > 0) {
      for (final phase in const [0.0, 0.5]) {
        final p = (motion.hover.value + phase) % 1.0;
        final birth = math.min(1.0, p / 0.12);
        final alpha = 0.45 * ringsIn * birth * (1 - p) * (1 - p);
        if (alpha <= 0) continue;
        canvas.drawCircle(
          center,
          logoW * (0.3 + 0.6 * Curves.easeOut.transform(p)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.75 + 2 * (1 - p)
            ..color = Colors.white.withValues(alpha: alpha),
        );
      }
    }

    // Speed streaks trailing the bee, matching the lines in the logo art.
    final pose = motion.pose(layout);
    if (pose.trail > 0.01 && pose.trailLength > 1) {
      final dir = pose.trailDir;
      final normal = Offset(-dir.dy, dir.dx);
      final beeScale = pose.scaleX;
      final tail = center + pose.offset - dir * (logoW * 0.3 * beeScale);
      const lanes = [(-0.12, 0.7), (0.06, 1.0), (0.22, 0.55)];
      for (final (lane, length) in lanes) {
        final from = tail + normal * (layout.logoH * lane * beeScale);
        final to = from - dir * (pose.trailLength * length);
        canvas.drawLine(
          from,
          to,
          Paint()
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..shader = ui.Gradient.linear(from, to, [
              Colors.white.withValues(alpha: 0.75 * pose.trail),
              Colors.white.withValues(alpha: 0),
            ]),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EnergyPainter old) =>
      old.motion != motion || old.layout != layout;
}

/// "Beeyo", revealed letter by letter as [reveal] runs 0→1, then swept by
/// a light band travelling top to bottom as [shine] runs 0→1.
class _AnimatedWordmark extends StatelessWidget {
  const _AnimatedWordmark({
    required this.reveal,
    required this.fadeOut,
    this.shine = 0,
  });

  final double reveal;
  final double fadeOut;
  final double shine;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Colors.white,
      fontSize: 42,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
    );
    Widget word = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < _wordmark.length; i++)
          Builder(builder: (context) {
            // First ~300ms of [reveal] is the post-landing pause.
            final start = 0.33 + i * 0.08;
            final v = Interval(start, math.min(1.0, start + 0.35),
                    curve: Curves.easeOutCubic)
                .transform(reveal);
            return Opacity(
              opacity: v,
              child: Transform.translate(
                offset: Offset(0, 14 * (1 - v)),
                child: Text(_wordmark[i], style: style),
              ),
            );
          }),
      ],
    );

    // Only once every letter is in, so the band never pops in mid-reveal.
    final strength = const Interval(0.85, 1).transform(reveal);
    if (strength > 0) {
      final edge = Color.lerp(Colors.white, _shineGold, strength)!;
      word = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          // A narrow gold streak with a warm-white core. It starts fully
          // above the text and ends fully below it, so the loop restarts
          // with nothing on screen.
          final h = bounds.height;
          final y = h * (-0.4 + 1.8 * shine);
          return ui.Gradient.linear(
            Offset(0, y - h * 0.3),
            Offset(0, y + h * 0.3),
            [Colors.white, edge, const Color(0xFFFFF8E1), edge, Colors.white],
            const [0, 0.3, 0.5, 0.7, 1],
          );
        },
        child: word,
      );
    }

    return Opacity(opacity: 1 - fadeOut, child: word);
  }
}
