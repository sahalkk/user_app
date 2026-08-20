import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart' hide AddressLabel;

import '../../../../blocs/auth_bloc/auth_bloc.dart';
import '../../../../blocs/auth_bloc/auth_state.dart';
import '../../../../shared/models/saved_address_model.dart';
import 'address_wizard_draft.dart';

/// Step 2 of the add-address wizard. Uses local controllers rather than
/// live-writing into [draft] — the shared draft is only touched when the
/// user taps "Save" below, so backing out via the plain app-bar back arrow
/// leaves Step 1's collapsed summary exactly as it was.
class ContactDetailsScreen extends StatefulWidget {
  final AddressWizardDraft draft;
  const ContactDetailsScreen({super.key, required this.draft});

  @override
  State<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends State<ContactDetailsScreen> {
  late bool _forSelf;
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _customLabelController;
  late AddressLabel _label;
  String? _error;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
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
    _nameController.dispose();
    _phoneController.dispose();
    _customLabelController.dispose();
    super.dispose();
  }

  // Guests can never reach this flow — cart and Address Book both require
  // login first — so this cast is always safe here.
  void _prefillFromAccount() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      _nameController.text = authState.name ?? '';
      _phoneController.text = authState.phone ?? '';
    }
  }

  void _setForSelf(bool value) {
    setState(() {
      _forSelf = value;
      if (value) {
        _prefillFromAccount();
      } else {
        _nameController.clear();
        _phoneController.clear();
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
      _phoneController.text = contact.phones.first.number;
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = "Enter a name and phone number");
      return;
    }
    final draft = widget.draft;
    draft.forSelf = _forSelf;
    draft.recipientName = name;
    draft.recipientPhone = phone;
    draft.label = _label;
    draft.customLabel = _customLabelController.text.trim();
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          "Contact details",
          style: TextStyle(
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: _ToggleButton(
                  label: "For me",
                  selected: _forSelf,
                  onTap: () => _setForSelf(true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ToggleButton(
                  label: "For someone else",
                  selected: !_forSelf,
                  onTap: () => _setForSelf(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const _FieldLabel("Recipient name"),
          const SizedBox(height: 6),
          _WizardTextField(controller: _nameController, hint: "Full name"),
          const SizedBox(height: 14),
          const _FieldLabel("Phone number"),
          const SizedBox(height: 6),
          _WizardTextField(
            controller: _phoneController,
            hint: "Phone number",
            keyboardType: TextInputType.phone,
            trailing: IconButton(
              icon: const Icon(Icons.contacts_rounded,
                  color: Color(0xFF3DAA5C)),
              onPressed: _pickContact,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Color(0xFFE53935))),
          ],
          const SizedBox(height: 24),
          const Text("Save address as",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B6B6B))),
          const SizedBox(height: 10),
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
            const SizedBox(height: 12),
            _WizardTextField(
              controller: _customLabelController,
              hint: "Label (e.g. Friend's place)",
            ),
          ],
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3DAA5C),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text("Save",
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF3DAA5C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected
                  ? const Color(0xFF3DAA5C)
                  : const Color(0xFFE0E0E0)),
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

class _WizardTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final Widget? trailing;

  const _WizardTextField({
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.trailing,
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
        keyboardType: keyboardType,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
              fontFamily: 'Poppins', fontSize: 13, color: Color(0xFF9E9E9E)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: trailing,
        ),
      ),
    );
  }
}
