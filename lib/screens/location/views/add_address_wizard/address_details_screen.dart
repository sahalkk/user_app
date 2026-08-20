import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/models/saved_address_model.dart';
import '../../cubit/location_cubit.dart';
import 'address_wizard_draft.dart';
import 'contact_details_screen.dart';
import 'review_location_screen.dart';

/// Step 1 of the add-address wizard. Pushed on top of MapPinPickerScreen
/// (never replacing it) — "Change" just pops back to reveal the still-fully
/// -interactive map screen underneath, no special signaling needed.
class AddressDetailsScreen extends StatefulWidget {
  final AddressWizardDraft draft;
  const AddressDetailsScreen({super.key, required this.draft});

  @override
  State<AddressDetailsScreen> createState() => _AddressDetailsScreenState();
}

class _AddressDetailsScreenState extends State<AddressDetailsScreen> {
  late final TextEditingController _addressController;
  late final TextEditingController _mapsLinkController;
  late final TextEditingController _landmarkController;
  String? _addressError;
  String? _contactError;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _addressController = TextEditingController(text: draft.addressLine);
    _mapsLinkController = TextEditingController(text: draft.googleMapsLink ?? '');
    _landmarkController = TextEditingController(text: draft.landmark ?? '');
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapsLinkController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => widget.draft.imageLocalPath = file.path);
  }

  Future<void> _openContactDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactDetailsScreen(draft: widget.draft),
      ),
    );
    if (!mounted) return;
    setState(() => _contactError = null);
  }

  void _onNext() {
    final draft = widget.draft;
    final address = _addressController.text.trim();
    draft.addressLine = address;

    if (address.isEmpty) {
      setState(() => _addressError = "Enter your full address");
      return;
    }
    setState(() => _addressError = null);

    if (draft.recipientName.isEmpty || draft.recipientPhone.isEmpty) {
      setState(() => _contactError = "Add contact details to continue");
      _openContactDetails();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ReviewLocationScreen(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    return BlocListener<LocationCubit, LocationState>(
      // Same pattern MapPinPickerScreen uses — each screen in the wizard
      // stack independently pops itself on Bound, so the single Bound
      // emission at the end unwinds the whole stack back to the caller.
      //
      // onCheckoutSave == null guard: see the matching guard in
      // MapPinPickerScreen — the checkout entry point's ReviewLocationScreen
      // listener handles popping this screen itself, deterministically,
      // before calling onCheckoutSave.
      listener: (context, state) {
        if (state is Bound && draft.onCheckoutSave == null) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: const Color(0xFFF5F5F5),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black87),
          title: const Text(
            "Address details",
            style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                fontSize: 17),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    draft.areaLabel,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Change",
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Color(0xFF3DAA5C),
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _FieldLabel("Enter full address *"),
            const SizedBox(height: 6),
            _WizardField(
              controller: _addressController,
              hint: "House/flat no., building, street, area",
              maxLines: 3,
              onChanged: (_) => setState(() => _addressError = null),
            ),
            if (_addressError != null) ...[
              const SizedBox(height: 6),
              Text(_addressError!,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFFE53935))),
            ],
            const SizedBox(height: 14),
            const _FieldLabel("Google maps link (optional)"),
            const SizedBox(height: 6),
            _WizardField(
              controller: _mapsLinkController,
              hint: "Paste a Google maps link",
              onChanged: (v) => draft.googleMapsLink = v.trim().isEmpty ? null : v.trim(),
            ),
            const SizedBox(height: 14),
            const _FieldLabel("Landmark (optional)"),
            const SizedBox(height: 6),
            _WizardField(
              controller: _landmarkController,
              hint: "Nearby landmark, floor, gate instructions",
              onChanged: (v) => draft.landmark = v.trim().isEmpty ? null : v.trim(),
            ),
            const SizedBox(height: 14),
            const _FieldLabel("Location image (optional)"),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickImage,
              child: draft.imageLocalPath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(draft.imageLocalPath!),
                        height: 140,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Container(
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: Color(0xFF6B6B6B)),
                            SizedBox(height: 4),
                            Text("Add a photo",
                                style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    color: Color(0xFF6B6B6B))),
                          ],
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _openContactDetails,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _contactError != null
                          ? const Color(0xFFE53935)
                          : const Color(0xFFE0E0E0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        color: Color(0xFF3DAA5C)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Contact Details",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87)),
                          const SizedBox(height: 2),
                          if (draft.recipientName.isEmpty)
                            Text(
                              _contactError ?? "Add recipient name & phone",
                              style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: _contactError != null
                                      ? const Color(0xFFE53935)
                                      : const Color(0xFF9E9E9E)),
                            )
                          else
                            Row(
                              children: [
                                Flexible(
                                  child: Text(draft.recipientName,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 12,
                                          color: Color(0xFF6B6B6B))),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F5E9),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(draft.displayLabel,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF3DAA5C))),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: Color(0xFF6B6B6B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3DAA5C),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: const Text("Next",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on AddressWizardDraft {
  String get displayLabel =>
      label.name == 'other' && (customLabel?.isNotEmpty ?? false)
          ? customLabel!
          : label.display;
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6B6B6B)));
  }
}

class _WizardField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final ValueChanged<String>? onChanged;

  const _WizardField({
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        onChanged: onChanged,
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
