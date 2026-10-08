import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/saved_address_model.dart';
import '../../location/cubit/location_cubit.dart';
import '../../location/views/map_pin_picker_screen.dart';
import '../../location/views/not_deliverable_view.dart';

enum _AddressAction { deliverHere, edit, delete }

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late Future<List<SavedAddressModel>> _addressesFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _addressesFuture = context.read<LocationCubit>().getSavedAddresses();
    });
  }

  Future<void> _selectAddress(SavedAddressModel address) async {
    setState(() => _isBusy = true);
    final cubit = context.read<LocationCubit>();
    await cubit.switchToSavedAddress(address);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (cubit.state is Bound) {
      Navigator.of(context).pop();
    }
    // If it turned out NotDeliverable, the body below shows that inline —
    // no pop, so the user can immediately pick something else.
  }

  /// Straight into the add-address wizard (map → details → review), pin
  /// starting at the user's current delivery location. Stays on the Address
  /// Book afterwards so the new entry shows up in the list, marked as the
  /// one being delivered to.
  Future<void> _addNew() async {
    final saved = await MapPinPickerScreen.openForNewAddress(context);
    if (mounted && saved) _reload();
  }

  Future<void> _edit(SavedAddressModel address) async {
    final saved = await MapPinPickerScreen.openForEdit(context, address);
    if (mounted && saved) _reload();
  }

  Future<void> _delete(SavedAddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove this address?",
            style:
                TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800)),
        content: Text(
          "\"${address.displayLabel}\" will be removed from your saved addresses.",
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF6B6B6B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel",
                style: TextStyle(color: Color(0xFF6B6B6B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Remove",
                style: TextStyle(
                    color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    await context.read<LocationCubit>().deleteAddress(address);
    if (!mounted) return;
    setState(() => _isBusy = false);
    _reload();
  }

  /// A card tap only opens this sheet — switching the delivery address,
  /// editing or deleting each take a deliberate second tap, so a stray tap
  /// on the list can't silently change where orders go.
  Future<void> _openActions(SavedAddressModel address) async {
    final action = await showModalBottomSheet<_AddressAction>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AddressActionsSheet(
        address: address,
        isActive: context.read<LocationCubit>().isBound(address),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _AddressAction.deliverHere:
        await _selectAddress(address);
      case _AddressAction.edit:
        await _edit(address);
      case _AddressAction.delete:
        await _delete(address);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Address Book",
          style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: Colors.black87),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton.icon(
              onPressed: _addNew,
              icon: const Icon(Icons.add_rounded,
                  color: Color(0xFF3DAA5C), size: 18),
              label: const Text("Add New",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF3DAA5C),
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE8F5E9),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, locState) {
          return Stack(
            children: [
              FutureBuilder<List<SavedAddressModel>>(
                future: _addressesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: Color(0xFF3DAA5C)));
                  }
                  final addresses = snapshot.data!;
                  if (addresses.isEmpty) {
                    return _EmptyState(onAddPressed: _addNew);
                  }

                  final cubit = context.read<LocationCubit>();

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      // Shown above the list rather than instead of it, so
                      // an unserviceable address can still be switched
                      // away from, edited, or deleted right here.
                      if (locState is NotDeliverable) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const NotDeliverableView(),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const Text(
                        "Saved Addresses",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B6B6B)),
                      ),
                      const SizedBox(height: 10),
                      ...addresses.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _AddressCard(
                              address: a,
                              isActive: cubit.isBound(a),
                              onTap: () => _openActions(a),
                            ),
                          )),
                    ],
                  );
                },
              ),
              if (locState is CheckingServiceability || _isBusy)
                Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF3DAA5C))),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Icon, background and foreground colour for an address label.
(IconData, Color, Color) _labelStyle(AddressLabel label) {
  switch (label) {
    case AddressLabel.home:
      return (
        Icons.home_rounded,
        const Color(0xFFE8F5E9),
        const Color(0xFF3DAA5C)
      );
    case AddressLabel.work:
      return (
        Icons.work_rounded,
        const Color(0xFFE3F2FD),
        const Color(0xFF1E88E5)
      );
    case AddressLabel.other:
      return (
        Icons.place_rounded,
        const Color(0xFFF0F0F0),
        const Color(0xFF6B6B6B)
      );
  }
}

class _LabelAvatar extends StatelessWidget {
  final AddressLabel label;
  const _LabelAvatar(this.label);

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _labelStyle(label);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

// ── Saved address card ────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  final SavedAddressModel address;
  final bool isActive;
  final VoidCallback onTap;

  const _AddressCard({
    required this.address,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
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
            _LabelAvatar(address.label),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          address.displayLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black87),
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        _Badge(
                          label: "Delivering here",
                          bg: const Color(0xFFE8F5E9),
                          fg: const Color(0xFF3DAA5C),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    address.primaryAddressText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: Color(0xFF6B6B6B)),
                  ),
                  if (address.recipientName.isNotEmpty ||
                      address.recipientPhone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      "${address.recipientName} · ${address.recipientPhone}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11,
                          color: Color(0xFF9E9E9E)),
                    ),
                  ],
                ],
              ),
            ),
            // Hints that a tap opens options rather than acting directly.
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.more_vert_rounded,
                  size: 20, color: Color(0xFF9E9E9E)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg),
      ),
    );
  }
}

// ── Per-address options sheet ─────────────────────────────────────────
/// Pops with the chosen [_AddressAction], or null if dismissed.
class _AddressActionsSheet extends StatelessWidget {
  final SavedAddressModel address;
  final bool isActive;

  const _AddressActionsSheet({required this.address, required this.isActive});

  @override
  Widget build(BuildContext context) {
    void choose(_AddressAction action) => Navigator.pop(context, action);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _LabelAvatar(address.label),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(address.displayLabel,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.black87)),
                      Text(address.primaryAddressText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              color: Color(0xFF6B6B6B))),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFEEEEEE)),
            isActive
                ? const _SheetAction(
                    icon: Icons.check_circle_rounded,
                    label: "Currently delivering here",
                    color: Color(0xFF3DAA5C),
                  )
                : _SheetAction(
                    icon: Icons.local_shipping_outlined,
                    label: "Set as delivery address",
                    color: const Color(0xFF3DAA5C),
                    onTap: () => choose(_AddressAction.deliverHere),
                  ),
            _SheetAction(
              icon: Icons.edit_outlined,
              label: "Edit address",
              onTap: () => choose(_AddressAction.edit),
            ),
            _SheetAction(
              icon: Icons.delete_outline_rounded,
              label: "Delete address",
              color: const Color(0xFFE53935),
              onTap: () => choose(_AddressAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

/// One option row in [_AddressActionsSheet]; [onTap] null renders it as a
/// non-interactive status line.
class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    this.color = Colors.black87,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: Color(0xFFBDBDBD)),
          ],
        ),
      ),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onAddPressed;
  const _EmptyState({required this.onAddPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.location_on_outlined,
                  color: Color(0xFF3DAA5C), size: 38),
            ),
            const SizedBox(height: 20),
            const Text(
              "You haven't saved any addresses yet",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              "Save your home, work, or any other place for faster checkout next time.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onAddPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3DAA5C),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  "Add Address",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
