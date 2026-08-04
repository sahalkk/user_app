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

// Optional: specific error state
class AuthFailure extends AuthState {
  final String message;
  const AuthFailure(this.message);
  @override
  List<Object> get props => [message];
}
