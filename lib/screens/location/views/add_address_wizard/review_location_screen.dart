import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../shared/models/checkout_address_model.dart';
import '../../../../shared/models/saved_address_model.dart';
import '../../cubit/location_cubit.dart';
import '../not_deliverable_view.dart';
import 'address_wizard_draft.dart';

/// Step 3 (final) of the add-address wizard — a non-interactive map preview
/// + summary, and the actual persistence trigger.
class ReviewLocationScreen extends StatelessWidget {
  final AddressWizardDraft draft;
  const ReviewLocationScreen({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    return BlocListener<LocationCubit, LocationState>(
      // Same independently-popping pattern as MapPinPickerScreen and Step 1
      // — each buried screen popping itself off on this single Bound
      // emission is what cascades the whole wizard stack closed. Also where
      // the checkout entry point's onCheckoutSave actually fires, since
      // Bound.address is the real, persisted SavedAddressModel (with its
      // final id/createdAt), not the draft.
      listener: (context, state) {
        if (state is! Bound) return;
        final onCheckoutSave = draft.onCheckoutSave;
        if (onCheckoutSave != null) {
          // Checkout entry point: MapPinPickerScreen's and Step 1's own
          // Bound listeners deliberately stay out of this (see their
          // onCheckoutSave == null guards) so exactly these 4 explicit pops
          // — this screen, Step 1, MapPinPickerScreen, and the modal sheet
          // that launched it — run deterministically before onCheckoutSave
          // fires. onCheckoutSave's pushReplacement (cart_screen.dart)
          // replaces whatever is currently on top with CheckoutScreen; it
          // must land on AddAddressScreen, not race an unrelated bare pop
          // that would immediately undo it.
          final navigator = Navigator.of(context);
          navigator.pop();
          navigator.pop();
          navigator.pop();
          navigator.pop();
          onCheckoutSave(CheckoutAddressModel(
            recipientName: draft.recipientName,
            recipientPhone: draft.recipientPhone,
            address: state.address,
          ));
          return;
        }
        Navigator.of(context).pop();
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
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: draft.position,
                          initialZoom: 16,
                          interactionOptions:
                              const InteractionOptions(flags: InteractiveFlag.none),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.beeyo.customer',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: draft.position,
                              width: 44,
                              height: 56,
                              child: const Icon(Icons.location_pin,
                                  size: 44, color: Color(0xFF3DAA5C)),
                            ),
                          ]),
                        ],
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

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<LocationCubit>();
    final editing = draft.editing;
    // Editing a saved address that ISN'T the one currently bound should
    // just persist the change, not re-run serviceability or rebind it —
    // same distinction MapPinPickerScreen's _ConfirmSheet used to make.
    final isInactiveEdit = editing != null && editing.id != cubit.boundAddressId;

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
      draft.onCheckoutSave?.call(CheckoutAddressModel(
        recipientName: draft.recipientName,
        recipientPhone: draft.recipientPhone,
        address: updated,
      ));
      // No Bound emission happens for an inactive edit, so nothing else in
      // the wizard stack pops itself automatically — unwind all 3 screens
      // (this one, Step 1, MapPinPickerScreen) back to whatever pushed
      // MapPinPickerScreen (Address Book), same as the old single-screen
      // flow's direct pop did.
      final navigator = Navigator.of(context);
      navigator.pop();
      navigator.pop();
      navigator.pop();
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
