import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/ad_repository.dart';
import '../../shared/models/ad_model.dart';
import 'ads_state.dart';

export 'ads_state.dart';

/// Sponsored ads for every placement, cached per placement for the session.
class AdsCubit extends Cubit<AdsState> {
  final AdRepository _repository;

  /// Ads already counted this session — an impression is recorded once per
  /// ad per app run, however often it scrolls back into view.
  final Set<String> _impressed = {};

  /// In-flight fetches, so concurrent callers all await the same request.
  final Map<AdPlacement, Future<void>> _pending = {};

  AdsCubit(this._repository) : super(const AdsState());

  /// Fetches [placement] unless it's already loaded or loading. [force]
  /// refetches (pull-to-refresh) while keeping current ads on screen, so the
  /// slot doesn't flash back to a skeleton.
  Future<void> load(AdPlacement placement, {bool force = false}) {
    final pending = _pending[placement];
    if (pending != null) return pending;
    if (!force && state.slot(placement).status == AdSlotStatus.loaded) {
      return Future.value();
    }
    return _pending[placement] =
        _fetch(placement).whenComplete(() => _pending.remove(placement));
  }

  Future<void> _fetch(AdPlacement placement) async {
    final current = state.slot(placement);

    if (current.status != AdSlotStatus.loaded) {
      emit(state.withSlot(
          placement, AdSlot(status: AdSlotStatus.loading, ads: current.ads)));
    }

    try {
      final result = await _repository.fetchAds(placement);
      if (isClosed) return;
      emit(state
          .withSlot(
              placement, AdSlot(status: AdSlotStatus.loaded, ads: result.ads))
          .copyWith(settings: result.settings));
    } catch (e) {
      debugPrint('Ads load failed for ${placement.wire}: $e');
      if (isClosed) return;
      // A failed refresh keeps whatever was showing; a failed first load
      // collapses the slot.
      final previous = state.slot(placement);
      emit(state.withSlot(
        placement,
        previous.ads.isNotEmpty
            ? AdSlot(status: AdSlotStatus.loaded, ads: previous.ads)
            : const AdSlot(status: AdSlotStatus.failed),
      ));
    }
  }

  /// Call once the ad is actually on screen (≥50% visible).
  void recordImpression(AdModel ad) {
    if (_impressed.add(ad.id)) _repository.trackImpression(ad.id);
  }

  /// The ad's image couldn't load — drop it everywhere for this session.
  void hide(AdModel ad) {
    if (state.hiddenIds.contains(ad.id)) return;
    emit(state.copyWith(hiddenIds: {...state.hiddenIds, ad.id}));
  }

  /// Records the click and opens the advertiser's site in the browser.
  /// False when nothing could open it.
  Future<bool> open(AdModel ad) async {
    _repository.trackClick(ad.id);
    final uri = Uri.tryParse(ad.targetUrl);
    if (uri == null || uri.scheme != 'https') return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Ad launch failed for ${ad.targetUrl}: $e');
      return false;
    }
  }
}
