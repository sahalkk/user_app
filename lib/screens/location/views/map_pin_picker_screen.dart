import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../shared/models/saved_address_model.dart';
import '../cubit/location_cubit.dart';

typedef _SearchResult = ({String label, LatLng position});

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

  const MapPinPickerScreen({
    super.key,
    required this.initialPosition,
    this.existingAddress,
    this.initialFormattedAddress,
  });

  @override
  State<MapPinPickerScreen> createState() => _MapPinPickerScreenState();
}

class _MapPinPickerScreenState extends State<MapPinPickerScreen> {
  late final MapController _mapController;
  late AddressLabel _label;
  late final TextEditingController _customLabelController;
  late final TextEditingController _landmarkController;
  bool _isDragging = false;

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  List<_SearchResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    final existing = widget.existingAddress;
    _label = existing?.label ?? AddressLabel.home;
    _customLabelController =
        TextEditingController(text: existing?.customLabel ?? '');
    _landmarkController =
        TextEditingController(text: existing?.landmark ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cubit = context.read<LocationCubit>();
      if (existing != null) {
        // Avoid a re-geocode flicker showing different wording than what
        // was originally saved, until the user actually moves the pin.
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
    _customLabelController.dispose();
    _landmarkController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onMapEventFinished() {
    setState(() => _isDragging = false);
    context
        .read<LocationCubit>()
        .updatePinPosition(_mapController.camera.center);
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await context.read<LocationCubit>().searchAddress(query);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    });
  }

  void _selectSearchResult(_SearchResult result) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _searchResults = []);
    // The label is already known from the search result itself, so this
    // goes straight to Confirming — .move() below only re-centers the map
    // and is ignored by onMapEvent's mapController-source check, avoiding
    // a redundant second reverse-geocode call for the same point.
    context.read<LocationCubit>().selectSearchResult(result.label, result.position);
    _mapController.move(result.position, 16);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, LocationState>(
      // Closes this screen once a bind-worthy save completes (new address,
      // or editing the address that's currently active). Editing a saved
      // address that ISN'T active never emits Bound — it pops itself
      // directly from the confirm button instead (see _ConfirmSheet).
      listener: (context, state) {
        if (state is Bound) Navigator.of(context).pop();
      },
      child: Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialPosition,
              initialZoom: 16,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture && !_isDragging) {
                  setState(() => _isDragging = true);
                }
              },
              onMapEvent: (event) {
                // mapController-sourced moves (our own .move() calls from
                // the locate-me FAB and search result selection) already
                // know their address — re-geocoding them here would be a
                // redundant, back-to-back native geocoder call for the
                // exact position that was just resolved.
                if (event is MapEventMoveEnd &&
                    event.source != MapEventSource.mapController) {
                  _onMapEventFinished();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.beeyo.customer',
              ),
            ],
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

          // Top bar: back + search
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(21),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
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
                                    fontFamily: 'Poppins', fontSize: 14),
                                decoration: const InputDecoration(
                                  hintText: "Search for area, street...",
                                  hintStyle: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 14,
                                      color: Color(0xFF9E9E9E)),
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
                                    strokeWidth: 2,
                                    color: Color(0xFF3DAA5C)),
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
                    margin: const EdgeInsets.only(top: 8, left: 52),
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
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
                      separatorBuilder: (_, __) => const Divider(
                          height: 1, color: Color(0xFFE0E0E0)),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.location_on_outlined,
                              color: Color(0xFF3DAA5C), size: 20),
                          title: Text(
                            result.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87),
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),

          // Locate-me FAB
          Positioned(
            right: 16,
            bottom: 260,
            child: _RoundIconButton(
              icon: Icons.my_location_rounded,
              onTap: () async {
                final cubit = context.read<LocationCubit>();
                await cubit.useCurrentLocation();
                final state = cubit.state;
                if (state is Confirming) {
                  _mapController.move(state.position, 16);
                }
              },
            ),
          ),

          // Bottom confirm sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: _ConfirmSheet(
              isDragging: _isDragging,
              label: _label,
              onLabelChanged: (l) => setState(() => _label = l),
              customLabelController: _customLabelController,
              landmarkController: _landmarkController,
              existingAddress: widget.existingAddress,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
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
  final AddressLabel label;
  final ValueChanged<AddressLabel> onLabelChanged;
  final TextEditingController customLabelController;
  final TextEditingController landmarkController;
  final SavedAddressModel? existingAddress;

  const _ConfirmSheet({
    required this.isDragging,
    required this.label,
    required this.onLabelChanged,
    required this.customLabelController,
    required this.landmarkController,
    this.existingAddress,
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
          BlocBuilder<LocationCubit, LocationState>(
            builder: (context, state) {
              final isNotDeliverable = state is NotDeliverable;
              final address = isDragging
                  ? "Locating…"
                  : state is Confirming
                      ? state.formattedAddress
                      : state is NotDeliverable
                          ? state.formattedAddress
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
          BlocBuilder<LocationCubit, LocationState>(
            builder: (context, state) {
              if (state is! NotDeliverable) return const SizedBox();
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

          // Label chips
          Wrap(
            spacing: 8,
            children: AddressLabel.values.map((l) {
              final selected = l == label;
              return ChoiceChip(
                label: Text(l.display),
                selected: selected,
                onSelected: (_) => onLabelChanged(l),
                selectedColor: const Color(0xFF3DAA5C),
                backgroundColor: const Color(0xFFF0F0F0),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: selected
                          ? const Color(0xFF3DAA5C)
                          : const Color(0xFFE0E0E0)),
                ),
              );
            }).toList(),
          ),

          if (label == AddressLabel.other) ...[
            const SizedBox(height: 12),
            _InputField(
              controller: customLabelController,
              hint: "Label (e.g. Friend's place)",
            ),
          ],

          const SizedBox(height: 12),
          _InputField(
            controller: landmarkController,
            hint: "Landmark / floor / gate instructions (helps riders)",
            maxLines: 2,
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: BlocBuilder<LocationCubit, LocationState>(
              builder: (context, state) {
                final isChecking = state is CheckingServiceability;
                final canConfirm = state is Confirming && !isDragging;
                final cubit = context.read<LocationCubit>();
                final editing = existingAddress;
                // Editing a saved address that ISN'T the one currently
                // bound should just persist the change, not rebind it.
                final isInactiveEdit =
                    editing != null && editing.id != cubit.boundAddressId;

                return ElevatedButton(
                  onPressed: !canConfirm || isChecking
                      ? null
                      : () async {
                          if (isInactiveEdit) {
                            await cubit.editSavedAddress(editing.copyWith(
                              label: label,
                              customLabel: customLabelController.text.trim(),
                              position: state.position,
                              formattedAddress: state.formattedAddress,
                              landmark: landmarkController.text.trim(),
                            ));
                            if (context.mounted) Navigator.pop(context);
                            return;
                          }
                          cubit.confirmAddress(
                            position: state.position,
                            formattedAddress: state.formattedAddress,
                            label: label,
                            customLabel: customLabelController.text.trim(),
                            landmark: landmarkController.text.trim(),
                            editing: editing,
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
                          editing != null ? "Save Changes" : "Confirm & Save",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;

  const _InputField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9E9E9E)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}
