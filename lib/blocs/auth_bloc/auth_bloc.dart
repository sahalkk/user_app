import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    // 1. Check Login Status on App Start
    on<AppStarted>(_onAppStarted);

    // 2. Handle Login
    on<LoginRequested>(_onLoginRequested);

    // 3. Handle Logout
    on<LogoutRequested>(_onLogoutRequested);
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AuthState> emit) async {
    try {
      final isLoggedIn = await authRepository.isLoggedIn();
      if (isLoggedIn) {
        final token = await authRepository.getToken();
        // Backfills the backend user id for sessions logged in before order
        // placement needed it — no-ops if already stored.
        await authRepository.ensureUserId();
        final phone = await authRepository.getUserPhone();
        final name = await authRepository.getUserName();
        emit(AuthAuthenticated(token ?? "", phone: phone, name: name));
      } else {
        emit(AuthUnauthenticated());
      }
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
      LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final result = await authRepository.login(event.phone, event.otp);
      final token = await authRepository.getToken();

      if (token != null) {
        emit(AuthAuthenticated(
          token,
          phone: event.phone,
          name: result.name,
          isNewUser: result.isNewUser,
        ));
      } else {
        emit(const AuthFailure("Login failed: No token received"));
      }
    } catch (e) {
      emit(AuthFailure(e.toString()));
    }
  }

  Future<void> _onLogoutRequested(
      LogoutRequested event, Emitter<AuthState> emit) async {
    await authRepository.logout();
    emit(AuthUnauthenticated());
  }
}
