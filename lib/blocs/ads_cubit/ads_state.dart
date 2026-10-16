import 'package:equatable/equatable.dart';
import '../../shared/models/ad_model.dart';

enum AdSlotStatus { initial, loading, loaded, failed }

/// One placement's ads, fetched at most once per session unless refreshed.
class AdSlot extends Equatable {
  final AdSlotStatus status;
  final List<AdModel> ads;

  const AdSlot({this.status = AdSlotStatus.initial, this.ads = const []});

  /// Loaded or failed — either way, there's nothing more to wait for.
  bool get isResolved =>
      status == AdSlotStatus.loaded || status == AdSlotStatus.failed;

  @override
  List<Object?> get props => [status, ads];
}

class AdsState extends Equatable {
  final Map<AdPlacement, AdSlot> slots;
  final AdSettings settings;

  /// Ads whose image failed to load — hidden everywhere for the session.
  final Set<String> hiddenIds;

  const AdsState({
    this.slots = const {},
    this.settings = const AdSettings(),
    this.hiddenIds = const {},
  });

  AdSlot slot(AdPlacement placement) => slots[placement] ?? const AdSlot();

  /// Ads to actually render for [placement], in priority order.
  List<AdModel> visibleAds(AdPlacement placement) => slot(placement)
      .ads
      .where((ad) => !hiddenIds.contains(ad.id))
      .toList(growable: false);

  AdsState copyWith({
    Map<AdPlacement, AdSlot>? slots,
    AdSettings? settings,
    Set<String>? hiddenIds,
  }) {
    return AdsState(
      slots: slots ?? this.slots,
      settings: settings ?? this.settings,
      hiddenIds: hiddenIds ?? this.hiddenIds,
    );
  }

  AdsState withSlot(AdPlacement placement, AdSlot slot) =>
      copyWith(slots: {...slots, placement: slot});

  @override
  List<Object?> get props => [slots, settings, hiddenIds];
}
