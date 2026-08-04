import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../shared/models/checkout_address_model.dart';
import '../../../shared/models/saved_address_model.dart';
import '../../location/cubit/location_cubit.dart';
import '../../location/views/location_picker_sheet.dart';
import '../../location/views/map_pin_picker_screen.dart';
import '../../location/views/not_deliverable_view.dart';

class AddAddressScreen extends StatefulWidget {
  // Called once the user has picked/confirmed a serviceable address and
  // filled in recipient contact details for this order.
  final void Function(CheckoutAddressModel) onSave;

  const AddAddressScreen({super.key, required this.onSave});

  @override
  State<AddAddressScreen> createState() => _AddAddressScreenState();
}

class _AddAddressScreenState extends State<AddAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  late Future<List<SavedAddressModel>> _addressesFuture;
  SavedAddressModel? _selectedAddress;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<LocationCubit>();
    _addressesFuture = cubit.getSavedAddresses();
    // Default to whatever's already bound — that's what the cart/catalog
    // are already scoped to, so it's the sane default for checkout too.
    final state = cubit.state;
    if (state is Bound) _selectedAddress = state.address;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _reloadAddresses() {
    setState(() {
      _addressesFuture = context.read<LocationCubit>().getSavedAddresses();
    });
  }

  Future<void> _selectSavedAddress(SavedAddressModel address) async {
    if (address.id == context.read<LocationCubit>().boundAddressId) {
      setState(() => _selectedAddress = address);
      return;
    }
    setState(() => _isBusy = true);
    final cubit = context.read<LocationCubit>();
    await cubit.switchToSavedAddress(address);
    if (!mounted) return;
    setState(() => _isBusy = false);
    if (cubit.state is Bound) {
      setState(() => _selectedAddress = address);
    }
    // If NotDeliverable, the BlocBuilder body below shows that inline —
    // _selectedAddress deliberately stays unchanged.
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
            child: MapPinPickerScreen(
              initialPosition: state.position,
              initialFormattedAddress: state.formattedAddress,
            ),
          ),
        ),
      );
    } else {
      await LocationPickerSheet.show(context);
    }
    if (!mounted) return;
    _reloadAddresses();
    final bound = cubit.state;
    if (bound is Bound) setState(() => _selectedAddress = bound.address);
  }

  Future<void> _addNew() async {
    final cubit = context.read<LocationCubit>();
    await LocationPickerSheet.show(context);
    if (!mounted) return;
    _reloadAddresses();
    final state = cubit.state;
    if (state is Bound) setState(() => _selectedAddress = state.address);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select a delivery address to continue")),
      );
      return;
    }
    widget.onSave(CheckoutAddressModel(
      recipientName: _nameController.text.trim(),
      recipientPhone: _phoneController.text.trim(),
      address: _selectedAddress!,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Add Address",
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                color: Colors.black87)),
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: BlocBuilder<LocationCubit, LocationState>(
        builder: (context, locState) {
          return Stack(
            children: [
              Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  children: [
                    const Text("Contact details",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B6B6B))),
                    const SizedBox(height: 10),
                    _buildTextField("Full Name", _nameController),
                    const SizedBox(height: 12),
                    _buildTextField("Phone Number", _phoneController,
                        isNumber: true),

                    const SizedBox(height: 24),
                    const Text("Delivery address",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B6B6B))),
                    const SizedBox(height: 10),

                    if (locState is NotDeliverable)
                      const NotDeliverableView()
                    else ...[
                      _QuickActionCard(onTap: _useCurrentLocation),
                      const SizedBox(height: 12),
                      FutureBuilder<List<SavedAddressModel>>(
                        future: _addressesFuture,
                        builder: (context, snapshot) {
                          final addresses = snapshot.data ?? [];
                          if (!snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: Color(0xFF3DAA5C))),
                            );
                          }
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
                                .map((a) => Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: _SelectableAddressCard(
                                        address: a,
                                        isSelected: a.id == _selectedAddress?.id,
                                        onTap: () => _selectSavedAddress(a),
                                      ),
                                    ))
                                .toList(),
                          );
                        },
                      ),
                      const SizedBox(height: 4),
                      TextButton.icon(
                        onPressed: _addNew,
                        icon: const Icon(Icons.add_rounded,
                            color: Color(0xFF3DAA5C), size: 18),
                        label: const Text("Add new address",
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                color: Color(0xFF3DAA5C),
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
              if (locState is CheckingServiceability || _isBusy)
                Container(
                  color: Colors.black.withValues(alpha: 0.05),
                  child: const Center(
                      child: CircularProgressIndicator(color: Color(0xFF3DAA5C))),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
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
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3DAA5C),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Text(
                        "Save Address",
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
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontFamily: 'Poppins', color: Color(0xFF9E9E9E)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "This field is required";
        }
        return null;
      },
    );
  }
}

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
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.my_location_rounded,
                  color: Color(0xFF3DAA5C), size: 18),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "Use current location",
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B6B6B)),
          ],
        ),
      ),
    );
  }
}

class _SelectableAddressCard extends StatelessWidget {
  final SavedAddressModel address;
  final bool isSelected;
  final VoidCallback onTap;

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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isSelected ? const Color(0xFF3DAA5C) : const Color(0xFFE0E0E0),
              width: isSelected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(_icon,
                size: 20,
                color: isSelected ? const Color(0xFF3DAA5C) : const Color(0xFF6B6B6B)),
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
                  Text(address.formattedAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF6B6B6B))),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? const Color(0xFF3DAA5C) : const Color(0xFFE0E0E0),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
