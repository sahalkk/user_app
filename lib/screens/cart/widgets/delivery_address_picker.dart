import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/saved_address_model.dart';
import '../../location/cubit/location_cubit.dart';
import '../../location/views/map_pin_picker_screen.dart';

/// Saved-address list + "Add new address" for choosing where an order goes.
/// Picking a row binds it on [LocationCubit] (the single source of truth for
/// the delivery address); this widget only reports, via [onResolved], when
/// a saved address with recipient details has been bound by the user.
///
/// Hosted inline by the cart's expandable footer.
class DeliveryAddressPicker extends StatefulWidget {
  final VoidCallback onResolved;

  /// Caps the list's height; it scrolls inside that once it has more rows.
  final double maxHeight;

  const DeliveryAddressPicker({
    super.key,
    required this.onResolved,
    required this.maxHeight,
  });

  static bool hasContact(SavedAddressModel a) =>
      a.recipientName.isNotEmpty && a.recipientPhone.isNotEmpty;

  /// The bound address, but only when it's one of [saved] — the ambient
  /// "just checking this area" location bound at app start isn't a
  /// deliverable address (no recipient, no flat number).
  static SavedAddressModel? boundSaved(
      LocationState state, List<SavedAddressModel> saved) {
    if (state is! Bound) return null;
    return saved.any((a) => a.isSameAddressAs(state.address))
        ? state.address
        : null;
  }

  /// Older saved addresses can lack a recipient — collects it through the
  /// wizard's edit mode (pin + details prefilled) so no order goes out
  /// without anyone to hand it to. True once the bound address has one.
  static Future<bool> completeContact(
      BuildContext context, SavedAddressModel address) async {
    final cubit = context.read<LocationCubit>();
    final saved = await MapPinPickerScreen.openForEdit(context, address);
    final state = cubit.state;
    return saved && state is Bound && hasContact(state.address);
  }

  @override
  State<DeliveryAddressPicker> createState() => _DeliveryAddressPickerState();
}

class _DeliveryAddressPickerState extends State<DeliveryAddressPicker> {
  late final LocationCubit _cubit;
  late final Bound? _priorBound;
  late Future<List<SavedAddressModel>> _addressesFuture;
  // Id of the row whose serviceability check is running — that row gets
  // the spinner, and every row is disabled until it lands.
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<LocationCubit>();
    final s = _cubit.state;
    _priorBound = s is Bound ? s : null;
    _addressesFuture = _cubit.getSavedAddresses();
  }

  @override
  void dispose() {
    // Picking an undeliverable address leaves the cubit on NotDeliverable;
    // closing the picker there must not drop the address that was bound
    // before (restorePreviousState never clobbers a fresh Bound).
    final prior = _priorBound;
    if (prior != null) _cubit.restorePreviousState(prior);
    super.dispose();
  }

  Future<void> _select(SavedAddressModel address) async {
    if (_cubit.isBound(address)) {
      await _resolveBound(address);
      return;
    }
    setState(() => _busyId = address.id);
    await _cubit.switchToSavedAddress(address);
    if (!mounted) return;
    setState(() => _busyId = null);
    // NotDeliverable shows inline above the list, straight off the cubit.
    final state = _cubit.state;
    if (state is Bound) await _resolveBound(state.address);
  }

  Future<void> _resolveBound(SavedAddressModel bound) async {
    if (DeliveryAddressPicker.hasContact(bound)) {
      widget.onResolved();
      return;
    }
    final completed =
        await DeliveryAddressPicker.completeContact(context, bound);
    if (!mounted) return;
    if (completed) {
      widget.onResolved();
    } else {
      _reload();
    }
  }

  Future<void> _addNew() async {
    // A freshly saved address is bound and already has recipient details
    // (the wizard requires them), so there's nothing left to pick.
    final saved = await MapPinPickerScreen.openForNewAddress(context);
    if (!mounted) return;
    if (saved) {
      widget.onResolved();
    } else {
      _reload();
    }
  }

  void _reload() =>
      setState(() => _addressesFuture = _cubit.getSavedAddresses());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<SavedAddressModel>>(
      future: _addressesFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(
                color: Color(0xFF3DAA5C), backgroundColor: Color(0xFFF0F0F0)),
          );
        }
        final addresses = snapshot.data!;

        return BlocBuilder<LocationCubit, LocationState>(
          builder: (context, locState) {
            final selected =
                DeliveryAddressPicker.boundSaved(locState, addresses);
            final locked =
                _busyId != null || locState is CheckingServiceability;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: widget.maxHeight),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  if (locState is NotDeliverable)
                    _NotDeliverableNotice(address: locState.formattedAddress),
                  ...addresses.map((a) => _AddressRow(
                        address: a,
                        isSelected:
                            selected != null && a.isSameAddressAs(selected),
                        isBusy: _busyId == a.id,
                        onTap: locked ? null : () => _select(a),
                      )),
                  _AddNewAddressRow(onTap: locked ? null : _addNew),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NotDeliverableNotice extends StatelessWidget {
  final String address;
  const _NotDeliverableNotice({required this.address});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off_rounded,
              size: 18, color: Color(0xFFE53935)),
          const SizedBox(width: 8),
          Expanded(
            child: Text("We don't deliver to $address yet",
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFFC62828))),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final SavedAddressModel address;
  final bool isSelected;
  final bool isBusy;
  final VoidCallback? onTap;

  const _AddressRow({
    required this.address,
    required this.isSelected,
    required this.isBusy,
    required this.onTap,
  });

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
    final hasContact = DeliveryAddressPicker.hasContact(address);
    final accent =
        isSelected ? const Color(0xFF3DAA5C) : const Color(0xFF6B6B6B);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F8F3) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF3DAA5C)
                  : const Color(0xFFE0E0E0),
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(_icon, size: 20, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(address.displayLabel,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  Text(address.primaryAddressText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF6B6B6B))),
                  // A missing recipient is collected right after picking
                  // (see DeliveryAddressPicker.completeContact) — say so.
                  Text(
                      hasContact
                          ? "${address.recipientName} · ${address.recipientPhone}"
                          : "Recipient details needed",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: hasContact
                              ? const Color(0xFF9E9E9E)
                              : const Color(0xFFF57C00))),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isBusy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Color(0xFF3DAA5C)),
              )
            else
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                color: isSelected
                    ? const Color(0xFF3DAA5C)
                    : const Color(0xFFE0E0E0),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

class _AddNewAddressRow extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddNewAddressRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_rounded, color: Color(0xFF3DAA5C), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text("Add new address",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3DAA5C))),
            ),
            Icon(Icons.chevron_right_rounded, color: Color(0xFF6B6B6B)),
          ],
        ),
      ),
    );
  }
}
