part of 'authentication_bloc.dart';

enum AuthenticationStatus { unknown, authenticated, unauthenticated }

class AuthenticationState extends Equatable {
  final AuthenticationStatus status;
  final dynamic user; // Replace 'dynamic' with your User model
  final String? errorMessage;
  final bool isLoading;

  const AuthenticationState._({
    this.status = AuthenticationStatus.unknown,
    this.user,
    this.errorMessage,
    this.isLoading = false,
  });

  // Factory constructors for easier state creation
  const AuthenticationState.unknown() : this._();

  const AuthenticationState.authenticated(dynamic user)
      : this._(status: AuthenticationStatus.authenticated, user: user);

  const AuthenticationState.unauthenticated()
      : this._(status: AuthenticationStatus.unauthenticated);

  const AuthenticationState.loading() : this._(isLoading: true);

  const AuthenticationState.failure(String message)
      : this._(errorMessage: message);

  @override
  List<Object?> get props => [status, user, errorMessage, isLoading];
}
