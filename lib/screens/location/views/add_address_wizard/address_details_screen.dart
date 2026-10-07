import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide AddressLabel;
import 'package:image_picker/image_picker.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../shared/models/saved_address_model.dart';
import 'address_wizard_draft.dart';
import 'review_location_screen.dart';

/// Step 1 (of 2) of the add-address wizard. Pushed on top of
/// MapPinPickerScreen (never replacing it) — "Change" just pops back to
/// reveal the still-fully-interactive map screen underneath, no special
/// signaling needed. Closing the wizard after a save is handled entirely by
/// ReviewLocationScreen. Contact details + the Home/Work/Other label — Step 2
/// until it was folded in here — are an inline expandable section rather
/// than a separate screen, so the whole address can be filled in one pass.
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

  late bool _forSelf;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _customLabelController;
  late AddressLabel _label;
  String? _contactError;
  // Expanded by default: when contact info is already prefilled from the
  // account, a collapsed card would let the user tap "Next" straight
  // through without ever noticing the "For someone else" option exists.
  bool _contactExpanded = true;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _addressController = TextEditingController(text: draft.addressLine);
    _mapsLinkController =
        TextEditingController(text: draft.googleMapsLink ?? '');
    _landmarkController = TextEditingController(text: draft.landmark ?? '');

    _forSelf = draft.forSelf;
    _label = draft.label;
    _customLabelController =
        TextEditingController(text: draft.customLabel ?? '');
    _nameController = TextEditingController(text: draft.recipientName);
    _phoneController = TextEditingController(text: draft.recipientPhone);

    if (_forSelf &&
        draft.recipientName.isEmpty &&
        draft.recipientPhone.isEmpty) {
      _prefillFromAccount();
    }
  }

  @override
  void dispose() {
    _addressController.dispose();
    _mapsLinkController.dispose();
    _landmarkController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _customLabelController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => widget.draft.imageLocalPath = file.path);
  }

  // Guests can never reach this flow — cart and Address Book both require
  // login first. Read from AuthRepository rather than AuthBloc's state:
  // the name is stored there as soon as it's set, even when the bloc's
  // AuthAuthenticated was emitted before it existed (e.g. a new account).
  Future<void> _prefillFromAccount() async {
    final authRepository = context.read<AuthRepository>();
    final name = await authRepository.fetchUserName();
    final phone = await authRepository.getUserPhone();
    // Bail if the user toggled "For someone else" (or started typing)
    // while this was loading — don't overwrite what they've entered.
    if (!mounted || !_forSelf) return;
    setState(() {
      if (_nameController.text.isEmpty) _nameController.text = name ?? '';
      if (_phoneController.text.isEmpty) _phoneController.text = phone ?? '';
    });
  }

  void _setForSelf(bool value) {
    setState(() {
      _forSelf = value;
      if (value) {
        _prefillFromAccount();
        _label = AddressLabel.home;
      } else {
        _nameController.clear();
        _phoneController.clear();
        // No Home/Work/Other chips for someone else's address — it's saved
        // under whatever free-text name is typed below instead.
        _label = AddressLabel.other;
      }
    });
  }

  Future<void> _pickContact() async {
    final status =
        await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted &&
        status != PermissionStatus.limited) {
      return;
    }
    final contact = await FlutterContacts.native
        .showPicker(properties: {ContactProperty.phone});
    if (contact == null || !mounted) return;
    if (contact.phones.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That contact has no phone number")),
      );
      return;
    }
    setState(() {
      if ((contact.displayName ?? '').isNotEmpty) {
        _nameController.text = contact.displayName!;
      }
      // Contact numbers can carry a country code, spaces, or dashes (e.g.
      // "+91 98765 43210") — the field itself only accepts 10 bare digits,
      // so strip everything else and keep just the local number.
      final digits =
          contact.phones.first.number.replaceAll(RegExp(r'[^0-9]'), '');
      _phoneController.text =
          digits.length > 10 ? digits.substring(digits.length - 10) : digits;
    });
  }

  String get _contactLabel => _label == AddressLabel.other &&
          _customLabelController.text.trim().isNotEmpty
      ? _customLabelController.text.trim()
      : _label.display;

  void _onNext() {
    final draft = widget.draft;
    final address = _addressController.text.trim();
    draft.addressLine = address;

    if (address.isEmpty) {
      setState(() => _addressError = "Enter your full address");
      return;
    }
    setState(() => _addressError = null);

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() {
        _contactError = "Add recipient name & phone to continue";
        _contactExpanded = true;
      });
      return;
    }
    setState(() => _contactError = null);

    draft.forSelf = _forSelf;
    draft.recipientName = name;
    draft.recipientPhone = phone;
    draft.label = _label;
    draft.customLabel = _customLabelController.text.trim();

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
    return Scaffold(
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
            onChanged: (v) =>
                draft.googleMapsLink = v.trim().isEmpty ? null : v.trim(),
          ),
          const SizedBox(height: 14),
          const _FieldLabel("Landmark (optional)"),
          const SizedBox(height: 6),
          _WizardField(
            controller: _landmarkController,
            hint: "Nearby landmark, floor, gate instructions",
            onChanged: (v) =>
                draft.landmark = v.trim().isEmpty ? null : v.trim(),
          ),
          const SizedBox(height: 14),
          const _FieldLabel("Location image (optional)"),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: _pickImage,
            child: draft.imageLocalPath != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    // image_picker returns a blob: URL on web (no real
                    // filesystem path, and dart:io's File isn't usable
                    // there anyway) — Image.network reads that URL
                    // directly, where Image.file would just throw.
                    child: kIsWeb
                        ? Image.network(
                            draft.imageLocalPath!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: _contactError != null
                      ? const Color(0xFFE53935)
                      : const Color(0xFFE0E0E0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _contactExpanded = !_contactExpanded),
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
                            // Collapsed-only preview — once expanded the
                            // fields below already show this, so skip the
                            // redundant line to save vertical space.
                            if (!_contactExpanded) ...[
                              const SizedBox(height: 2),
                              if (_nameController.text.trim().isEmpty)
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
                                      child: Text(_nameController.text.trim(),
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
                                      child: Text(_contactLabel,
                                          style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFF3DAA5C))),
                                    ),
                                  ],
                                ),
                            ],
                          ],
                        ),
                      ),
                      Icon(
                        _contactExpanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: const Color(0xFF6B6B6B),
                      ),
                    ],
                  ),
                ),
                if (_contactExpanded) ...[
                  const Divider(height: 16, color: Color(0xFFE0E0E0)),
                  Row(
                    children: [
                      Expanded(
                        child: _ToggleButton(
                          label: "For me",
                          selected: _forSelf,
                          onTap: () => _setForSelf(true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _ToggleButton(
                          label: "For someone else",
                          selected: !_forSelf,
                          onTap: () => _setForSelf(false),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _WizardField(
                          controller: _nameController,
                          label: "Name",
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _WizardField(
                          controller: _phoneController,
                          label: "Phone",
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          prefixText: "+91 ",
                          // Picking from contacts only makes sense when
                          // filling in someone else's number — "For me"
                          // is already the account's own number.
                          // flutter_contacts has no web implementation
                          // at all, so the picker is hidden there too.
                          trailing: (_forSelf || kIsWeb)
                              ? null
                              : IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: const Icon(Icons.contacts_rounded,
                                      size: 18, color: Color(0xFF3DAA5C)),
                                  onPressed: _pickContact,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_forSelf) ...[
                    const Text("Save address as",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B6B6B))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: AddressLabel.values.map((l) {
                        final selected = l == _label;
                        return ChoiceChip(
                          label: Text(l.display),
                          selected: selected,
                          onSelected: (_) => setState(() => _label = l),
                          selectedColor: const Color(0xFF3DAA5C),
                          backgroundColor: Colors.white,
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
                    if (_label == AddressLabel.other) ...[
                      const SizedBox(height: 10),
                      _WizardField(
                        controller: _customLabelController,
                        hint: "Label (e.g. Friend's place)",
                      ),
                    ],
                  ] else ...[
                    const Text("Save address as (optional)",
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B6B6B))),
                    const SizedBox(height: 6),
                    _WizardField(
                      controller: _customLabelController,
                      hint: "e.g. Mom's place, Office reception",
                    ),
                  ],
                ],
              ],
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
    );
  }
}

class _ToggleButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3DAA5C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  selected ? const Color(0xFF3DAA5C) : const Color(0xFFE0E0E0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
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
  // Either a plain placeholder (hint, paired with a _FieldLabel above) or a
  // compact floating label (label) that doubles as its own placeholder —
  // the latter skips the separate label row, used where vertical space is
  // tight (e.g. the Contact Details section).
  final String? hint;
  final String? label;
  final int maxLines;
  final TextInputType? keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;

  const _WizardField({
    required this.controller,
    this.hint,
    this.label,
    this.maxLines = 1,
    this.keyboardType,
    this.maxLength,
    this.inputFormatters,
    this.prefixText,
    this.trailing,
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
        keyboardType: keyboardType,
        maxLength: maxLength,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9E9E9E)),
          labelText: label,
          labelStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9E9E9E)),
          floatingLabelStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 12, color: Color(0xFF3DAA5C)),
          floatingLabelBehavior:
              prefixText != null ? FloatingLabelBehavior.always : null,
          prefixText: prefixText,
          prefixStyle: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87),
          border: InputBorder.none,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          counterText: maxLength != null ? '' : null,
          suffixIcon: trailing,
        ),
      ),
    );
  }
}
