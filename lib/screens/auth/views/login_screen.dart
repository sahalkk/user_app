import 'dart:async';
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
  final FocusNode _otpFocusNode = FocusNode();

  bool _isOtpSent = false;
  String _validationError = '';

  // Timer variables
  int _secondsRemaining = 29;
  Timer? _timer;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _secondsRemaining = 29);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F3D26), // Deep brand green
      body: BlocListener<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            Navigator.pop(context, true);
          } else if (state is AuthFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.redAccent,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            // Smooth transition between Phone and OTP steps
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: !_isOtpSent ? _buildPhoneStep() : _buildOtpStep(),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 1. PHONE INPUT STEP
  // ==========================================
  Widget _buildPhoneStep() {
    return Column(
      key: const ValueKey("PhoneStep"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text("Skip >",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 60),
        const Text("beeyo",
            style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -2.0)),
        const SizedBox(height: 16),
        const Text("Essentials\nat your Doorstep",
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1.1)),
        const SizedBox(height: 40),
        if (_validationError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_validationError,
                style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),
        Container(
          height: 56,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(28)),
          child: Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 20.0, right: 12.0),
                child: Text("+91",
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
              ),
              Container(width: 1, height: 24, color: Colors.grey.shade300),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: "Enter Phone Number",
                    hintStyle: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              final phoneDigits =
                  _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
              if (phoneDigits.length < 10) {
                setState(() => _validationError =
                    'Mobile number must be at least 10 digits');
                return;
              }
              setState(() {
                _validationError = '';
                _isOtpSent = true;
              });
              _startTimer();

              // 🔥 FIX: Wait 300ms for the AnimatedSwitcher to finish, THEN open keyboard
              Future.delayed(const Duration(milliseconds: 300), () {
                _otpFocusNode.requestFocus();
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              elevation: 0,
            ),
            child: const Text("Continue",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ),
        ),
        const Spacer(),
        Center(
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                  color: Colors.white70, fontSize: 12, height: 1.5),
              children: [
                const TextSpan(text: "By continuing, you agree to our\n"),
                TextSpan(
                    text: "Terms of Use",
                    style: TextStyle(
                        color: Colors.green.shade300,
                        fontWeight: FontWeight.bold)),
                const TextSpan(text: " & "),
                TextSpan(
                    text: "Privacy Policy",
                    style: TextStyle(
                        color: Colors.green.shade300,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // 2. OTP VERIFICATION STEP
  // ==========================================
  Widget _buildOtpStep() {
    return Column(
      key: const ValueKey("OtpStep"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Back Button
        GestureDetector(
          onTap: () {
            setState(() {
              _isOtpSent = false;
              _otpController.clear();
            });
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(height: 32),

        // Titles
        const Text("OTP\nVerification",
            style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.1)),
        const SizedBox(height: 16),
        RichText(
          text: TextSpan(
            style: const TextStyle(color: Colors.white70, fontSize: 15),
            children: [
              const TextSpan(text: "OTP has been sent to "),
              TextSpan(
                  text: "+91 ${_phoneController.text}",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
        const SizedBox(height: 40),

        if (_validationError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(_validationError,
                style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ),

        // --- CUSTOM PURE FLUTTER OTP INPUT ---
        SizedBox(
          height: 60,
          child: Stack(
            children: [
              // 1. The Visible Circles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  bool isFilled = index < _otpController.text.length;
                  String digit = isFilled ? _otpController.text[index] : "";
                  return Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isFilled
                          ? const Color(0xFF00E676)
                          : Colors.white.withOpacity(0.1),
                    ),
                    child: Center(
                      child: Text(
                        digit,
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  );
                }),
              ),

              // 2. The Invisible Text Field
              // 🔥 FIX: Added Positioned.fill so tapping ANYWHERE on the row focuses the keyboard
              Positioned.fill(
                child: TextField(
                  controller: _otpController,
                  focusNode: _otpFocusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  cursorColor: Colors.transparent,
                  // 🔥 FIX: Made font size normal again so it takes up space, but kept it invisible
                  style:
                      const TextStyle(color: Colors.transparent, fontSize: 24),
                  decoration: const InputDecoration(
                    counterText: "",
                    border: InputBorder.none,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // --- TIMER & RESEND ROW ---
        Text(
          "00:${_secondsRemaining.toString().padLeft(2, '0')}",
          style: const TextStyle(
              color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text("Didn't get it? ",
                style: TextStyle(color: Colors.white70, fontSize: 15)),
            const Icon(Icons.chat_bubble_outline,
                color: Colors.white70, size: 16),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _secondsRemaining == 0 ? () => _startTimer() : null,
              child: Text(
                "Send OTP (SMS)",
                style: TextStyle(
                  color: _secondsRemaining == 0 ? Colors.white : Colors.white38,
                  decoration: TextDecoration.underline,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        const Spacer(),

        // --- VERIFY BUTTON ---
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              final otpDigits =
                  _otpController.text.replaceAll(RegExp(r'[^0-9]'), '');
              if (otpDigits.length < 6) {
                setState(() => _validationError = 'OTP must be 6 digits');
                return;
              }
              setState(() => _validationError = '');

              // Trigger Bloc Login
              context.read<AuthBloc>().add(
                    LoginRequested(
                        phone: _phoneController.text, otp: _otpController.text),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              elevation: 0,
            ),
            child: BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is AuthLoading) {
                  return const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3));
                }
                return const Text("Verify & Login",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white));
              },
            ),
          ),
        ),
      ],
    );
  }
}
