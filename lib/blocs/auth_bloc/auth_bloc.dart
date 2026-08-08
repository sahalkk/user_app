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
      if (!isLoggedIn) {
        emit(AuthUnauthenticated());
        return;
      }

      // Resolve from fast local reads (SharedPreferences) and emit
      // immediately — the "am I logged in" answer must never be blocked on
      // a network call.
      final token = await authRepository.getToken();
      final phone = await authRepository.getUserPhone();
      final name = await authRepository.getUserName();
      emit(AuthAuthenticated(token ?? "", phone: phone, name: name));
    } catch (_) {
      emit(AuthUnauthenticated());
      return;
    }

    // Best-effort backfill for legacy sessions that predate userId capture
    // at login — runs *after* the emit above so it can't hold up startup,
    // and is isolated in its own try/catch so a failure here can never
    // downgrade the AuthAuthenticated state already emitted.
    try {
      await authRepository.ensureUserId();
    } catch (_) {
      // ignore — order placement surfaces a clear error if still missing.
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
