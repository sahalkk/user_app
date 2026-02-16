import 'package:app123/blocs/auth_bloc/auth_state.dart';
import 'package:app123/blocs/auth_bloc/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:app123/blocs/auth_bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isOtpSent = false;
  String _validationError = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context), // Close login screen
        ),
      ),
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            // LOGIN SUCCESS: Close screen and return "true"
            Navigator.pop(context, true);
          } else if (state is AuthFailure) {
            // Show error message if login failed
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Welcome to Beeyo",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isOtpSent
                    ? "Enter the code sent to your phone"
                    : "Enter your mobile number to login",
                style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
              ),
              const SizedBox(height: 32),

              // VALIDATION ERROR MESSAGE
              if (_validationError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _validationError,
                    style: const TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ),

              // PHONE INPUT
              if (!_isOtpSent)
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: "Mobile Number",
                    prefixText: "+91 ",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

              // OTP INPUT
              if (_isOtpSent)
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "OTP",
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),

              const Spacer(),

              // BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (!_isOtpSent) {
                      // 1. Validate phone number length (10+ digits)
                      final phoneDigits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
                      if (phoneDigits.length < 10) {
                        setState(() {
                          _validationError = 'Mobile number must be at least 10 digits';
                        });
                        return;
                      }
                      // Clear error and proceed to OTP
                      setState(() {
                        _validationError = '';
                        _isOtpSent = true; // Show OTP field
                      });
                    } else {
                      // 2. Validate OTP length (6+ digits)
                      final otpDigits = _otpController.text.replaceAll(RegExp(r'[^0-9]'), '');
                      if (otpDigits.length < 6) {
                        setState(() {
                          _validationError = 'OTP must be at least 6 digits';
                        });
                        return;
                      }
                      // Clear error and trigger Login
                      setState(() {
                        _validationError = '';
                      });
                      context.read<AuthBloc>().add(
                            LoginRequested(
                                phone: _phoneController.text,
                                otp: _otpController.text),
                          );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: BlocBuilder<AuthBloc, AuthState>(
                    builder: (context, state) {
                      if (state is AuthLoading) {
                        return const CircularProgressIndicator(
                            color: Colors.white);
                      }
                      return Text(
                        _isOtpSent ? "Verify & Login" : "Continue",
                        style:
                            const TextStyle(fontSize: 18, color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
