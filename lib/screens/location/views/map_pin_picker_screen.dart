import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';

import '../../../data/repositories/location_repository.dart'
    show AddressSearchFailed, distanceMeters;
import '../../../shared/models/place_suggestion_model.dart';
import '../../../shared/models/saved_address_model.dart';
import '../../../shared/widgets/place_suggestion_tile.dart';
import '../cubit/location_cubit.dart';
import 'add_address_wizard/address_details_screen.dart';
import 'add_address_wizard/address_wizard_draft.dart';

/// Full-screen "drop a pin" picker. The pin stays fixed at the screen
/// center — the map pans underneath it — which is what riders' navigation
/// ultimately keys off, so keep this exactly analogous to Swiggy/Zepto/
/// Blinkit rather than a draggable-marker pattern.
class MapPinPickerScreen extends StatefulWidget {
  final LatLng initialPosition;

  /// When set, the screen opens in edit mode for this address — label,
  /// custom label, and landmark are prefilled, and confirming updates it
  /// in place instead of creating a new saved address.
  final SavedAddressModel? existingAddress;

  /// When the caller already resolved an address for [initialPosition]
  /// (e.g. a GPS fix or search result), pass it here so the screen shows
  /// it immediately instead of firing a redundant reverse-geocode call.
  final String? initialFormattedAddress;

  /// True when entered from the ambient "is my area serviceable" search
  /// flow (a LocationPickerSheet search result) rather than an
  /// explicit add/edit-a-delivery-address flow. Trims the chrome down to
  /// just the map + a "Confirm Location" action — no title bar in the
  /// default mode, no Home/Work/Other label chips, no custom-label or
  /// landmark field, and confirming never writes into the real saved-
  /// address list (see LocationCubit.confirmAddress's
  /// persistAsSavedAddress). [existingAddress] is never set alongside this.
  final bool ambientConfirm;

  /// Shows an "Is this your exact delivery location?" prompt above the
  /// address — set when the pin starts on a location we inferred (the
  /// bound area, GPS) rather than one the user just dropped themselves.
  final bool askToConfirmPin;

  const MapPinPickerScreen({
    super.key,
    required this.initialPosition,
    this.existingAddress,
    this.initialFormattedAddress,
    this.ambientConfirm = false,
    this.askToConfirmPin = false,
  });

  /// The only way this screen should be pushed: names the route
  /// [kAddressMapRouteName] so the wizard can pop back to it on save, and
  /// re-provides [cubit] for the new route. Resolves to `true` once the
  /// wizard saved (or, in [ambientConfirm] mode, once a location was bound).
  static Route<bool> route({
    required LocationCubit cubit,
    required LatLng initialPosition,
    SavedAddressModel? existingAddress,
    String? initialFormattedAddress,
    bool ambientConfirm = false,
    bool askToConfirmPin = false,
  }) {
    return MaterialPageRoute<bool>(
      settings: const RouteSettings(name: kAddressMapRouteName),
      builder: (_) => BlocProvider.value(
        value: cubit,
        child: MapPinPickerScreen(
          initialPosition: initialPosition,
          existingAddress: existingAddress,
          initialFormattedAddress: initialFormattedAddress,
          ambientConfirm: ambientConfirm,
          askToConfirmPin: askToConfirmPin,
        ),
      ),
    );
  }

  /// Opens the add-address wizard for a brand-new address, with the pin on
  /// [LocationCubit.bestMapStart]. Returns true once it's saved (and bound).
  static Future<bool> openForNewAddress(BuildContext context) async {
    final cubit = context.read<LocationCubit>();
    final start = await cubit.bestMapStart();
    if (!context.mounted) return false;
    return _openWizard(
      context,
      route(
        cubit: cubit,
        initialPosition: start.position,
        initialFormattedAddress: start.formattedAddress,
        askToConfirmPin: true,
      ),
    );
  }

  /// Opens the add-address wizard in edit mode for [address]. Returns true
  /// once the edit is saved. An address with no stored position (see
  /// [SavedAddressModel.hasPosition]) starts at [LocationCubit.bestMapStart]
  /// instead of (0, 0) in the ocean — saving that would reverse-geocode to
  /// no city/state, which the backend rejects.
  static Future<bool> openForEdit(
      BuildContext context, SavedAddressModel address) async {
    final cubit = context.read<LocationCubit>();
    final start = address.hasPosition
        ? address.position
        : (await cubit.bestMapStart()).position;
    if (!context.mounted) return false;
    return _openWizard(
      context,
      route(cubit: cubit, initialPosition: start, existingAddress: address),
    );
  }

  /// Unless the wizard ends on a new bind, the app's location state must be
  /// left as it was (bound, not deliverable, …) — the map moves the cubit
  /// to Confirming while the pin is being adjusted, an inactive edit saves
  /// without binding, and the review step can land on NotDeliverable.
  static Future<bool> _openWizard(
      BuildContext context, Route<bool> wizardRoute) async {
    final cubit = context.read<LocationCubit>();
    final priorState = cubit.state;
    final saved = await Navigator.push(context, wizardRoute);
    cubit.restorePreviousState(priorState);
    return saved == true;
  }

  @override
  State<MapPinPickerScreen> createState() => _MapPinPickerScreenState();
}

// Roof level — close enough to see individual buildings on satellite.
const double _pinZoom = 18;

gmaps.LatLng _toG(LatLng p) => gmaps.LatLng(p.latitude, p.longitude);

class _MapPinPickerScreenState extends State<MapPinPickerScreen> {
  gmaps.GoogleMapController? _mapController;
  // The point under the fixed centre pin, kept in sync from onCameraMove.
  late LatLng _cameraCenter = widget.initialPosition;
  // Set while the camera is moving because of our own animateCamera call
  // (search pick, locate-me), whose address is already known. Unlike
  // flutter_map, google_maps_flutter doesn't say whether a move came from a
  // gesture, so this is how we skip the drag UI + redundant re-geocode.
  // Starts at the initial position: the map reports an idle once it first
  // loads, and that spot's address was already seeded in initState.
  late LatLng? _programmaticTarget = widget.initialPosition;
  bool _isDragging = false;
  // Hybrid = satellite photo + road/place labels, so customers can drop the
  // pin on their own roof; the layers button flips to the plain map.
  gmaps.MapType _mapType = gmaps.MapType.hybrid;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<PlaceSuggestion> _searchResults = [];
  bool _isSearching = false;
  // Guards against a slow older response overwriting newer results.
  int _searchSeq = 0;
  String _sessionToken = newPlacesSessionToken();

  @override
  void initState() {
    super.initState();
    final existing = widget.existingAddress;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<LocationCubit>();
      if (existing != null && existing.hasPosition) {
        // Avoid a re-geocode flicker showing different wording than what
        // was originally saved, until the user actually moves the pin.
        // (Without a stored position the pin starts elsewhere, so the
        // saved wording wouldn't match it — geocode it below instead.)
        cubit.seedConfirming(existing);
      } else if (widget.initialFormattedAddress != null) {
        // Already resolved by the caller (GPS fix, search result) — don't
        // fire a second reverse-geocode call for the same position.
        cubit.seedConfirmingPosition(
            widget.initialPosition, widget.initialFormattedAddress!);
      } else {
        cubit.updatePinPosition(widget.initialPosition);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _moveCamera(LatLng position) {
    _programmaticTarget = position;
    _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(_toG(position), _pinZoom));
  }

  void _onCameraMoveStarted() {
    if (_programmaticTarget == null && !_isDragging) {
      setState(() => _isDragging = true);
    }
  }

  void _onCameraIdle() {
    final target = _programmaticTarget;
    _programmaticTarget = null;
    // Our own move landing where we sent it already knows its address. If
    // the centre is elsewhere, the user dragged (an animation to the
    // current spot may never report idle, leaving a stale target).
    if (target != null && distanceMeters(target, _cameraCenter) < 2) return;
    setState(() => _isDragging = false);
    context.read<LocationCubit>().updatePinPosition(_cameraCenter);
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      _searchSeq++; // drop any in-flight response for the old query
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      final seq = ++_searchSeq;
      List<PlaceSuggestion> results;
      try {
        // Rank around wherever the map is currently looking.
        results = (await context.read<LocationCubit>().searchPlaces(query,
                near: _cameraCenter, sessionToken: _sessionToken))
            .results;
      } on AddressSearchFailed {
        results = [];
      }
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  Future<void> _selectSearchResult(PlaceSuggestion result) async {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _searchResults = []);
    final cubit = context.read<LocationCubit>();
    final token = _sessionToken;
    _sessionToken = newPlacesSessionToken();
    final LatLng position;
    try {
      position = await cubit.resolvePlace(result, sessionToken: token);
    } on AddressSearchFailed {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Couldn't open that place. Please try again.")));
      return;
    }
    if (!mounted) return;
    // autoConfirm: false — we're already mid pin-adjustment on this screen,
    // so a search result here should just re-center the pin (landing on
    // Confirming, same as GPS/drag), not immediately confirm out from
    // under whatever the user is still doing here.
    cubit.selectSearchResult(result.label, position, autoConfirm: false);
    _moveCamera(position);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, LocationState>(
      // Closes this screen once a bind-worthy save completes (new address,
      // or editing the address that's currently active). Editing a saved
      // address that ISN'T active never emits Bound — it pops itself
      // directly from the confirm button instead (see _ConfirmSheet).
      //
      // NotDeliverable in ambient mode deliberately does NOT pop anymore —
      // _ConfirmSheet now handles that state inline with its own "Use
      // current location" / "Select another location" actions instead of
      // bouncing back to the underlying LocationPickerSheet. Precise mode
      // keeps today's behavior (stays put, pin still adjustable via the
      // disabled-button + drag message) — deliberately not touched here.
      //
      // Ambient mode only: in precise mode a bind only ever comes from the
      // wizard's final step, which pops this screen itself (with `true`)
      // after unwinding the wizard screens above it.
      listener: (context, state) {
        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
        if (state is Bound && widget.ambientConfirm && isCurrent) {
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            gmaps.GoogleMap(
              initialCameraPosition: gmaps.CameraPosition(
                  target: _toG(widget.initialPosition), zoom: _pinZoom),
              mapType: _mapType,
              onMapCreated: (controller) => _mapController = controller,
              onCameraMoveStarted: _onCameraMoveStarted,
              onCameraMove: (position) => _cameraCenter =
                  LatLng(position.target.latitude, position.target.longitude),
              onCameraIdle: _onCameraIdle,
              // The screen has its own locate-me button and search bar.
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
            ),

            // Fixed center pin
            const IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.location_pin,
                      size: 44, color: Color(0xFF3DAA5C)),
                ),
              ),
            ),

            // White fade behind the status bar / title / search so they
            // stay readable over busy satellite imagery.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: MediaQuery.of(context).padding.top +
                      (widget.ambientConfirm ? 120 : 80),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.95),
                        Colors.white.withValues(alpha: 0.75),
                        Colors.white.withValues(alpha: 0),
                      ],
                      stops: const [0, 0.6, 1],
                    ),
                  ),
                ),
              ),
            ),

            // Top bar: back + search
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.ambientConfirm) ...[
                    const Text(
                      "Confirm location",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: Color(0xFF1A1A1A)),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      _RoundIconButton(
                        icon: Icons.arrow_back_rounded,
                        size: _searchBarHeight,
                        borderRadius: _searchBarRadius,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: _searchBarHeight,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(_searchBarRadius),
                            border: Border.all(color: const Color(0xFFE3E3E3)),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.search_rounded,
                                  color: Color(0xFF6B6B6B), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: _onSearchChanged,
                                  style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      color: Color(0xFF1A1A1A)),
                                  decoration: const InputDecoration(
                                    hintText: "Search for area, street...",
                                    hintStyle: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13.5,
                                        color: Color(0xFF9A9A9A)),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              if (_isSearching)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Color(0xFF3DAA5C)),
                                )
                              else if (_searchController.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchController.clear();
                                    setState(() => _searchResults = []);
                                  },
                                  child: const Icon(Icons.close_rounded,
                                      color: Color(0xFF6B6B6B), size: 18),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(
                          top: 6, left: _searchBarHeight + 8),
                      constraints: const BoxConstraints(maxHeight: 260),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_searchBarRadius),
                        border: Border.all(color: const Color(0xFFE3E3E3)),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4)),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, color: Color(0xFFE0E0E0)),
                        itemBuilder: (context, index) {
                          final result = _searchResults[index];
                          return PlaceSuggestionTile(
                            suggestion: result,
                            dense: true,
                            onTap: () => _selectSearchResult(result),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),

            // Satellite <-> plain map toggle
            Positioned(
              right: 16,
              bottom: 312,
              child: _RoundIconButton(
                icon: _mapType == gmaps.MapType.hybrid
                    ? Icons.map_outlined
                    : Icons.satellite_alt_outlined,
                onTap: () => setState(() {
                  _mapType = _mapType == gmaps.MapType.hybrid
                      ? gmaps.MapType.normal
                      : gmaps.MapType.hybrid;
                }),
              ),
            ),

            // Locate-me FAB
            Positioned(
              right: 16,
              bottom: 260,
              child: _RoundIconButton(
                icon: Icons.my_location_rounded,
                onTap: () async {
                  // autoConfirm: false — this FAB just re-centers the map on
                  // the device's GPS position while mid pin-adjustment; it
                  // must land on Confirming, not confirm out from under the
                  // in-progress edit.
                  final cubit = context.read<LocationCubit>();
                  await cubit.useCurrentLocation(autoConfirm: false);
                  final state = cubit.state;
                  if (state is Confirming) _moveCamera(state.position);
                },
              ),
            ),

            // Bottom confirm sheet
            Align(
              alignment: Alignment.bottomCenter,
              child: _ConfirmSheet(
                isDragging: _isDragging,
                existingAddress: widget.existingAddress,
                ambientConfirm: widget.ambientConfirm,
                askToConfirmPin: widget.askToConfirmPin,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Top bar: rectangular search box with small rounded corners, and a
// matching square back button.
const double _searchBarHeight = 46;
const double _searchBarRadius = 8;

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  // Null = circle (map FABs); a value = rounded square (back button).
  final double? borderRadius;
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.size = 42,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: radius == null ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: radius == null ? null : BorderRadius.circular(radius),
          border: radius == null
              ? null
              : Border.all(color: const Color(0xFFE3E3E3)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, color: Colors.black87, size: 20),
      ),
    );
  }
}

class _ConfirmSheet extends StatelessWidget {
  final bool isDragging;
  final SavedAddressModel? existingAddress;
  final bool ambientConfirm;
  final bool askToConfirmPin;

  const _ConfirmSheet({
    required this.isDragging,
    this.existingAddress,
    required this.ambientConfirm,
    required this.askToConfirmPin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Color(0x1A000000), blurRadius: 16),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (ambientConfirm) ...[
            const Text(
              "Delivering to",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 4),
          ],
          if (askToConfirmPin) ...[
            const Text(
              "Is this your exact delivery location?",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87),
            ),
            const SizedBox(height: 2),
            const Text(
              "Move the pin to adjust",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 12),
          ],
          BlocBuilder<LocationCubit, LocationState>(
            builder: (context, state) {
              final isNotDeliverable = state is NotDeliverable;
              final address = isDragging
                  ? "Locating…"
                  : state is Confirming
                      ? state.formattedAddress
                      : state is NotDeliverable
                          ? state.formattedAddress
                          : state is CheckFailed
                              ? state.address.formattedAddress
                              : "…";
              return Row(
                children: [
                  Icon(
                    isNotDeliverable
                        ? Icons.location_off_rounded
                        : Icons.location_on_rounded,
                    color: isNotDeliverable
                        ? const Color(0xFFE53935)
                        : const Color(0xFF3DAA5C),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      address,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: Colors.black87),
                    ),
                  ),
                ],
              );
            },
          ),
          // Ambient mode replaces this drag-message + the confirm button
          // below with an inline "oops" action state instead (see the
          // bottom BlocBuilder) — this stays precise-mode only.
          BlocBuilder<LocationCubit, LocationState>(
            builder: (context, state) {
              if (state is! NotDeliverable || ambientConfirm) {
                return const SizedBox();
              }
              return const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "We don't deliver here yet. Drag the map to try a nearby spot.",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFFE53935)),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          BlocBuilder<LocationCubit, LocationState>(
            builder: (context, state) {
              // Ambient-only inline "oops" state: replaces the confirm
              // button entirely rather than just disabling it, since there's
              // a real way out of it here — re-check on current GPS, or
              // bail back to search. State-driven off this same builder (not
              // a separate listener/imperative branch), so re-tapping "Use
              // current location" and landing on NotDeliverable again just
              // re-renders this same branch with the new address — no extra
              // state-tracking needed.
              if (ambientConfirm && state is NotDeliverable) {
                final cubit = context.read<LocationCubit>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Oops, it's an unserviceable area",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE53935)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () =>
                            cubit.useCurrentLocation(autoConfirm: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3DAA5C),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Use current location",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          // ManualEntry is what makes the underlying
                          // LocationPickerSheet's builder fall through to
                          // _MainPickerView (the plain search sheet) rather
                          // than NotDeliverableView — the user is choosing
                          // to search fresh here, not being told no again.
                          cubit.pickDifferentLocation();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          "Select another location",
                          style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Ambient-only inline "couldn't check" state — mirrors the
              // NotDeliverable branch above but for when checkServiceability
              // itself couldn't complete (network/backend unreachable)
              // rather than authoritatively saying "not deliverable". Without
              // this, CheckFailed falls through to the generic button branch
              // below, whose canConfirm requires Confirming — leaving a
              // permanently disabled button and no explanation (see
              // CheckFailedScreen for the equivalent full-page treatment on
              // the bootstrap path).
              if (ambientConfirm && state is CheckFailed) {
                final cubit = context.read<LocationCubit>();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Couldn't check delivery availability",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFE53935)),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Check your connection and try again.",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF6B6B6B)),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => cubit.retryServiceabilityCheck(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3DAA5C),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Try again",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: () {
                          cubit.pickDifferentLocation();
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          "Select another location",
                          style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final isChecking = state is CheckingServiceability;
              final canConfirm = state is Confirming && !isDragging;
              final cubit = context.read<LocationCubit>();
              final editing = existingAddress;

              return SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: !canConfirm || isChecking
                      ? null
                      : () {
                          if (ambientConfirm) {
                            // No label/landmark collected in this mode, and
                            // it must never silently grow the user's real
                            // saved-address list — see
                            // LocationCubit.confirmAddress's
                            // persistAsSavedAddress doc.
                            cubit.confirmAddress(
                              position: state.position,
                              formattedAddress: state.formattedAddress,
                              label: AddressLabel.home,
                              persistAsSavedAddress: false,
                            );
                            return;
                          }

                          // Serviceability is no longer checked the instant
                          // the pin is confirmed — the wizard checks it at
                          // the very end (Step 3's Save). This screen's job
                          // now is just handing off position + area label to
                          // the wizard, seeded from existingAddress when
                          // editing.
                          final draft = AddressWizardDraft(
                            position: state.position,
                            areaLabel: state.formattedAddress,
                            addressLine: editing?.addressLine ?? '',
                            googleMapsLink: editing?.googleMapsLink,
                            imageLocalPath: editing?.imageLocalPath,
                            landmark: editing?.landmark,
                            label: editing?.label ?? AddressLabel.home,
                            customLabel: editing?.customLabel,
                            recipientName: editing?.recipientName ?? '',
                            recipientPhone: editing?.recipientPhone ?? '',
                            editing: editing,
                          );
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AddressDetailsScreen(draft: draft),
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3DAA5C),
                    disabledBackgroundColor: const Color(0xFFBDBDBD),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          ambientConfirm ? "Confirm Location" : "Continue",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
