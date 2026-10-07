import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../blocs/auth_bloc/auth_bloc.dart';
import '../../../blocs/auth_bloc/auth_state.dart';
import '../../../data/repositories/location_repository.dart'
    show AddressSearchFailed, distanceMeters;
import '../../../shared/models/checkout_address_model.dart';
import '../../../shared/models/saved_address_model.dart';
import '../../address_book/views/address_book_screen.dart';
import '../cubit/location_cubit.dart';
import 'add_address_wizard/address_wizard_draft.dart';
import 'map_pin_picker_screen.dart';
import 'not_deliverable_view.dart';

/// Saved addresses + a best-effort current-position fix, fetched together —
/// see [_LocationPickerSheetState._loadMainPickerData] for why these are
/// combined into a single future rather than two independent ones.
typedef MainPickerData = ({
  List<SavedAddressModel> addresses,
  LatLng? currentPosition,
});

class LocationPickerSheet extends StatefulWidget {
  /// False (default): the ambient "is my area serviceable" flow — GPS/search
  /// picks skip straight to the answer, and "Add new address" is hidden
  /// since there's no named-address feature to attach a manually-dropped
  /// pin to from here. True: an explicit add/edit-a-delivery-address flow
  /// (Address Book, checkout) — GPS/search picks land on the pin-adjust
  /// step, and "Add new address" (precise pin drop) stays available.
  final bool precise;

  /// Which flow this sheet was entered from — threaded through to whatever
  /// MapPinPickerScreen it eventually pushes, and from there to the
  /// add-address wizard.
  final AddressWizardEntryPoint entryPoint;

  /// Only meaningful for the checkout entry point — threaded through to the
  /// wizard's [AddressWizardDraft.onCheckoutSave].
  final void Function(CheckoutAddressModel)? onCheckoutSave;

  const LocationPickerSheet({
    super.key,
    this.precise = false,
    this.entryPoint = AddressWizardEntryPoint.addressBook,
    this.onCheckoutSave,
  });

  static Future<void> show(
    BuildContext context, {
    bool precise = false,
    AddressWizardEntryPoint entryPoint = AddressWizardEntryPoint.addressBook,
    void Function(CheckoutAddressModel)? onCheckoutSave,
  }) async {
    final cubit = context.read<LocationCubit>();
    // Captured before anything below can move the cubit off of it — restored
    // afterward if the sheet gets dismissed/abandoned without landing on a
    // new Bound (see the check after the await below).
    final priorState = cubit.state;
    final priorBound = priorState is Bound ? priorState : null;
    // Opening the sheet while state is already NotDeliverable (carried over
    // from before it was opened — e.g. "Choose a different location" on
    // NotServiceableScreen, the header's "Not deliverable here" dropdown,
    // or Address Book/AddAddressScreen's own "Add new"/"Use current
    // location" reached while their embedded NotDeliverableView is already
    // showing) would otherwise render that exact same sorry message a
    // second time, stacked on top of the one already visible behind it.
    // Reset to ManualEntry first so the sheet opens fresh on the actual
    // search view instead. Doesn't affect the legitimate case — reaching
    // NotDeliverable from an action taken *inside* the sheet (a saved-
    // address tap, "Use current location") still renders NotDeliverableView
    // inline as normal, since that happens after this one-time check, via
    // the sheet's own BlocConsumer further down.
    if (cubit.state is NotDeliverable) {
      cubit.pickDifferentLocation();
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: LocationPickerSheet(
          precise: precise,
          entryPoint: entryPoint,
          onCheckoutSave: onCheckoutSave,
        ),
      ),
    );
    // Covers every dismissal path uniformly (drag-to-dismiss, tap-outside,
    // back button, or reaching NotDeliverable/ManualEntry and just closing
    // without finishing) — this await already spans the sheet's entire
    // lifetime, including any MapPinPickerScreen pushed from within it
    // (e.g. via "Adjust pin on map & save"), so by the time control gets
    // here the whole exploration is over one way or another. Exploring a
    // new location must not be destructive to an already-bound address
    // until a new bind actually succeeds.
    if (cubit.state is! Bound && priorBound != null) {
      cubit.restorePreviousBound(priorBound);
    }
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<({String label, LatLng position})> _results = [];
  bool _isSearching = false;
  // True when the last search attempt couldn't complete at all (network/
  // backend unreachable) — distinct from it completing and genuinely
  // finding nothing, which is just an empty [_results] with this false.
  bool _searchFailed = false;

  // Saved addresses + the best-effort current-position fix (for "X km away"
  // badges) are fetched together as ONE future, computed once here rather
  // than inline in _MainPickerView.build() — a future built inline is
  // re-created (and re-fetched from the backend) on every rebuild of that
  // widget, which is exactly what used to happen the instant the GPS fix
  // landed: that arrival triggered a rebuild, which re-ran the inline
  // getSavedAddresses() call, which reset the list back to its loading
  // state right as the badges should have appeared. Fetching both
  // concurrently and caching the combined future means the list and its
  // distance badges always render together, in one pass, the first time.
  late Future<MainPickerData> _mainPickerDataFuture;

  @override
  void initState() {
    super.initState();
    _mainPickerDataFuture = _loadMainPickerData();
  }

  Future<MainPickerData> _loadMainPickerData() async {
    final cubit = context.read<LocationCubit>();
    // Both calls are started here, before either is awaited below, so the
    // network fetch and the GPS fix resolve concurrently rather than one
    // after the other.
    final addressesFuture = cubit.getSavedAddresses();
    final positionFuture = cubit.tryGetCurrentPosition();
    return (
      addresses: await addressesFuture,
      currentPosition: await positionFuture,
    );
  }

  /// Re-runs the combined fetch above — called after returning from the
  /// Address Book so edits/deletes made there are reflected here (see
  /// [_openAddressBook]).
  void _refreshMainPickerData() {
    setState(() => _mainPickerDataFuture = _loadMainPickerData());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _results = [];
        _searchFailed = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    setState(() {
      _isSearching = true;
      _searchFailed = false;
    });
    try {
      final results = await context.read<LocationCubit>().searchAddress(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } on AddressSearchFailed {
      if (!mounted) return;
      setState(() {
        _results = [];
        _isSearching = false;
        _searchFailed = true;
      });
    }
  }

  /// Pushes the map screen and, once it returns, closes this sheet if the
  /// pin was successfully confirmed & bound. Deliberately lives here (on
  /// the sheet's own long-lived State) rather than inside a sub-view that
  /// gets swapped out by the BlocBuilder the instant state becomes Bound,
  /// disposing its context before the awaited Navigator.push future even
  /// resolves, which silently no-ops any pop attempted from it.
  ///
  /// Shared by both entry modes: the listener in [build] pushes this the
  /// instant GPS or a search result lands on [Confirming] — neither mode
  /// stops at an intermediate text preview first.
  Future<void> _pushMapConfirm(Confirming state,
      {required bool ambientConfirm}) async {
    final cubit = context.read<LocationCubit>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: MapPinPickerScreen(
            initialPosition: state.position,
            initialFormattedAddress: state.formattedAddress,
            ambientConfirm: ambientConfirm,
            entryPoint: widget.entryPoint,
            onCheckoutSave: widget.onCheckoutSave,
          ),
        ),
      ),
    );
    // onCheckoutSave == null guard: for the checkout entry point,
    // ReviewLocationScreen's listener already pops this sheet itself as one
    // of 4 explicit, deterministic pops before calling onCheckoutSave — an
    // independent pop here (racing that sequence, or firing after it) could
    // pop the CheckoutScreen onCheckoutSave's pushReplacement just pushed.
    if (!mounted) return;
    if (cubit.state is Bound) {
      if (widget.onCheckoutSave == null) Navigator.of(context).maybePop();
      return;
    }
    // Backed out of the map screen without binding. The builder's Confirming
    // branch is only the "Loading map…" placeholder that exists to cover
    // this push, so leaving the cubit on Confirming strands the sheet on
    // that spinner permanently — the listener can't re-fire without a state
    // change, so nothing re-pushes the map either, and drag-to-dismiss would
    // be the only way out. Reset to ManualEntry so backing out lands on the
    // plain search view instead (with the user's previous query and results
    // still in place).
    if (cubit.state is Confirming) {
      cubit.pickDifferentLocation();
    }
  }

  /// Opens the Address Book and, once it returns, refreshes this sheet's
  /// own saved-addresses list — edits/deletes made there (e.g. tapping the
  /// gear icon and deleting an address) otherwise leave the stale list
  /// showing here, since nothing else tells [_MainPickerView]'s FutureBuilder
  /// to re-fetch (popping back to this route doesn't itself trigger a
  /// LocationCubit state change to rebuild off of).
  Future<void> _openAddressBook() async {
    final cubit = context.read<LocationCubit>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const AddressBookScreen(),
        ),
      ),
    );
    if (mounted) _refreshMainPickerData();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: BlocConsumer<LocationCubit, LocationState>(
            listener: (context, state) {
              // Binding succeeded — the header already reflects it, so
              // close the sheet automatically. Only do this when the
              // sheet is actually the topmost route: when a map confirm
              // step has pushed MapPinPickerScreen on top, that screen
              // owns closing itself on Bound — popping here too would
              // race it and could pop the wrong route.
              final route = ModalRoute.of(context);
              final isTopmost = route == null || route.isCurrent;
              if (state is Bound) {
                if (isTopmost) Navigator.of(context).maybePop();
              } else if (state is Confirming && isTopmost) {
                // Both modes land straight on the map+pin confirm step
                // instead of stopping at an intermediate text preview —
                // ambientConfirm controls only the chrome MapPinPickerScreen
                // shows once there (trimmed for ambient, full label/landmark
                // UI for precise). Gated on isTopmost for the same reason as
                // the Bound case above: once MapPinPickerScreen is pushed, IT
                // keeps re-emitting Confirming as its own normal operation
                // (initState seeding, dragging the pin, its own search box)
                // — without this guard, every one of those would push
                // ANOTHER map screen on top, since this listener stays
                // subscribed the whole time the sheet is merely buried, not
                // disposed.
                _pushMapConfirm(state, ambientConfirm: !widget.precise);
              }
            },
            builder: (context, state) {
              if (state is PermissionPrimer) {
                return _PermissionPrimerView(scrollController: scrollController);
              }
              if (state is CheckingServiceability) {
                return const _CenteredLoader(label: "Checking delivery availability…");
              }
              if (state is NotDeliverable) {
                return SingleChildScrollView(
                  controller: scrollController,
                  child: const NotDeliverableView(),
                );
              }
              if (state is Confirming) {
                // Both modes auto-navigate straight to the map/pin confirm
                // step (see the listener above) — this never renders for
                // longer than the one frame before that push happens. A
                // brief loader covers that frame. It's also never left
                // standing after the map screen is dismissed —
                // _pushMapConfirm resets the cubit to ManualEntry on a
                // non-binding back-out, which falls this builder through to
                // _MainPickerView.
                return const _CenteredLoader(label: "Loading map…");
              }
              return _MainPickerView(
                scrollController: scrollController,
                searchController: _searchController,
                onSearchChanged: _onSearchChanged,
                onRetrySearch: () => _runSearch(_searchController.text),
                results: _results,
                isSearching: _isSearching,
                searchFailed: _searchFailed,
                isResolving: state is Resolving || state is PermissionChecking,
                notice: state is ManualEntry ? state.message : null,
                precise: widget.precise,
                mainPickerDataFuture: _mainPickerDataFuture,
                entryPoint: widget.entryPoint,
                onCheckoutSave: widget.onCheckoutSave,
                onOpenAddressBook: _openAddressBook,
              );
            },
          ),
        );
      },
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  final String label;
  const _CenteredLoader({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFF3DAA5C)),
            const SizedBox(height: 16),
            Text(label,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Color(0xFF6B6B6B),
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Permission primer ("rationale before the OS dialog") ──────────────
class _PermissionPrimerView extends StatelessWidget {
  final ScrollController scrollController;
  const _PermissionPrimerView({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.location_on_rounded,
                color: Color(0xFF3DAA5C), size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            "Enable location for faster delivery",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Colors.black87),
          ),
          const SizedBox(height: 8),
          const Text(
            "We'll use your location to find your address and show you what's deliverable nearby. You can always enter it manually instead.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF6B6B6B)),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => context.read<LocationCubit>().acknowledgePrimer(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3DAA5C),
                shape:
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Allow location access",
                  style:
                      TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<LocationCubit>().declinePrimer(),
            child: const Text("Enter address manually",
                style: TextStyle(color: Color(0xFF6B6B6B), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ── Main picker: current location + search + saved addresses ──────────
class _MainPickerView extends StatelessWidget {
  final ScrollController scrollController;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRetrySearch;
  final List<({String label, LatLng position})> results;
  final bool isSearching;
  final bool searchFailed;
  final bool isResolving;
  // ManualEntry's reason (permission denied, location services off, GPS
  // timeout…). Without it, a failed "Use my current location" tap — or a
  // denied OS dialog right before this sheet auto-opened — would leave the
  // user on the search view with no hint why nothing happened.
  final String? notice;
  final bool precise;
  final Future<MainPickerData> mainPickerDataFuture;
  final AddressWizardEntryPoint entryPoint;
  final void Function(CheckoutAddressModel)? onCheckoutSave;
  final VoidCallback onOpenAddressBook;

  const _MainPickerView({
    required this.scrollController,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRetrySearch,
    required this.results,
    required this.isSearching,
    required this.searchFailed,
    required this.isResolving,
    this.notice,
    required this.precise,
    required this.mainPickerDataFuture,
    required this.entryPoint,
    this.onCheckoutSave,
    required this.onOpenAddressBook,
  });

  @override
  Widget build(BuildContext context) {
    final isGuest = context.watch<AuthBloc>().state is! AuthAuthenticated;
    // A search that ran and came back empty (found nothing, or couldn't
    // reach the geocoder at all) must not silently fall through to the
    // "Use my current location" / saved-addresses block below — that would
    // look exactly like the search box was never touched. Only collapse to
    // that default view while there's no active query.
    final hasActiveQuery = searchController.text.trim().length >= 3;
    final showSearchEmptyState =
        hasActiveQuery && !isSearching && results.isEmpty;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Select delivery location",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87)),
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF0F0F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close_rounded,
                    size: 18, color: Color(0xFF6B6B6B)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (notice != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 18, color: Color(0xFFF57C00)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(notice!,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF6B6B6B))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Search field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
            decoration: const InputDecoration(
              hintText: "Search for area, street, or landmark",
              hintStyle: TextStyle(
                  fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9E9E9E)),
              prefixIcon: Icon(Icons.search_rounded, color: Color(0xFF6B6B6B)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        if (isSearching)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF3DAA5C)))),
          ),

        if (results.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...results.map((r) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.location_on_outlined,
                    color: Color(0xFF6B6B6B)),
                title: Text(r.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins', fontSize: 13, color: Colors.black87)),
                // autoConfirm defaults to false: every search result lands
                // on Confirming and gets reviewed on the map first (see
                // the sheet's listener/builder for how each mode routes
                // from there).
                onTap: () => context
                    .read<LocationCubit>()
                    .selectSearchResult(r.label, r.position),
              )),
        ] else if (showSearchEmptyState) ...[
          const SizedBox(height: 8),
          _SearchEmptyState(
            query: searchController.text.trim(),
            failed: searchFailed,
            onRetry: onRetrySearch,
          ),
        ] else ...[
          const SizedBox(height: 8),
          // Use current location
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: isResolving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Color(0xFF3DAA5C)))
                : const Icon(Icons.my_location_rounded, color: Color(0xFF3DAA5C)),
            title: const Text("Use my current location",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3DAA5C))),
            onTap: isResolving
                ? null
                : () => context
                    .read<LocationCubit>()
                    .useCurrentLocation(autoConfirm: !precise),
          ),
          const Divider(height: 24, color: Color(0xFFE0E0E0)),

          // Guests have no saved-addresses concept — the picked location
          // only lives for the session (see LocationCubit._runServiceabilityCheck),
          // so showing an always-empty "Saved addresses" list is just noise.
          if (!isGuest) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Saved addresses",
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B6B6B))),
                GestureDetector(
                  onTap: onOpenAddressBook,
                  child: const Icon(Icons.settings_outlined,
                      size: 18, color: Color(0xFF6B6B6B)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FutureBuilder<MainPickerData>(
              future: mainPickerDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(
                        color: Color(0xFF3DAA5C), backgroundColor: Color(0xFFF0F0F0)),
                  );
                }
                // Addresses and the current-position fix arrive together
                // (see MainPickerData) — a saved-address tile is never
                // shown before it already knows whether it can render a
                // distance badge, so there's no separate pass where the
                // list appears first and badges pop in a moment later.
                final addresses = snapshot.data?.addresses ?? [];
                final currentPosition = snapshot.data?.currentPosition;
                if (addresses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("No saved addresses yet",
                        style: TextStyle(
                            fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9E9E9E))),
                  );
                }
                return Column(
                  children: addresses
                      .map((a) => _SavedAddressTile(
                          address: a, currentPosition: currentPosition))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          // Manually dropping a pin without a search match only matters
          // when actually building a named delivery address — the ambient
          // "is my area serviceable" flow has no address to attach it to,
          // so this stays hidden there and only shows in precise mode
          // (Address Book / checkout).
          if (precise)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_location_alt_outlined,
                  color: Color(0xFF3DAA5C)),
              title: const Text("Add new address",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3DAA5C))),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: context.read<LocationCubit>(),
                    child: MapPinPickerScreen(
                      initialPosition:
                          const LatLng(8.5241, 76.9366), // Trivandrum
                      entryPoint: entryPoint,
                      onCheckoutSave: onCheckoutSave,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ── Search ran and came back empty — either genuinely no matches, or the
// lookup itself couldn't complete (e.g. no network / backend unreachable).
// Rendered in place of the search results list so it never gets confused
// with the unrelated "Use my current location" / saved-addresses default. ──
class _SearchEmptyState extends StatelessWidget {
  final String query;
  final bool failed;
  final VoidCallback onRetry;
  const _SearchEmptyState({
    required this.query,
    required this.failed,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            failed ? Icons.wifi_off_rounded : Icons.search_off_rounded,
            color: failed ? const Color(0xFFF57C00) : const Color(0xFF9E9E9E),
            size: 28,
          ),
          const SizedBox(height: 10),
          Text(
            failed
                ? "Couldn't search right now"
                : 'No results for "$query"',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.black87),
          ),
          const SizedBox(height: 4),
          Text(
            failed
                ? "Check your connection and try again, or drop a pin on the map instead."
                : "Try a different area, street, or landmark.",
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF6B6B6B)),
          ),
          if (failed) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF3DAA5C),
              ),
              child: const Text("Try again",
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SavedAddressTile extends StatelessWidget {
  final SavedAddressModel address;
  final LatLng? currentPosition;
  const _SavedAddressTile({required this.address, this.currentPosition});

  IconData get _icon {
    switch (address.label) {
      case AddressLabel.home:
        return Icons.home_rounded;
      case AddressLabel.work:
        return Icons.work_rounded;
      case AddressLabel.other:
        return Icons.place_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final pos = currentPosition;
    // A saved address with no real fix (backend returned null lat/lng —
    // e.g. addresses created before those columns existed) is stored as
    // LatLng(0, 0), the same "unknown position" sentinel used elsewhere
    // (see delivery_zone_model.dart). Showing a distance against Null
    // Island would always read as a bogus ~8,000+ km, so skip the badge
    // instead, same as when there's no current-position fix at all.
    final hasRealPosition =
        address.position.latitude != 0 || address.position.longitude != 0;
    final distanceLabel = (pos == null || !hasRealPosition)
        ? null
        : _formatDistance(distanceMeters(pos, address.position));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.read<LocationCubit>().switchToSavedAddress(address),
      child: Container(
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: Icon(_icon, color: const Color(0xFF3DAA5C), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address.displayLabel,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  const SizedBox(height: 4),
                  Text(address.primaryAddressText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF6B6B6B))),
                  if (distanceLabel != null) ...[
                    const SizedBox(height: 8),
                    _DistanceBadge(label: distanceLabel),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDistance(double meters) {
  if (meters < 1000) return "${meters.round()} m away";
  return "${(meters / 1000).toStringAsFixed(1)} km away";
}

class _DistanceBadge extends StatelessWidget {
  final String label;
  const _DistanceBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.near_me_rounded, size: 11, color: Color(0xFF6B6B6B)),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B6B6B))),
        ],
      ),
    );
  }
}
