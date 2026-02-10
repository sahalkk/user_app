import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object> get props => [];
}

// Initial state before we check anything
class AuthInitial extends AuthState {}

// Showing a spinner while logging in
class AuthLoading extends AuthState {}

// User is logged in (We have a token!)
class AuthAuthenticated extends AuthState {
  final String token;

  const AuthAuthenticated(this.token);

  @override
  List<Object> get props => [token];
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
