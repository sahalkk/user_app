import 'dart:async';
import 'package:beeyo_customer/blocs/auth_bloc/auth_state.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_event.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:beeyo_customer/blocs/auth_bloc/auth_bloc.dart';

import 'set_name_screen.dart';

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

  void _startTimer(int seconds) {
    setState(() => _secondsRemaining = seconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _phoneDigits =>
      _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

  // Send-OTP or verify request in flight — every button on the screen is
  // disabled until it settles.
  bool _isBusy(AuthState state) => state is OtpSending || state is AuthLoading;

  // "Change number": back to the phone step with a clean slate.
  void _resetToPhoneStep() {
    _timer?.cancel();
    setState(() {
      _isOtpSent = false;
      _validationError = '';
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Dark green background — white status bar icons here, overriding the
    // app-wide dark-icon default set in MaterialApp.builder.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F3D26), // Deep brand green
        body: BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              if (state.isNewUser) {
                // Replaces LoginScreen in the stack — when SetNameScreen pops,
                // it lands back on whoever originally pushed LoginScreen.
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const SetNameScreen()),
                );
              } else {
                Navigator.pop(context, true);
              }
            } else if (state is OtpSent) {
              // A new code invalidates the previous one, so start each
              // (re)send with an empty input.
              final wasOnPhoneStep = !_isOtpSent;
              setState(() {
                _validationError = '';
                _isOtpSent = true;
                _otpController.clear();
              });
              _startTimer(state.retryAfterSeconds);

              // 🔥 FIX: Wait 300ms for the AnimatedSwitcher to finish, THEN open keyboard
              Future.delayed(Duration(milliseconds: wasOnPhoneStep ? 300 : 0),
                  () {
                if (mounted) _otpFocusNode.requestFocus();
              });
            } else if (state is OtpFailure) {
              setState(() => _validationError = state.message);
              // Rate-limited resend — count down to when the backend will
              // actually accept the next request.
              if (_isOtpSent && state.retryAfterSeconds != null) {
                _startTimer(state.retryAfterSeconds!);
              }
            } else if (state is AuthFailure) {
              setState(() {
                _validationError = state.message;
                _otpController.clear();
              });
              _otpFocusNode.requestFocus();
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
      ),
    );
  }

  // ==========================================
  // 1. PHONE INPUT STEP
  // ==========================================
  Widget _buildPhoneStep() {
    final authState = context.watch<AuthBloc>().state;
    final isBusy = _isBusy(authState);

    return Column(
      key: const ValueKey("PhoneStep"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.topRight,
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
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
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  decoration: const InputDecoration(
                    hintText: "Enter Phone Number",
                    hintStyle: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                    counterText: '',
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
            onPressed: isBusy
                ? null
                : () {
                    if (_phoneDigits.length < 10) {
                      setState(() => _validationError =
                          'Mobile number must be at least 10 digits');
                      return;
                    }
                    setState(() => _validationError = '');

                    // Moves to the OTP step only once the backend confirms
                    // the code was sent (see OtpSent in the listener).
                    context
                        .read<AuthBloc>()
                        .add(OtpRequested(phone: _phoneDigits));
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              disabledBackgroundColor: const Color(0xFF00E676),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              elevation: 0,
            ),
            child: authState is OtpSending
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : const Text("Continue",
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
    final authState = context.watch<AuthBloc>().state;
    final isBusy = _isBusy(authState);
    final canResend = _secondsRemaining == 0 && !isBusy;

    return Column(
      key: const ValueKey("OtpStep"),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Back Button
        GestureDetector(
          onTap: isBusy ? null : _resetToPhoneStep,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle),
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
                          : Colors.white.withValues(alpha: 0.1),
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
          // Cooldowns from a rate limit can run past a minute.
          "${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:"
          "${(_secondsRemaining % 60).toString().padLeft(2, '0')}",
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
              onTap: canResend
                  ? () {
                      setState(() => _validationError = '');
                      context
                          .read<AuthBloc>()
                          .add(OtpRequested(phone: _phoneDigits));
                    }
                  : null,
              child: Text(
                authState is OtpSending ? "Sending..." : "Send OTP (SMS)",
                style: TextStyle(
                  color: canResend ? Colors.white : Colors.white38,
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
            onPressed: isBusy
                ? null
                : () {
                    final otpDigits =
                        _otpController.text.replaceAll(RegExp(r'[^0-9]'), '');
                    if (otpDigits.length < 6) {
                      setState(() => _validationError = 'OTP must be 6 digits');
                      return;
                    }
                    setState(() => _validationError = '');

                    // Trigger Bloc Login
                    context.read<AuthBloc>().add(
                          LoginRequested(phone: _phoneDigits, otp: otpDigits),
                        );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              disabledBackgroundColor: const Color(0xFF00E676),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
              elevation: 0,
            ),
            child: authState is AuthLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 3))
                : const Text("Verify & Login",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
          ),
        ),
      ],
    );
  }
}
