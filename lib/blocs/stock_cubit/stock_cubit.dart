import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/stock_repository.dart';
import '../../screens/location/cubit/location_cubit.dart';

/// At or below this many units left, products show an "Only N left" badge.
const int kLowStockThreshold = 5;

/// How often stock is re-synced (as a cheap delta) while the app is open.
const Duration _kPollInterval = Duration(seconds: 45);

/// Live stock for the dark store serving the bound address, as one
/// `productId -> sellable units` map. Products, the cart and wishlists keep
/// holding plain [ProductModel]s; stock lives here only, so a change never
/// means rebuilding those lists. Widgets `select` the one entry they show.
class StockState extends Equatable {
  final String? warehouseId;
  final Map<String, int> _stock;

  /// False until the first full sync for [warehouseId] lands.
  final bool loaded;

  /// Bumped on every real change, so equality never deep-compares the map.
  final int version;

  const StockState({
    this.warehouseId,
    Map<String, int> stock = const {},
    this.loaded = false,
    this.version = 0,
  }) : _stock = stock;

  /// Units left, or null while unknown (not loaded yet, no store bound, or
  /// the backend doesn't serve stock). Unknown is treated as available —
  /// the server still has the final say when the order is placed.
  int? stockOf(String productId) => loaded ? _stock[productId] : null;

  bool isSoldOut(String productId) => stockOf(productId) == 0;

  /// N when 1..[kLowStockThreshold] are left, else null.
  int? lowStockCount(String productId) {
    final s = stockOf(productId);
    return s != null && s > 0 && s <= kLowStockThreshold ? s : null;
  }

  @override
  List<Object?> get props => [warehouseId, loaded, version];
}

class StockCubit extends Cubit<StockState> with WidgetsBindingObserver {
  final StockRepository _repository;
  late final StreamSubscription<LocationState> _locationSub;
  Timer? _timer;
  String? _cursor;
  bool _foreground = true;

  /// Every fetch runs through this chain, one at a time, so an older
  /// response can never land on top of a newer one.
  Future<void> _queue = Future.value();

  StockCubit(this._repository, LocationCubit location)
      : super(const StockState()) {
    WidgetsBinding.instance.addObserver(this);
    _locationSub = location.stream.listen(_onLocation);
    _onLocation(location.state);
  }

  void _onLocation(LocationState location) {
    if (location is Bound && location.darkStoreId != null) {
      _bind(location.darkStoreId!);
    }
  }

  /// A different store has different stock — start over with a full sync.
  void _bind(String warehouseId) {
    if (warehouseId == state.warehouseId) return;
    _cursor = null;
    emit(StockState(warehouseId: warehouseId));
    refresh();
    _restartTimer();
  }

  /// Full sync the first time for a store, a delta afterwards.
  Future<void> refresh() => _enqueue(() async {
        final warehouseId = state.warehouseId;
        if (warehouseId == null) return;
        final snapshot =
            await _repository.fetchStock(warehouseId, since: _cursor);
        if (isClosed || warehouseId != state.warehouseId) return;
        _cursor = snapshot.serverTime;
        _merge(snapshot.stock, replace: snapshot.full);
      });

  /// Freshest numbers for a few products — e.g. the cart on open, or a
  /// product page — without touching the delta cursor.
  Future<void> refreshProducts(Iterable<String> productIds) {
    final ids = productIds.toSet();
    if (ids.isEmpty) return Future.value();
    return _enqueue(() async {
      final warehouseId = state.warehouseId;
      if (warehouseId == null || !state.loaded) return;
      final snapshot =
          await _repository.fetchStock(warehouseId, productIds: ids);
      if (isClosed || warehouseId != state.warehouseId) return;
      _merge(snapshot.stock);
    });
  }

  /// What the server reported as left when an order was refused.
  void applyShortages(Map<String, int> available) {
    if (state.loaded) _merge(available);
  }

  void _merge(Map<String, int> incoming, {bool replace = false}) {
    final current = state._stock;
    if (!replace &&
        state.loaded &&
        incoming.entries.every((e) => current[e.key] == e.value)) {
      return; // nothing actually changed — no rebuilds
    }
    emit(StockState(
      warehouseId: state.warehouseId,
      stock: Map.unmodifiable(replace ? incoming : {...current, ...incoming}),
      loaded: true,
      version: state.version + 1,
    ));
  }

  Future<void> _enqueue(Future<void> Function() task) {
    final next = _queue.then((_) => task()).catchError((Object e) {
      // Offline or an older backend without the stock endpoint: keep what
      // we have (or stay "unknown") and try again on the next tick.
      debugPrint('Stock sync failed: $e');
    });
    _queue = next;
    return next;
  }

  void _restartTimer() {
    _timer?.cancel();
    if (!_foreground || state.warehouseId == null) return;
    _timer = Timer.periodic(_kPollInterval, (_) => refresh());
  }

  @override
  // Not `state`: that would shadow the cubit's own state.
  // ignore: avoid_renaming_method_parameters
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final foreground = lifecycle == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      // Anything could have sold while we were away.
      refresh();
      _restartTimer();
    } else {
      _timer?.cancel();
    }
  }

  @override
  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSub.cancel();
    _timer?.cancel();
    return super.close();
  }
}
