import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';

import '../../../blocs/auth_bloc/auth_bloc.dart';
import '../../../blocs/auth_bloc/auth_state.dart';
import '../../../data/repositories/location_repository.dart'
    show AddressSearchFailed, distanceMeters;
import '../../../shared/models/place_suggestion_model.dart';
import '../../../shared/models/saved_address_model.dart';
import '../../../shared/widgets/place_suggestion_tile.dart';
import '../../address_book/views/address_book_screen.dart';
import '../cubit/location_cubit.dart';
import 'map_pin_picker_screen.dart';

/// The ambient "where are you / is my area serviceable" picker: GPS, search,
/// or a saved address. GPS picks bind straight away; search results get a
/// trimmed map confirm step. Creating or editing a full named address is
/// not done here — that's MapPinPickerScreen's add-address wizard, opened
/// directly by checkout and the Address Book.
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  static Future<void> show(BuildContext context) async {
    final cubit = context.read<LocationCubit>();
    // Captured before anything below can move the cubit off of it — restored
    // afterward if the sheet is dismissed without the user picking anything.
    final priorState = cubit.state;
    // Opening the sheet while state is already NotDeliverable (carried over
    // from before it was opened — e.g. "Choose a different location" on
    // NotServiceableScreen, or the header's "Not deliverable here" dropdown)
    // would otherwise make the sheet's listener see no change on a repeat
    // pick of the same spot. Reset to ManualEntry so it opens fresh on the
    // search view.
    if (cubit.state is NotDeliverable) {
      cubit.pickDifferentLocation();
    }
    // True when the sheet closed itself because the user's pick reached a
    // result (see the listener in build) — that result is what Home should
    // now show, good or bad. Anything else (drag-to-dismiss, tap-outside,
    // back, or backing out of a map confirm step) is an abandoned
    // exploration, which must leave the app as it was before the sheet
    // opened.
    final picked = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => BlocProvider.value(
        value: cubit,
        child: const LocationPickerSheet(),
      ),
    );
    if (picked != true) cubit.restorePreviousState(priorState);
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  List<PlaceSuggestion> _results = [];
  bool _poweredByGoogle = false;
  bool _isSearching = false;
  // Bumped per search so a slow response for "kas" can't overwrite the
  // newer results for "kasara" that arrived first.
  int _searchSeq = 0;
  String _sessionToken = newPlacesSessionToken();
  // Ranks suggestions near the user: the GPS fix once it resolves, else the
  // address they're currently on. Null just means "anywhere in India".
  LatLng? _searchBias;
  // True when the last search attempt couldn't complete at all (network/
  // backend unreachable) — distinct from it completing and genuinely
  // finding nothing, which is just an empty [_results] with this false.
  bool _searchFailed = false;

  // Saved addresses and the best-effort current-position fix (only used for
  // the "X km away" badges) are two independent futures, both started once
  // here, concurrently. The list renders as soon as the addresses arrive —
  // a GPS fix can take many seconds (indoors, cold GPS, emulators) and must
  // not hold the list back; each badge shows a small placeholder until the
  // position resolves. Both are cached here rather than created inline in
  // _MainPickerView.build(): an inline future is re-created (re-fetching
  // from the backend) on every rebuild, which would reset the list to its
  // loading state the moment anything rebuilt it.
  late Future<List<SavedAddressModel>> _addressesFuture;
  late final Future<LatLng?> _positionFuture;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<LocationCubit>();
    _addressesFuture = cubit.getSavedAddresses();
    _positionFuture = cubit.tryGetCurrentPosition();
    final current = cubit.state;
    if (current is Bound) _searchBias = current.address.position;
    _positionFuture.then((p) {
      if (p != null) _searchBias = p;
    });
  }

  /// Re-fetches the saved addresses — called after returning from the
  /// Address Book so edits/deletes made there are reflected here (see
  /// [_openAddressBook]). The position fix is still valid, so it's kept.
  void _refreshSavedAddresses() {
    setState(() {
      _addressesFuture = context.read<LocationCubit>().getSavedAddresses();
    });
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
      _searchSeq++; // drop any in-flight response for the old query
      setState(() {
        _results = [];
        _isSearching = false;
        _searchFailed = false;
      });
      return;
    }
    _debounce =
        Timer(const Duration(milliseconds: 300), () => _runSearch(query));
  }

  Future<void> _runSearch(String query) async {
    final seq = ++_searchSeq;
    setState(() {
      _isSearching = true;
      _searchFailed = false;
    });
    try {
      final search = await context.read<LocationCubit>().searchPlaces(query,
          near: _searchBias, sessionToken: _sessionToken);
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = search.results;
        _poweredByGoogle = search.poweredByGoogle;
        _isSearching = false;
      });
    } on AddressSearchFailed {
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = [];
        _isSearching = false;
        _searchFailed = true;
      });
    }
  }

  // autoConfirm defaults to false: every search result lands on Confirming
  // and gets reviewed on the map first (see the listener/builder in build
  // for how each mode routes from there).
  Future<void> _selectResult(PlaceSuggestion suggestion) async {
    final cubit = context.read<LocationCubit>();
    final token = _sessionToken;
    // The pick ends this billing session; the next search starts a new one.
    _sessionToken = newPlacesSessionToken();
    try {
      final position = await cubit.resolvePlace(suggestion, sessionToken: token);
      if (!mounted) return;
      cubit.selectSearchResult(suggestion.label, position);
    } on AddressSearchFailed {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't open that place. Please try again.")));
    }
  }

  /// Pushes the map screen and, once it returns, closes this sheet if the
  /// pin was successfully confirmed & bound. Deliberately lives here (on
  /// the sheet's own long-lived State) rather than inside a sub-view that
  /// gets swapped out by the BlocBuilder the instant state becomes Bound,
  /// disposing its context before the awaited Navigator.push future even
  /// resolves, which silently no-ops any pop attempted from it.
  ///
  /// The listener in [build] pushes this the instant a search result lands
  /// on [Confirming] — there's no intermediate text preview first.
  Future<void> _pushMapConfirm(Confirming state) async {
    final cubit = context.read<LocationCubit>();
    await Navigator.push(
      context,
      MapPinPickerScreen.route(
        cubit: cubit,
        initialPosition: state.position,
        initialFormattedAddress: state.formattedAddress,
        ambientConfirm: true,
      ),
    );
    if (!mounted) return;
    if (cubit.state is Bound) {
      Navigator.of(context).maybePop(true);
      return;
    }
    // Backed out of the map screen without binding — possibly after it
    // showed NotDeliverable/CheckFailed inline. Reset to ManualEntry so the
    // sheet lands back on the plain search view (with the user's previous
    // query and results still in place) rather than on the "Loading map…"
    // placeholder or a result state the user just walked away from.
    cubit.pickDifferentLocation();
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
    if (mounted) _refreshSavedAddresses();
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
              // The user's pick (saved address, current location) reached
              // a result — close the sheet so they see it on Home: the new
              // address in the header, the not-serviceable screen, or the
              // couldn't-check screen with its retry. Nothing is left to do
              // here, and staying open would hide that result. Only when
              // the sheet is the topmost route: when a map confirm step has
              // pushed MapPinPickerScreen on top, that screen owns its own
              // result (and NotDeliverable is shown inline there) — popping
              // here too would race it and could pop the wrong route.
              final route = ModalRoute.of(context);
              final isTopmost = route == null || route.isCurrent;
              final isResult = state is Bound ||
                  state is NotDeliverable ||
                  state is CheckFailed;
              if (isResult) {
                if (isTopmost) Navigator.of(context).maybePop(true);
              } else if (state is Confirming && isTopmost) {
                // A search result lands straight on the (trimmed-chrome)
                // map+pin confirm step instead of stopping at an
                // intermediate text preview. Gated on isTopmost for the
                // same reason as the Bound case above: once
                // MapPinPickerScreen is pushed, IT
                // keeps re-emitting Confirming as its own normal operation
                // (initState seeding, dragging the pin, its own search box)
                // — without this guard, every one of those would push
                // ANOTHER map screen on top, since this listener stays
                // subscribed the whole time the sheet is merely buried, not
                // disposed.
                _pushMapConfirm(state);
              }
            },
            builder: (context, state) {
              if (state is PermissionPrimer) {
                return _PermissionPrimerView(
                    scrollController: scrollController);
              }
              if (state is CheckingServiceability) {
                return const _CenteredLoader(
                    label: "Checking delivery availability…");
              }
              if (state is Confirming) {
                // Auto-navigates straight to the map/pin confirm step (see
                // the listener above) — this never renders for
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
                poweredByGoogle: _poweredByGoogle,
                onSelectResult: _selectResult,
                isSearching: _isSearching,
                searchFailed: _searchFailed,
                isResolving: state is Resolving || state is PermissionChecking,
                notice: state is ManualEntry ? state.message : null,
                addressesFuture: _addressesFuture,
                positionFuture: _positionFuture,
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
              onPressed: () =>
                  context.read<LocationCubit>().acknowledgePrimer(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3DAA5C),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text("Allow location access",
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<LocationCubit>().declinePrimer(),
            child: const Text("Enter address manually",
                style: TextStyle(
                    color: Color(0xFF6B6B6B), fontWeight: FontWeight.w600)),
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
  final List<PlaceSuggestion> results;
  final bool poweredByGoogle;
  final ValueChanged<PlaceSuggestion> onSelectResult;
  final bool isSearching;
  final bool searchFailed;
  final bool isResolving;
  // ManualEntry's reason (permission denied, location services off, GPS
  // timeout…). Without it, a failed "Use my current location" tap — or a
  // denied OS dialog right before this sheet auto-opened — would leave the
  // user on the search view with no hint why nothing happened.
  final String? notice;
  final Future<List<SavedAddressModel>> addressesFuture;
  final Future<LatLng?> positionFuture;
  final VoidCallback onOpenAddressBook;

  const _MainPickerView({
    required this.scrollController,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRetrySearch,
    required this.results,
    required this.poweredByGoogle,
    required this.onSelectResult,
    required this.isSearching,
    required this.searchFailed,
    required this.isResolving,
    this.notice,
    required this.addressesFuture,
    required this.positionFuture,
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
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF9E9E9E)),
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
          for (final (i, r) in results.indexed) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFEEEEEE)),
            PlaceSuggestionTile(
                suggestion: r, onTap: () => onSelectResult(r)),
          ],
          // Google's terms require this wherever its suggestions are shown
          // without a Google map.
          if (poweredByGoogle)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text("Powered by Google",
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Color(0xFF9E9E9E))),
              ),
            ),
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
                : const Icon(Icons.my_location_rounded,
                    color: Color(0xFF3DAA5C)),
            title: const Text("Use my current location",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3DAA5C))),
            onTap: isResolving
                ? null
                : () => context.read<LocationCubit>().useCurrentLocation(),
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
            FutureBuilder<List<SavedAddressModel>>(
              future: addressesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(
                        color: Color(0xFF3DAA5C),
                        backgroundColor: Color(0xFFF0F0F0)),
                  );
                }
                final addresses = snapshot.data ?? [];
                if (addresses.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("No saved addresses yet",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: Color(0xFF9E9E9E))),
                  );
                }
                return Column(
                  children: addresses
                      .map((a) => _SavedAddressTile(
                          address: a, positionFuture: positionFuture))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
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
            failed ? "Couldn't search right now" : 'No results for "$query"',
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
  final Future<LatLng?> positionFuture;
  const _SavedAddressTile(
      {required this.address, required this.positionFuture});

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
    // A distance to an address with no real fix (see
    // SavedAddressModel.hasPosition) would read as a bogus ~8,000+ km —
    // and since that's known up front, such a tile never shows a badge
    // placeholder either.

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
                  if (address.hasPosition)
                    _AsyncDistanceBadge(
                      target: address.position,
                      positionFuture: positionFuture,
                    ),
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

/// "X km away" badge that doesn't hold up its card: shows a same-sized
/// placeholder while the position fix is pending, cross-fades to the real
/// distance once it lands, and smoothly collapses if no fix is available
/// (permission off, GPS timeout) — the card is usable throughout.
class _AsyncDistanceBadge extends StatelessWidget {
  final LatLng target;
  final Future<LatLng?> positionFuture;
  const _AsyncDistanceBadge({
    required this.target,
    required this.positionFuture,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LatLng?>(
      future: positionFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState != ConnectionState.done;
        final position = snapshot.data;

        final Widget child;
        if (isLoading) {
          child = const Padding(
            key: ValueKey('loading'),
            padding: EdgeInsets.only(top: 8),
            child: _DistanceBadge(),
          );
        } else if (position != null) {
          child = Padding(
            key: const ValueKey('distance'),
            padding: const EdgeInsets.only(top: 8),
            child: _DistanceBadge(
                label: _formatDistance(distanceMeters(position, target))),
          );
        } else {
          child = const SizedBox.shrink(key: ValueKey('none'));
        }

        // AnimatedSize smooths the one case that changes height (no fix →
        // the placeholder collapses away); placeholder → distance is the
        // same pill, so that's a pure cross-fade.
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topLeft,
              children: [...previous, if (current != null) current],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

/// [label] null renders the loading placeholder — same pill, with a small
/// spinner in place of the distance, so nothing shifts when it resolves.
class _DistanceBadge extends StatelessWidget {
  final String? label;
  const _DistanceBadge({this.label});

  @override
  Widget build(BuildContext context) {
    final label = this.label;
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
          if (label == null) ...[
            const SizedBox(
              width: 9,
              height: 9,
              child: CircularProgressIndicator(
                  strokeWidth: 1.5, color: Color(0xFF9E9E9E)),
            ),
            const SizedBox(width: 4),
          ],
          Text(label ?? "km away",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: label == null
                      ? const Color(0xFFBDBDBD)
                      : const Color(0xFF6B6B6B))),
        ],
      ),
    );
  }
}
