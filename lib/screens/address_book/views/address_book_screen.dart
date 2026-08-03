import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/saved_address_model.dart';
import '../../location/cubit/location_cubit.dart';
import '../../location/views/location_picker_sheet.dart';
import '../../location/views/map_pin_picker_screen.dart';
import '../../location/views/not_deliverable_view.dart';

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

  Future<void> _useCurrentLocation() async {
    final cubit = context.read<LocationCubit>();
    await cubit.useCurrentLocation();
    if (!mounted) return;

    final state = cubit.state;
    if (state is Confirming) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: cubit,
            child: MapPinPickerScreen(initialPosition: state.position),
          ),
        ),
      );
    } else {
      // Permission primer / manual-entry fallback needed — the full
      // picker sheet already knows how to handle every one of those
      // sub-states, no need to duplicate that UI here.
      await LocationPickerSheet.show(context);
    }
    if (!mounted) return;
    _reload();
    if (cubit.state is Bound) Navigator.of(context).pop();
  }

  Future<void> _addNew() async {
    await LocationPickerSheet.show(context);
    if (!mounted) return;
    _reload();
    if (context.read<LocationCubit>().state is Bound) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _edit(SavedAddressModel address) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<LocationCubit>(),
          child: MapPinPickerScreen(
            initialPosition: address.position,
            existingAddress: address,
          ),
        ),
      ),
    );
    if (!mounted) return;
    _reload();
  }

  Future<void> _delete(SavedAddressModel address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Remove this address?",
            style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w800)),
        content: Text(
          "\"${address.displayLabel}\" will be removed from your saved addresses.",
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF6B6B6B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Color(0xFF6B6B6B))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Remove", style: TextStyle(color: Color(0xFFE53935), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isBusy = true);
    await context.read<LocationCubit>().deleteAddress(address.id);
    if (!mounted) return;
    setState(() => _isBusy = false);
    _reload();
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
              icon: const Icon(Icons.add_rounded, color: Color(0xFF3DAA5C), size: 18),
              label: const Text("Add New",
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Color(0xFF3DAA5C),
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFE8F5E9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, locState) {
          if (locState is NotDeliverable) {
            return const SingleChildScrollView(child: NotDeliverableView());
          }

          return Stack(
            children: [
              FutureBuilder<List<SavedAddressModel>>(
                future: _addressesFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF3DAA5C)));
                  }
                  final addresses = snapshot.data!;
                  if (addresses.isEmpty) {
                    return _EmptyState(onAddPressed: _addNew);
                  }

                  final boundId = context.read<LocationCubit>().boundAddressId;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _QuickActionCard(onTap: _useCurrentLocation),
                      const SizedBox(height: 22),
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
                              isActive: a.id == boundId,
                              onTap: () => _selectAddress(a),
                              onEdit: () => _edit(a),
                              onDelete: () => _delete(a),
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
                      child: CircularProgressIndicator(color: Color(0xFF3DAA5C))),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Quick action: "Use current location" ─────────────────────────────
class _QuickActionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickActionCard({required this.onTap});

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
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.my_location_rounded, color: Color(0xFF3DAA5C), size: 20),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                "Use current location",
                style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B6B6B)),
          ],
        ),
      ),
    );
  }
}

// ── Saved address card ────────────────────────────────────────────────
class _AddressCard extends StatelessWidget {
  final SavedAddressModel address;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AddressCard({
    required this.address,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  (IconData, Color, Color) get _iconStyle {
    switch (address.label) {
      case AddressLabel.home:
        return (Icons.home_rounded, const Color(0xFFE8F5E9), const Color(0xFF3DAA5C));
      case AddressLabel.work:
        return (Icons.work_rounded, const Color(0xFFE3F2FD), const Color(0xFF1E88E5));
      case AddressLabel.other:
        return (Icons.place_rounded, const Color(0xFFF0F0F0), const Color(0xFF6B6B6B));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = _iconStyle;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, color: fg, size: 20),
            ),
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
                    address.formattedAddress,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF6B6B6B)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ActionIcon(icon: Icons.edit_outlined, onTap: onEdit),
                      const SizedBox(width: 4),
                      _ActionIcon(icon: Icons.delete_outline_rounded, onTap: onDelete, color: const Color(0xFFE53935)),
                    ],
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

class _Badge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Badge({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  const _ActionIcon({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 18, color: color ?? const Color(0xFF6B6B6B)),
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
              decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.location_on_outlined, color: Color(0xFF3DAA5C), size: 38),
            ),
            const SizedBox(height: 20),
            const Text(
              "You haven't saved any addresses yet",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              "Save your home, work, or any other place for faster checkout next time.",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF6B6B6B)),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onAddPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3DAA5C),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text(
                  "Add Address",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
