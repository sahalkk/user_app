import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../../../blocs/ads_cubit/ads_cubit.dart';
import '../../../../shared/models/ad_model.dart';
import '../../../../shared/widgets/sponsored_ad_card.dart';

/// HOME_BANNER slot: a skeleton while loading, a 2:1 sponsored card (or an
/// auto-rotating carousel of them) once loaded, and nothing at all — not
/// even padding — when there are no ads.
class HomeAdBanner extends StatefulWidget {
  const HomeAdBanner({super.key});

  @override
  State<HomeAdBanner> createState() => _HomeAdBannerState();
}

class _HomeAdBannerState extends State<HomeAdBanner> {
  static const _padding = EdgeInsets.fromLTRB(16, 8, 16, 10);

  @override
  void initState() {
    super.initState();
    context.read<AdsCubit>().load(AdPlacement.homeBanner);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdsCubit, AdsState>(
      buildWhen: (a, b) =>
          a.slot(AdPlacement.homeBanner) != b.slot(AdPlacement.homeBanner) ||
          a.hiddenIds != b.hiddenIds ||
          a.settings != b.settings,
      builder: (context, state) {
        final slot = state.slot(AdPlacement.homeBanner);
        if (!slot.isResolved) {
          return const Padding(
            padding: _padding,
            child: SponsoredAdSkeleton(placement: AdPlacement.homeBanner),
          );
        }
        final ads = state.visibleAds(AdPlacement.homeBanner);
        if (ads.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: _padding,
          child: ads.length == 1
              ? SponsoredAdCard(ad: ads.first)
              : _AdCarousel(
                  ads: ads,
                  interval:
                      Duration(seconds: state.settings.homeAutoRotateSecs),
                ),
        );
      },
    );
  }
}

class _AdCarousel extends StatefulWidget {
  final List<AdModel> ads;
  final Duration interval;

  const _AdCarousel({required this.ads, required this.interval});

  @override
  State<_AdCarousel> createState() => _AdCarouselState();
}

class _AdCarouselState extends State<_AdCarousel> {
  final _controller = PageController();
  Timer? _timer;
  int _page = 0;
  bool _dragging = false;
  bool _onScreen = false;

  @override
  void didUpdateWidget(covariant _AdCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An ad dropped out (e.g. broken image) — keep the index in range.
    if (_page >= widget.ads.length) {
      _page = 0;
      if (_controller.hasClients) _controller.jumpToPage(0);
    }
    if (oldWidget.interval != widget.interval) _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Rotates only while the carousel is on screen and not being dragged.
  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (!_onScreen || _dragging) return;
    _timer = Timer.periodic(widget.interval, (_) {
      if (!_controller.hasClients) return;
      final next = (_page + 1) % widget.ads.length;
      _controller.animateToPage(next,
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeInOutCubic);
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _dragging = true;
      _restartTimer();
    } else if (n is ScrollEndNotification && _dragging) {
      _dragging = false;
      _restartTimer();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: const Key('home-ad-carousel'),
      onVisibilityChanged: (info) {
        final visible = info.visibleFraction >= 0.5;
        if (visible == _onScreen || !mounted) return;
        _onScreen = visible;
        _restartTimer();
      },
      child: AspectRatio(
        aspectRatio: kHomeAdAspectRatio,
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.ads.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => SponsoredAdCard(
                  key: ValueKey(widget.ads[i].id),
                  ad: widget.ads[i],
                ),
              ),
            ),
            // Dots sit inside the card (bottom-right, over the scrim) so
            // the slot is the same height as the single-ad case and its
            // skeleton.
            Positioned(
              right: 14,
              bottom: 14,
              child: IgnorePointer(
                child: Row(
                  children: [
                    for (var i = 0; i < widget.ads.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(left: 4),
                        width: i == _page ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
