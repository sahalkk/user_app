import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../../../../shared/models/saved_address_model.dart';
import '../../cubit/location_cubit.dart';
import '../not_deliverable_view.dart';
import 'address_wizard_draft.dart';

/// Step 2 (final) of the add-address wizard — a non-interactive map preview
/// + summary, and the actual persistence trigger.
class ReviewLocationScreen extends StatelessWidget {
  final AddressWizardDraft draft;
  const ReviewLocationScreen({super.key, required this.draft});

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
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 180,
                    child: IgnorePointer(
                      // Lite mode: a static, lightweight map snapshot on
                      // Android — this preview is never interacted with.
                      child: gmaps.GoogleMap(
                        liteModeEnabled: true,
                        mapType: gmaps.MapType.hybrid,
                        initialCameraPosition: gmaps.CameraPosition(
                          target: gmaps.LatLng(draft.position.latitude,
                              draft.position.longitude),
                          zoom: 18,
                        ),
                        markers: {
                          gmaps.Marker(
                            markerId: const gmaps.MarkerId('pin'),
                            position: gmaps.LatLng(draft.position.latitude,
                                draft.position.longitude),
                          ),
                        },
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        myLocationButtonEnabled: false,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text("Address details",
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B6B6B))),
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
