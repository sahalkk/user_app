import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

// Initial state before we check anything
class AuthInitial extends AuthState {}

// Showing a spinner while logging in
class AuthLoading extends AuthState {}

// User is logged in (We have a token!)
class AuthAuthenticated extends AuthState {
  final String token;
  final String? phone;
  final String? name;
  // True only for the login that just happened for a brand-new account —
  // used to route straight to the "what should we call you?" prompt.
  // Always false for sessions restored on app start.
  final bool isNewUser;

  const AuthAuthenticated(
    this.token, {
    this.phone,
    this.name,
    this.isNewUser = false,
  });

  @override
  List<Object?> get props => [token, phone, name, isNewUser];
}

// User is guest or logout complete
class AuthUnauthenticated extends AuthState {}

// Session was force-cleared after a 401 from the backend (expired/invalid
// token), as opposed to the user tapping "Log out" themselves. Still an
// AuthUnauthenticated, so every existing `is AuthAuthenticated ? ... : ...`
// guest-view check keeps working unchanged — this only adds a signal that
// app_view.dart's BlocListener can key off of to route back to LoginScreen.
class SessionExpired extends AuthUnauthenticated {}

// --- OTP request lifecycle ---
// The user is still logged out while requesting a code, so these extend
// AuthUnauthenticated (same reasoning as SessionExpired) and every
// guest-view check keeps working while the login screen is open.

// Waiting on POST /auth/send-otp.
class OtpSending extends AuthUnauthenticated {}

// The code is on its way — the resend countdown should start from
// [retryAfterSeconds].
class OtpSent extends AuthUnauthenticated {
  final int retryAfterSeconds;
  OtpSent(this.retryAfterSeconds);
  @override
  List<Object?> get props => [retryAfterSeconds];
}

// Sending the code failed. [retryAfterSeconds] is set when the backend
// rate-limited the request (429) and says when to try again.
class OtpFailure extends AuthUnauthenticated {
  final String message;
  final int? retryAfterSeconds;
  OtpFailure(this.message, {this.retryAfterSeconds});
  @override
  List<Object?> get props => [message, retryAfterSeconds];
}

// Optional: specific error state
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object> get props => [message];
}
