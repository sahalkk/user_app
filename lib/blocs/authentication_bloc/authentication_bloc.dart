import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'authentication_event.dart';
part 'authentication_state.dart';

class AuthenticationBloc
    extends Bloc<AuthenticationEvent, AuthenticationState> {
  // We can inject a UserRepository here later
  AuthenticationBloc() : super(const AuthenticationState.unknown()) {
    on<SignInRequired>(_onSignInRequired);
    on<SignUpRequired>(_onSignUpRequired);
    on<SignOutRequired>(_onSignOutRequired);
  }

  Future<void> _onSignInRequired(
    SignInRequired event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(const AuthenticationState.loading());
    try {
      // TODO: Replace with Real API Call
      await Future.delayed(
          const Duration(seconds: 2)); // Simulate network delay

      // Mock Success Logic
      if (event.email.isNotEmpty && event.password.length >= 6) {
        // Create a mock user object
        final mockUser = {'email': event.email, 'id': '123'};
        emit(AuthenticationState.authenticated(mockUser));
      } else {
        emit(const AuthenticationState.failure("Invalid email or password"));
      }
    } catch (e) {
      emit(AuthenticationState.failure(e.toString()));
    }
  }

  Future<void> _onSignUpRequired(
    SignUpRequired event,
    Emitter<AuthenticationState> emit,
  ) async {
    emit(const AuthenticationState.loading());
    try {
      // TODO: Replace with Real API Call
      await Future.delayed(const Duration(seconds: 2));

      final mockUser = {'email': event.email, 'id': 'new_user_123'};
      emit(AuthenticationState.authenticated(mockUser));
    } catch (e) {
      emit(AuthenticationState.failure(e.toString()));
    }
  }

  void _onSignOutRequired(
    SignOutRequired event,
    Emitter<AuthenticationState> emit,
  ) {
    emit(const AuthenticationState.unauthenticated());
  }
}
