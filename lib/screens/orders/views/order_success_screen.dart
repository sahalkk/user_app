import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/ads_cubit/ads_cubit.dart';
import '../../../shared/models/ad_model.dart';
import '../../../shared/models/order_model.dart';
import '../../../shared/utils/order_items_resolver.dart';
import '../../../shared/widgets/sponsored_ad_card.dart';
import '../../../theme/app_colors.dart';
import '../../main_wrapper.dart';

/// Shown right after checkout: a success check, the order id, an optional
/// sponsored card, and a countdown that moves on to the Orders tab.
///
/// The countdown runs for the ad's `displaySeconds` (6 s by default), or 3 s
/// when there's no ad to show. Opening the ad pauses it until the user is
/// back in the app; "View my order" and system back skip it.
class OrderSuccessScreen extends StatefulWidget {
  final OrderModel order;

  const OrderSuccessScreen({super.key, required this.order});

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  static const _defaultAdSeconds = 6;
  static const _noAdSeconds = 3;

  /// Longest we'll hold the screen waiting for the ad request. It's normally
  /// prefetched when the cart opens, so this only matters on a slow network.
  static const _adWaitLimit = Duration(milliseconds: 1500);

  late final AnimationController _check = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final AnimationController _countdown = AnimationController(vsync: this)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) _goToOrders();
    });

  Timer? _adWaitTimer;
  bool _started = false;
  bool _gaveUpWaiting = false;
  bool _pausedForAd = false;
  bool _leftApp = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final ads = context.read<AdsCubit>();
    ads.load(AdPlacement.orderSuccess);
    _adWaitTimer = Timer(_adWaitLimit, () {
      if (!mounted || _started) return;
      setState(() => _gaveUpWaiting = true);
      _syncCountdown(ads.state);
    });
    _syncCountdown(ads.state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _adWaitTimer?.cancel();
    _check.dispose();
    _countdown.dispose();
    super.dispose();
  }

  /// The ad to show, if any. Once we've stopped waiting for it, a late
  /// response is ignored rather than popping in and stretching the timer.
  AdModel? _adFrom(AdsState state) {
    if (_gaveUpWaiting) return null;
    final ads = state.visibleAds(AdPlacement.orderSuccess);
    return ads.isEmpty ? null : ads.first;
  }

  /// Starts the countdown once we know whether there's an ad, and shortens
  /// it to the no-ad length if the ad drops out later (broken image).
  void _syncCountdown(AdsState state) {
    final resolved = state.slot(AdPlacement.orderSuccess).isResolved;
    if (!_started && !resolved && !_gaveUpWaiting) return;

    final ad = _adFrom(state);
    final seconds = ad == null
        ? _noAdSeconds
        : (ad.displaySeconds ?? _defaultAdSeconds).clamp(3, 15);
    final total = Duration(seconds: seconds);

    if (!_started) {
      _started = true;
      _adWaitTimer?.cancel();
      _countdown.duration = total;
      _countdown.forward();
      return;
    }

    // Already running: keep the time already elapsed, change the total.
    final current = _countdown.duration!;
    if (current == total) return;
    final elapsed = current * _countdown.value;
    if (elapsed >= total) {
      _goToOrders();
      return;
    }
    final wasRunning = _countdown.isAnimating;
    _countdown.duration = total;
    _countdown.value = elapsed.inMilliseconds / total.inMilliseconds;
    if (wasRunning) _countdown.forward();
  }

  void _pauseForAd() {
    _pausedForAd = true;
    _leftApp = false;
    _countdown.stop();
    setState(() {});
  }

  void _onAdOpened(bool opened) {
    // Nothing opened (SnackBar already shown) — carry on counting.
    if (!opened && mounted) _resume();
  }

  void _resume() {
    if (!_pausedForAd) return;
    _pausedForAd = false;
    _leftApp = false;
    if (_started && !_leaving) _countdown.forward();
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_pausedForAd) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftApp = true;
    } else if (state == AppLifecycleState.resumed && _leftApp) {
      _resume();
    }
  }

  void _goToOrders() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _countdown.stop();
    // Same fresh stack on the Orders tab that checkout used before — back
    // from there shouldn't land on the now-empty cart.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (context) => const MainWrapper(initialIndex: 3)),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goToOrders();
      },
      child: BlocListener<AdsCubit, AdsState>(
        listener: (context, state) => _syncCountdown(state),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                    child: Column(
                      children: [
                        _SuccessCheck(animation: _check),
                        const SizedBox(height: 22),
                        _FadeUp(
                          animation: _check,
                          child: Column(
                            children: [
                              const Text(
                                'Order Placed!',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Your order has been received successfully',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2F4F3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  'Order #${shortOrderId(widget.order)}',
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        BlocBuilder<AdsCubit, AdsState>(
                          builder: (context, state) {
                            final slot = state.slot(AdPlacement.orderSuccess);
                            if (!slot.isResolved && !_gaveUpWaiting) {
                              return const SponsoredAdSkeleton(
                                  placement: AdPlacement.orderSuccess);
                            }
                            final ad = _adFrom(state);
                            if (ad == null) return const SizedBox.shrink();
                            return _FadeUp(
                              animation: _check,
                              child: SponsoredAdCard(
                                ad: ad,
                                onWillOpen: _pauseForAd,
                                onOpened: _onAdOpened,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                _CountdownFooter(
                  countdown: _countdown,
                  started: () => _started,
                  paused: _pausedForAd,
                  onSkip: _goToOrders,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownFooter extends StatelessWidget {
  final AnimationController countdown;
  final bool Function() started;
  final bool paused;
  final VoidCallback onSkip;

  const _CountdownFooter({
    required this.countdown,
    required this.started,
    required this.paused,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: countdown,
            builder: (context, _) {
              final total = countdown.duration;
              final remaining = total == null
                  ? null
                  : (total.inMilliseconds * (1 - countdown.value) / 1000)
                      .ceil();
              final label = !started() || remaining == null
                  ? ' '
                  : paused
                      ? 'Paused — we’ll continue when you’re back'
                      : 'Taking you to your order in ${remaining}s';
              return Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: started() ? countdown.value : 0,
                      minHeight: 3,
                      backgroundColor: const Color(0xFFEDEFEE),
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primaryGreen),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onSkip,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text(
                'View my order',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Green disc that pops in, then a check mark drawn stroke by stroke.
class _SuccessCheck extends StatelessWidget {
  final Animation<double> animation;
  const _SuccessCheck({required this.animation});

  @override
  Widget build(BuildContext context) {
    final pop = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.55, curve: Curves.easeOutBack));
    final draw = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.4, 1, curve: Curves.easeOutCubic));
    return SizedBox.square(
      dimension: 112,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            // Soft halo
            Transform.scale(
              scale: 0.6 + 0.4 * pop.value,
              child: Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE8F5E9),
                ),
              ),
            ),
            Transform.scale(
              scale: pop.value,
              child: Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryGreen,
                ),
                child: CustomPaint(painter: _CheckPainter(draw.value)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  _CheckPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final path = Path()
      ..moveTo(size.width * 0.28, size.height * 0.52)
      ..lineTo(size.width * 0.44, size.height * 0.67)
      ..lineTo(size.width * 0.73, size.height * 0.37);
    final metric = path.computeMetrics().first;
    final partial =
        metric.extractPath(0, metric.length * math.min(progress, 1));
    canvas.drawPath(
      partial,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.progress != progress;
}

/// Fades and lifts [child] in during the back half of [animation].
class _FadeUp extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;
  const _FadeUp({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(
        parent: animation,
        curve: const Interval(0.35, 1, curve: Curves.easeOutCubic));
    return AnimatedBuilder(
      animation: curve,
      builder: (context, child) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - curve.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
