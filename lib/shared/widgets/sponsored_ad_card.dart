import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../blocs/ads_cubit/ads_cubit.dart';
import '../../theme/app_colors.dart';
import '../models/ad_model.dart';
import 'skeleton.dart';

// ─────────────────────────────────────────────
//  Sponsored ad card — one widget, a variant per placement
// ─────────────────────────────────────────────
//
// Every variant carries a "Sponsored" label, counts an impression once it's
// ≥50% on screen, and opens the advertiser's site from the CTA or anywhere
// on the card. If the image can't load, the ad hides itself (AdsCubit.hide)
// and its slot collapses.
//
// Each variant has a matching [SponsoredAdSkeleton] of the exact same size,
// so swapping skeleton → ad never moves the layout.

/// Home banner creative ratio (1200×600).
const double kHomeAdAspectRatio = 2 / 1;

/// Order success creative ratio (1200×800).
const double kOrderSuccessAdAspectRatio = 3 / 2;

// Cart row geometry — mirrors _CartItemCard in cart_screen.dart so an ad row
// is exactly the size and shape of a product row. Change both together.
// _CartItemCard is a Container with a 1px border, and Container adds the
// border width to its padding — so the content inset there is 12 + 1.
const double _kCartPadding = 12 + 1;
const double _kCartRadius = 16;
const double _kCartThumb = 70;
const double _kCartThumbRadius = 12;
const double _kCartThumbGap = 16;
const double _kCartPillHeight = 31; // quantity selector: 15px icon + 8px × 2
const TextStyle _kCartTitleStyle = TextStyle(
    fontFamily: 'Poppins',
    fontWeight: FontWeight.w700,
    fontSize: 15,
    color: Colors.black87);
const TextStyle _kCartLabelStyle = TextStyle(
    fontFamily: 'Poppins', color: AppColors.textSecondary, fontSize: 11);

// Order success card: fixed-height text strip under the 3:2 image.
const double _kSuccessStripHeight = 76;
const double _kSuccessRadius = 20;

/// Opens [ad] (records the click) and shows a SnackBar if nothing could
/// handle the link. Returns whether the browser opened.
Future<bool> openSponsoredAd(BuildContext context, AdModel ad) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final opened = await context.read<AdsCubit>().open(ad);
  if (!opened) {
    messenger?.showSnackBar(const SnackBar(
        content: Text("Couldn't open the link. Please try again.")));
  }
  return opened;
}

class SponsoredAdCard extends StatefulWidget {
  final AdModel ad;

  /// Runs before the link opens — e.g. the order success screen pauses its
  /// countdown. Gets whether the browser actually opened afterwards.
  final ValueChanged<bool>? onOpened;
  final VoidCallback? onWillOpen;

  /// Distinguishes copies of the same ad on one screen (the cart repeats
  /// ads when there are fewer ads than slots) for visibility tracking.
  final String slotId;

  const SponsoredAdCard({
    super.key,
    required this.ad,
    this.onWillOpen,
    this.onOpened,
    this.slotId = '',
  });

  @override
  State<SponsoredAdCard> createState() => _SponsoredAdCardState();
}

class _SponsoredAdCardState extends State<SponsoredAdCard> {
  // An impression needs both: the card ≥50% on screen *and* its creative
  // actually rendered — a placeholder for an image that then 404s isn't one.
  bool _onScreen = false;
  bool _imageLoaded = false;

  AdModel get ad => widget.ad;

  void _maybeRecordImpression() {
    if (_onScreen && _imageLoaded && mounted) {
      context.read<AdsCubit>().recordImpression(ad);
    }
  }

  void _onImageLoaded() {
    if (_imageLoaded) return;
    _imageLoaded = true;
    _maybeRecordImpression();
  }

  Future<void> _open(BuildContext context) async {
    widget.onWillOpen?.call();
    final opened = await openSponsoredAd(context, ad);
    widget.onOpened?.call(opened);
  }

  @override
  Widget build(BuildContext context) {
    final card = switch (ad.placement) {
      AdPlacement.homeBanner =>
        _HomeBannerAd(ad: ad, onTap: () => _open(context)),
      AdPlacement.cartInline =>
        _CartInlineAd(ad: ad, onTap: () => _open(context)),
      AdPlacement.orderSuccess =>
        _OrderSuccessAd(ad: ad, onTap: () => _open(context)),
    };

    return VisibilityDetector(
      key: Key('ad-visibility-${ad.placement.wire}-${ad.id}-${widget.slotId}'),
      onVisibilityChanged: (info) {
        _onScreen = info.visibleFraction >= 0.5;
        _maybeRecordImpression();
      },
      child: Semantics(
        button: true,
        label: 'Sponsored: ${ad.title}. ${ad.ctaText}',
        child: card,
      ),
    );
  }
}

// ── Shared pieces ─────────────────────────────

Color _onColor(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : AppColors.textPrimary;

class _AdImage extends StatelessWidget {
  final AdModel ad;
  const _AdImage({required this.ad});

  @override
  Widget build(BuildContext context) {
    return CachedNetworkImage(
      imageUrl: ad.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: skeletonImagePlaceholder,
      imageBuilder: (context, provider) {
        final card = context.findAncestorStateOfType<_SponsoredAdCardState>();
        WidgetsBinding.instance
            .addPostFrameCallback((_) => card?._onImageLoaded());
        return Image(
          image: provider,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
      errorWidget: (context, url, error) {
        // Can't emit mid-build — hide on the next frame; the slot collapses.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) context.read<AdsCubit>().hide(ad);
        });
        return const ColoredBox(color: kSkeletonBase);
      },
    );
  }
}

/// Small "Sponsored" chip, for placing over imagery.
class _SponsoredChip extends StatelessWidget {
  const _SponsoredChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Sponsored',
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _CtaPill extends StatelessWidget {
  final AdModel ad;
  final double height;
  final double fontSize;
  final double horizontalPadding;
  final VoidCallback onTap;

  const _CtaPill({
    required this.ad,
    required this.height,
    required this.onTap,
    this.fontSize = 12,
    this.horizontalPadding = 14,
  });

  @override
  Widget build(BuildContext context) {
    final color = ad.ctaColor ?? AppColors.primaryGreen;
    return SizedBox(
      height: height,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(height / 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(height / 2),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Center(
              widthFactor: 1,
              child: Text(
                ad.ctaText,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: _onColor(color),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── HOME_BANNER ───────────────────────────────

class _HomeBannerAd extends StatelessWidget {
  final AdModel ad;
  final VoidCallback onTap;
  const _HomeBannerAd({required this.ad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = ad.subtitle;
    return AspectRatio(
      aspectRatio: kHomeAdAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Material(
          color: ad.backgroundColor ?? kSkeletonBase,
          child: InkWell(
            onTap: onTap,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _AdImage(ad: ad),
                // Bottom scrim so white copy reads on any creative.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.35, 1],
                      colors: [Color(0x00000000), Color(0xB3000000)],
                    ),
                  ),
                ),
                const Positioned(top: 10, right: 10, child: _SponsoredChip()),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ad.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: Colors.white,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      const SizedBox(height: 8),
                      _CtaPill(ad: ad, height: 30, onTap: onTap),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── CART_INLINE ───────────────────────────────

class _CartInlineAd extends StatelessWidget {
  final AdModel ad;
  final VoidCallback onTap;
  const _CartInlineAd({required this.ad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitle = ad.subtitle ?? ad.advertiserName;
    return _CartRowFrame(
      color: ad.backgroundColor ?? Colors.white,
      onTap: onTap,
      thumbnail: ClipRRect(
        borderRadius: BorderRadius.circular(_kCartThumbRadius),
        child: _AdImage(ad: ad),
      ),
      title: Text(ad.title,
          style: _kCartTitleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      label: Text(
        ad.advertiserName.isEmpty
            ? 'Sponsored'
            : 'Sponsored · ${ad.advertiserName}',
        style: _kCartLabelStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      bottomLeft: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      bottomRight: _CtaPill(ad: ad, height: _kCartPillHeight, onTap: onTap),
    );
  }
}

/// The cart row's box: same padding, radius, border, thumbnail slot and
/// line structure as a product row. Used by both the ad and its skeleton.
class _CartRowFrame extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;
  final Widget thumbnail;
  final Widget title;
  final Widget label;
  final Widget bottomLeft;
  final Widget bottomRight;

  const _CartRowFrame({
    required this.color,
    required this.thumbnail,
    required this.title,
    required this.label,
    required this.bottomLeft,
    required this.bottomRight,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kCartRadius),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(_kCartPadding),
          child: Row(
            children: [
              SizedBox.square(dimension: _kCartThumb, child: thumbnail),
              const SizedBox(width: _kCartThumbGap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    title,
                    const SizedBox(height: 4),
                    label,
                    const SizedBox(height: 12),
                    SizedBox(
                      height: _kCartPillHeight,
                      child: Row(
                        children: [
                          Expanded(child: bottomLeft),
                          const SizedBox(width: 10),
                          bottomRight,
                        ],
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
  }
}

// ── ORDER_SUCCESS ─────────────────────────────

class _OrderSuccessAd extends StatelessWidget {
  final AdModel ad;
  final VoidCallback onTap;
  const _OrderSuccessAd({required this.ad, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final background = ad.backgroundColor ?? const Color(0xFFF4F7F5);
    final onBackground = _onColor(background);
    final subtitle = ad.subtitle;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(_kSuccessRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: kOrderSuccessAdAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _AdImage(ad: ad),
                  const Positioned(top: 10, right: 10, child: _SponsoredChip()),
                ],
              ),
            ),
            SizedBox(
              height: _kSuccessStripHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ad.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: onBackground,
                            ),
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: onBackground.withValues(alpha: 0.7),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _CtaPill(
                      ad: ad,
                      height: 36,
                      fontSize: 12.5,
                      horizontalPadding: 18,
                      onTap: onTap,
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

// ── Skeletons ─────────────────────────────────

/// Loading placeholder with the exact footprint of [placement]'s ad.
class SponsoredAdSkeleton extends StatelessWidget {
  final AdPlacement placement;
  const SponsoredAdSkeleton({super.key, required this.placement});

  @override
  Widget build(BuildContext context) {
    switch (placement) {
      case AdPlacement.homeBanner:
        return const AspectRatio(
          aspectRatio: kHomeAdAspectRatio,
          child:
              SkeletonBox(borderRadius: BorderRadius.all(Radius.circular(16))),
        );
      case AdPlacement.cartInline:
        return _CartRowFrame(
          color: Colors.white,
          thumbnail: const SkeletonBox(
              borderRadius:
                  BorderRadius.all(Radius.circular(_kCartThumbRadius))),
          title: const _SkeletonLine(style: _kCartTitleStyle, widthFactor: 0.7),
          label: const _SkeletonLine(style: _kCartLabelStyle, widthFactor: 0.4),
          bottomLeft: const Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
                widthFactor: 0.6, child: SkeletonBox(height: 12)),
          ),
          bottomRight: const SkeletonBox(
              width: 76,
              height: _kCartPillHeight,
              borderRadius: BorderRadius.all(Radius.circular(16))),
        );
      case AdPlacement.orderSuccess:
        return ClipRRect(
          borderRadius: BorderRadius.circular(_kSuccessRadius),
          child: const ColoredBox(
            color: Color(0xFFF7F8F9),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: kOrderSuccessAdAspectRatio,
                  child: SkeletonBox(borderRadius: BorderRadius.zero),
                ),
                SizedBox(
                  height: _kSuccessStripHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 150, height: 13),
                              SizedBox(height: 8),
                              SkeletonBox(width: 100, height: 10),
                            ],
                          ),
                        ),
                        SkeletonBox(
                            width: 96,
                            height: 36,
                            borderRadius:
                                BorderRadius.all(Radius.circular(18))),
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
}

/// A skeleton bar occupying exactly one line of [style] — the line box comes
/// from a real (blank) Text, so the height matches the text it stands in for.
class _SkeletonLine extends StatelessWidget {
  final TextStyle style;
  final double widthFactor;
  const _SkeletonLine({required this.style, required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Text(' ', style: style, maxLines: 1),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: widthFactor,
              child: const SkeletonBox(),
            ),
          ),
        ),
      ],
    );
  }
}
