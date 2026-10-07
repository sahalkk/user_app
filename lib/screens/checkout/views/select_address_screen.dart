import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/saved_address_model.dart';
import '../../location/cubit/location_cubit.dart';
import '../../location/views/map_pin_picker_screen.dart';
import '../../location/views/not_deliverable_view.dart';

/// Checkout's "Select delivery address" step. Picking a card binds it on
/// [LocationCubit] (the single source of truth for the delivery address);
/// this screen only decides when the user may continue.
class SelectAddressScreen extends StatefulWidget {
  const SelectAddressScreen({super.key});

  /// Resolves to true when the user continued with a bound, saved address
  /// that has recipient details — false if they backed out.
  static Future<bool> open(BuildContext context) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SelectAddressScreen()),
    );
    return result == true;
  }

  @override
  State<SelectAddressScreen> createState() => _SelectAddressScreenState();
}

class _SelectAddressScreenState extends State<SelectAddressScreen> {
  late Future<List<SavedAddressModel>> _addressesFuture;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _addressesFuture = context.read<LocationCubit>().getSavedAddresses();
  }

  void _reloadAddresses() {
    setState(() {
      _addressesFuture = context.read<LocationCubit>().getSavedAddresses();
    });
  }

  static bool _hasContact(SavedAddressModel a) =>
      a.recipientName.isNotEmpty && a.recipientPhone.isNotEmpty;

  Future<void> _select(SavedAddressModel address) async {
    final cubit = context.read<LocationCubit>();
    if (cubit.isBound(address)) return;
    setState(() => _isBusy = true);
    await cubit.switchToSavedAddress(address);
    if (mounted) setState(() => _isBusy = false);
    // Bound ticks the card; NotDeliverable shows inline above the list —
    // both straight off the cubit in build(), nothing to track here.
  }

  Future<void> _addNew() async {
    final saved = await MapPinPickerScreen.openForNewAddress(context);
    if (!mounted) return;
    // A freshly saved address is bound and already has recipient details
    // (the wizard requires them), so there's nothing left to pick here.
    if (saved) {
      Navigator.pop(context, true);
      return;
    }
    _reloadAddresses();
  }

  Future<void> _continue(SavedAddressModel address) async {
    if (_hasContact(address)) {
      Navigator.pop(context, true);
      return;
    }

    // Older saved addresses can lack a recipient — collect it through the
    // wizard's edit mode (pin + details prefilled) before letting the
    // order go out without anyone to hand it to.
    final saved = await MapPinPickerScreen.openForEdit(context, address);
    if (!mounted) return;
    _reloadAddresses();
    final state = context.read<LocationCubit>().state;
    if (saved && state is Bound && _hasContact(state.address)) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Select delivery address",
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                fontSize: 17,
                color: Colors.black87)),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: FutureBuilder<List<SavedAddressModel>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF3DAA5C)));
          }
          final addresses = snapshot.data!;

          return BlocBuilder<LocationCubit, LocationState>(
            builder: (context, locState) {
              // Only a bound SAVED address counts as selected — the ambient
              // "just checking this area" location bound at app start isn't
              // a deliverable address (no recipient, no flat number).
              SavedAddressModel? selected;
              if (locState is Bound) {
                for (final a in addresses) {
                  if (a.isSameAddressAs(locState.address)) {
                    selected = locState.address;
                  }
                }
              }
              final isChecking = locState is CheckingServiceability || _isBusy;

              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    children: [
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
                      const Text("Saved addresses",
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF6B6B6B))),
                      const SizedBox(height: 10),
                      if (addresses.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 10),
                          child: Text("No saved addresses yet",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: Color(0xFF9E9E9E))),
                        ),
                      ...addresses.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SelectableAddressCard(
                              address: a,
                              isSelected: selected != null &&
                                  a.isSameAddressAs(selected),
                              onTap: isChecking ? null : () => _select(a),
                            ),
                          )),
                      _AddNewAddressCard(onTap: isChecking ? null : _addNew),
                    ],
                  ),
                  if (isChecking)
                    Container(
                      color: Colors.black.withValues(alpha: 0.05),
                      child: const Center(
                          child: CircularProgressIndicator(
                              color: Color(0xFF3DAA5C))),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      padding: EdgeInsets.fromLTRB(20, 12, 20,
                          MediaQuery.of(context).padding.bottom + 12),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(color: Color(0x14000000), blurRadius: 12),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: selected == null || isChecking
                              ? null
                              : () => _continue(selected!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3DAA5C),
                            disabledBackgroundColor: const Color(0xFFBDBDBD),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: const Text(
                            "Continue",
                            style: TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _AddNewAddressCard extends StatelessWidget {
  final VoidCallback? onTap;
  const _AddNewAddressCard({required this.onTap});

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
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.add_rounded, color: Color(0xFF3DAA5C), size: 20),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Add new address",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF3DAA5C)),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Color(0xFF6B6B6B)),
          ],
        ),
      ),
    );
  }
}

class _SelectableAddressCard extends StatelessWidget {
  final SavedAddressModel address;
  final bool isSelected;
  final VoidCallback? onTap;

  const _SelectableAddressCard({
    required this.address,
    required this.isSelected,
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
    final hasContact =
        address.recipientName.isNotEmpty && address.recipientPhone.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected
                  ? const Color(0xFF3DAA5C)
                  : const Color(0xFFE0E0E0),
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(_icon,
                size: 20,
                color: isSelected
                    ? const Color(0xFF3DAA5C)
                    : const Color(0xFF6B6B6B)),
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
                  const SizedBox(height: 2),
                  Text(address.primaryAddressText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Color(0xFF6B6B6B))),
                  const SizedBox(height: 4),
                  // Missing contact is collected on Continue (see
                  // _SelectAddressScreenState._continue) — say so up front.
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
