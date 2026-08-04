import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/auth_bloc/auth_bloc.dart';
import '../../../blocs/auth_bloc/auth_event.dart';
import '../../../data/repositories/auth_repository.dart';

/// Shown once, right after a brand-new account's first login (no name on
/// the backend yet) — also reusable later as an "edit name" screen from
/// Profile, since it just saves whatever's typed and pops.
class SetNameScreen extends StatefulWidget {
  final String? initialName;

  const SetNameScreen({super.key, this.initialName});

  @override
  State<SetNameScreen> createState() => _SetNameScreenState();
}

class _SetNameScreenState extends State<SetNameScreen> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.initialName ?? '');
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = "Please enter a name");
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await context.read<AuthRepository>().updateUserName(name);
      if (!mounted) return;
      // Refreshes AuthBloc's cached name/phone from the repository so
      // Profile (and anywhere else reading AuthState) picks it up.
      context.read<AuthBloc>().add(AppStarted());
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = "Couldn't save your name. Please try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                "What should we\ncall you?",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "This is how we'll greet you in the app.",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: TextField(
                  controller: _nameController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: "Your name",
                    hintStyle: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _save(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3DAA5C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text(
                          "Continue",
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white),
                        ),
                ),
              ),
              if (widget.initialName == null) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context, false),
                    child: Text(
                      "Skip for now",
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
