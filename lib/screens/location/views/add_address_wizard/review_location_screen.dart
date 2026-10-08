import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:latlong2/latlong.dart';

import '../../../../data/repositories/location_repository.dart'
    show distanceMeters;
import '../../../../shared/models/saved_address_model.dart';
import '../../cubit/location_cubit.dart';
import '../not_deliverable_view.dart';
import 'address_wizard_draft.dart';

const _green = Color(0xFF3DAA5C);
const _grey = Color(0xFF6B6B6B);

/// Beyond this the area text from the map step ("NASC Mini Stadium, …")
/// probably no longer describes the pin — nudge the user back to re-pick
/// the area rather than silently saving a mismatched address.
const _farMoveMeters = 150.0;

gmaps.LatLng _toG(LatLng p) => gmaps.LatLng(p.latitude, p.longitude);

/// Step 2 (final) of the add-address wizard — a last pin check on a live
/// map, the summary, and the actual persistence trigger.
class ReviewLocationScreen extends StatefulWidget {
  final AddressWizardDraft draft;
  const ReviewLocationScreen({super.key, required this.draft});

  @override
  State<ReviewLocationScreen> createState() => _ReviewLocationScreenState();
}

class _ReviewLocationScreenState extends State<ReviewLocationScreen> {
  AddressWizardDraft get draft => widget.draft;

  // Where the pin was when this step opened — the reference for "moved".
  late final LatLng _origin = draft.position;
  gmaps.GoogleMapController? _mapController;
  bool _isDragging = false;
  gmaps.MapType _mapType = gmaps.MapType.hybrid;

  double get _movedMeters => distanceMeters(_origin, draft.position);

  void _onCameraMove(gmaps.CameraPosition position) {
    // Written straight into the draft, so going back to the details step
    // and returning keeps the adjustment.
    draft.position =
        LatLng(position.target.latitude, position.target.longitude);
  }

  void _resetPin() {
    _mapController?.animateCamera(gmaps.CameraUpdate.newLatLng(_toG(_origin)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, LocationState>(
      // The single Bound emission at the end of a save is what closes the
      // whole wizard (this screen, Step 1, and MapPinPickerScreen) in one
      // go — see [_closeWizard]. Only while this route is current: once the
      // wizard is closing, this screen stays mounted for its exit
      // animation, and a caller restoring its previous Bound in the
      // meantime (e.g. Address Book after an inactive edit) must not
      // trigger a second close.
      listener: (context, state) {
        final isCurrent = ModalRoute.of(context)?.isCurrent ?? false;
        if (state is Bound && isCurrent) _closeWizard(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F5F5),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: const Text(
            "Review & save",
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                fontSize: 17),
          ),
        ),
        body: BlocBuilder<LocationCubit, LocationState>(
          builder: (context, state) {
            if (state is NotDeliverable) {
              return const SingleChildScrollView(child: NotDeliverableView());
            }
            final isChecking = state is CheckingServiceability;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                _buildPinMap(),
                _buildMoveNote(),
                const SizedBox(height: 20),
                const Text("Address details",
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _grey)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(draft.addressLine,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87)),
                      const SizedBox(height: 4),
                      Text(draft.areaLabel,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF6B6B6B))),
                      const Divider(height: 20, color: Color(0xFFE0E0E0)),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded,
                              size: 16, color: Color(0xFF6B6B6B)),
                          const SizedBox(width: 8),
                          Text(draft.recipientName,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isChecking ? null : () => _save(context),
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
                        : const Text("Save Address",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Live map with a fixed centre pin — dragging the map moves the spot
  /// under the pin, same interaction as the first map step.
  Widget _buildPinMap() {
    final mapHeight = (MediaQuery.sizeOf(context).height * 0.42)
        .clamp(280.0, 400.0)
        .toDouble();
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: mapHeight,
        child: Stack(
          children: [
            gmaps.GoogleMap(
              initialCameraPosition:
                  gmaps.CameraPosition(target: _toG(draft.position), zoom: 19),
              mapType: _mapType,
              onMapCreated: (controller) => _mapController = controller,
              onCameraMoveStarted: () => setState(() => _isDragging = true),
              onCameraMove: _onCameraMove,
              onCameraIdle: () => setState(() => _isDragging = false),
              // Inside a ListView the map would otherwise lose vertical
              // drags to the list's scrolling.
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer()),
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
            ),

            // Fixed centre pin; lifts while the map is being dragged.
            IgnorePointer(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 150),
                      offset: Offset(0, _isDragging ? -0.25 : 0),
                      child: const Icon(Icons.location_pin,
                          size: 46, color: _green),
                    ),
                    // Shadow marking the exact point; the pin's tip sits
                    // on it at rest.
                    Container(
                      width: _isDragging ? 10 : 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Balances the pin above so its tip is the map centre.
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),

            // Hint
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: IgnorePointer(
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: _isDragging ? 0 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pan_tool_alt_rounded,
                              size: 14, color: Colors.white),
                          SizedBox(width: 6),
                          Text("Move the map to put the pin on your door",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Map controls
            Positioned(
              right: 10,
              bottom: 10,
              child: Column(
                children: [
                  if (_movedMeters > 2) ...[
                    _MapButton(
                      icon: Icons.undo_rounded,
                      tooltip: "Reset pin",
                      onTap: _resetPin,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _MapButton(
                    icon: _mapType == gmaps.MapType.hybrid
                        ? Icons.map_outlined
                        : Icons.satellite_alt_rounded,
                    tooltip: "Map type",
                    onTap: () => setState(() => _mapType =
                        _mapType == gmaps.MapType.hybrid
                            ? gmaps.MapType.normal
                            : gmaps.MapType.hybrid),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirms a small adjustment; warns when the pin has wandered far
  /// enough that the area text from the map step may no longer fit.
  Widget _buildMoveNote() {
    final moved = _movedMeters;
    if (_isDragging || moved <= 2) return const SizedBox(height: 0);
    final far = moved > _farMoveMeters;
    final color = far ? const Color(0xFFF57C00) : _green;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(far ? Icons.info_outline_rounded : Icons.check_circle_rounded,
              size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
                far
                    ? "Pin moved ${moved.round()} m. If this is a different area, go back and pick it on the map first."
                    : "Pin adjusted by ${moved.round()} m",
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  /// Unwinds back to the MapPinPickerScreen this wizard was launched from
  /// and pops it with `true`, so whoever pushed the map (checkout, Address
  /// Book, the picker sheet) learns the save succeeded from the awaited
  /// result rather than from a fixed number of pops.
  void _closeWizard(BuildContext context) {
    final navigator = Navigator.of(context);
    var reachedMap = false;
    navigator.popUntil((route) {
      reachedMap = route.settings.name == kAddressMapRouteName;
      // Never pop past the root, even if the map route is somehow missing.
      return reachedMap || route.isFirst;
    });
    if (reachedMap) navigator.pop(true);
  }

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<LocationCubit>();
    final editing = draft.editing;
    // Editing a saved address that ISN'T the one currently bound should
    // just persist the change, not re-run serviceability or rebind it —
    // same distinction MapPinPickerScreen's _ConfirmSheet used to make.
    final isInactiveEdit = editing != null && !cubit.isBound(editing);

    if (isInactiveEdit) {
      final updated = SavedAddressModel(
        id: editing.id,
        label: draft.label,
        customLabel: draft.customLabel,
        position: draft.position,
        formattedAddress: draft.areaLabel,
        addressLine: draft.addressLine,
        googleMapsLink: draft.googleMapsLink,
        imageLocalPath: draft.imageLocalPath,
        landmark: draft.landmark,
        pincode: editing.pincode,
        isDefault: editing.isDefault,
        createdAt: editing.createdAt,
        updatedAt: DateTime.now(),
        backendId: editing.backendId,
        recipientName: draft.recipientName,
        recipientPhone: draft.recipientPhone,
      );
      await cubit.editSavedAddress(updated);
      if (!context.mounted) return;
      // No Bound emission happens for an inactive edit, so the listener
      // above never fires — close the wizard directly instead.
      _closeWizard(context);
      return;
    }

    cubit.confirmAddress(
      position: draft.position,
      formattedAddress: draft.areaLabel,
      label: draft.label,
      customLabel: draft.customLabel,
      landmark: draft.landmark,
      addressLine: draft.addressLine,
      googleMapsLink: draft.googleMapsLink,
      imageLocalPath: draft.imageLocalPath,
      recipientName: draft.recipientName,
      recipientPhone: draft.recipientPhone,
      editing: editing,
    );
  }
}

class _MapButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _MapButton(
      {required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}