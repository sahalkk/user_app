import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object> get props => [];
}

// Fired when the app first opens to check if user is already logged in
class AppStarted extends AuthEvent {}

// Fired when user clicks "Verify & Login"
class LoginRequested extends AuthEvent {
  final String phone;
  final String otp;

  const LoginRequested({required this.phone, required this.otp});

  @override
  List<Object> get props => [phone, otp];
}

// Fired when user clicks "Logout"
class LogoutRequested extends AuthEvent {}

// Fired when a repository gets a 401 from an authenticated endpoint —
// see AuthRepository.onUnauthorized.
class SessionExpiredEvent extends AuthEvent {}
