part of 'authentication_bloc.dart';

abstract class AuthenticationEvent extends Equatable {
  const AuthenticationEvent();

  @override
  List<Object> get props => [];
}

class AuthenticationUserChanged extends AuthenticationEvent {
  // Use 'dynamic' or your specific User model here if you have one
  final dynamic user;

  const AuthenticationUserChanged(this.user);

  @override
  List<Object> get props => [user ?? 'null'];
}

class SignInRequired extends AuthenticationEvent {
  final String email;
  final String password;

  const SignInRequired(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class SignUpRequired extends AuthenticationEvent {
  final String email;
  final String password;
  // Add other fields if needed like name, phone, etc.

  const SignUpRequired(this.email, this.password);

  @override
  List<Object> get props => [email, password];
}

class SignOutRequired extends AuthenticationEvent {}
