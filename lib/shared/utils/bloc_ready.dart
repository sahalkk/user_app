import 'package:flutter_bloc/flutter_bloc.dart';

/// Every bloc that resolves something asynchronously on startup (reading
/// SharedPreferences, hitting an API) has a transient initial state before
/// the real answer is known. Reading `.state` synchronously during that
/// window silently returns the transient state instead of the real one —
/// that's what caused the Orders tab to show a login screen for an already
/// logged-in user right after a cold start (AuthBloc hadn't finished
/// resolving AppStarted yet when MainWrapper's tab guard read its state).
///
/// Use [firstWhereReady] instead of a raw `.state` read anywhere behavior
/// depends on a bloc having finished its startup resolution — it returns
/// immediately if already resolved, or waits for the next state that is,
/// so callers never have to special-case "still loading".
extension BlocReadyX<S> on BlocBase<S> {
  Future<S> firstWhereReady(bool Function(S state) isReady) {
    if (isReady(state)) return Future.value(state);
    return stream.firstWhere(isReady);
  }
}
