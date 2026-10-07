import 'dart:async';
import 'dart:convert';
import 'package:beeyo_customer/shared/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Result of a successful [AuthRepository.login] call — lets the caller
/// (AuthBloc) decide whether to send a first-time signer through the
/// "what should we call you?" prompt.
class LoginResult {
  final bool isNewUser;
  final String? name;

  const LoginResult({required this.isNewUser, this.name});
}

/// Thrown by any repository after an authenticated request comes back 401.
/// By the time this is thrown, [AuthRepository.handleUnauthorized] has
/// already cleared the stale session — callers should treat this as "log
/// in again", not a generic network failure.
class SessionExpiredException implements Exception {
  const SessionExpiredException();
  @override
  String toString() => 'Session expired. Please log in again.';
}

/// A user-facing auth failure — [message] is safe to show on screen as-is
/// (it's either the backend's own `message` or one of our friendly
/// fallbacks, never a raw exception dump).
class AuthApiException implements Exception {
  final String message;
  // Set on 429s — how long until the backend will accept another OTP request.
  final int? retryAfterSeconds;

  const AuthApiException(this.message, {this.retryAfterSeconds});

  @override
  String toString() => message;
}

class AuthRepository {
  // Added 'https://' so the app knows how to connect to it securely
  final String loginUrl = '${ApiConstants.baseUrl}/api/v1/auth/signin';
  final String sendOtpUrl = '${ApiConstants.baseUrl}/api/v1/auth/send-otp';
  final String profileUrl = '${ApiConstants.baseUrl}/api/v1/users/profile';

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_phone';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _fallbackToken = 'success_fallback_token';
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const int _defaultResendSeconds = 30;

  // Broadcasts once whenever any repository hits a 401 on an authenticated
  // endpoint. AuthBloc subscribes to this to flip the whole app back to
  // "logged out" and route to LoginScreen, without every repo needing its
  // own reference to AuthBloc/Navigator.
  final _unauthorizedController = StreamController<void>.broadcast();
  Stream<void> get onUnauthorized => _unauthorizedController.stream;

  /// Call this the moment any authenticated request comes back 401. Clears
  /// the now-invalid session and notifies [onUnauthorized] listeners.
  /// Idempotent — a burst of 401s from several in-flight requests only
  /// clears/notifies once.
  Future<void> handleUnauthorized() async {
    if (!await isLoggedIn()) return;
    await logout();
    _unauthorizedController.add(null);
  }

  // Check if user is already logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null) return false;
    if (token == _fallbackToken) {
      // A session saved before the accessToken-parsing fix — this token is
      // a literal placeholder, not a real JWT, so nothing authenticated
      // will ever work with it. Clear it and make the user log in for
      // real rather than pretending this session is valid.
      await prefs.clear();
      return false;
    }
    return true;
  }

  // Get the saved token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // Get the backend user id (needed for order placement / history)
  Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userKey);
  }

  Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  /// Cached name if we have one, otherwise asks the backend — covers
  /// sessions where the name was set on another device, or before it was
  /// cached locally.
  Future<String?> fetchUserName() async {
    final cached = await getUserName();
    if (cached != null && cached.trim().isNotEmpty) return cached;
    final token = await getToken();
    if (token == null) return null;
    return _fetchAndStoreProfile(token);
  }

  /// Asks the backend to SMS a login OTP to [phone] (10 digits, no +91).
  /// Returns how many seconds to wait before the user may request another.
  Future<int> sendOtp(String phone) async {
    final response = await _postAuth(sendOtpUrl, {'mobile': phone});
    final body = _decodeBody(response);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = body?['data'];
      final retryAfter = data is Map ? data['retryAfterSeconds'] : null;
      return retryAfter is num ? retryAfter.toInt() : _defaultResendSeconds;
    }

    throw _errorFrom(response, body,
        fallback: 'Could not send OTP right now. Please try again shortly.');
  }

  // --- INTEGRATED API LOGIN FUNCTION ---
  Future<LoginResult> login(String phone, String otp) async {
    final response = await _postAuth(loginUrl, {'mobile': phone, 'otp': otp});

    // Check if the API returned 201 Created (or 200 OK)
    if (response.statusCode != 201 && response.statusCode != 200) {
      // 401 carries the exact reason (wrong code + attempts left, expired,
      // locked) in `message` — surface that instead of a generic error.
      throw _errorFrom(response, _decodeBody(response),
          fallback: 'Invalid OTP or Phone Number. Please try again.');
    }

    // 1. Parse the JSON response body. Real shape (confirmed live):
    // { success, code, message, data: { accessToken, user: { id, isNew, ... } }, errors, metadata }
    final responseData = _decodeBody(response);
    final data = responseData?['data'] as Map<String, dynamic>?;

    // 2. Extract the token — prefer the nested `data.accessToken` shape,
    // fall back to a few likely alternates in case the backend shape
    // ever changes, but never silently store a fake token.
    final String? realToken = data?['accessToken'] as String? ??
        data?['token'] as String? ??
        responseData?['accessToken'] as String? ??
        responseData?['token'] as String?;

    if (realToken == null) {
      throw const AuthApiException(
          'Login succeeded but no token was returned. Please try again.');
    }

    // 3. Save the real token locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, realToken);
    await prefs.setString(_userKey, phone);

    // 4. Store the backend user id — required for order
    // placement/history, which are keyed by userId, not the token.
    final userJson = data?['user'] as Map<String, dynamic>?;
    final userId = userJson?['id'];
    if (userId != null) {
      await prefs.setString(_userIdKey, userId.toString());
    } else {
      await _fetchAndStoreProfile(realToken);
    }

    // 5. First-time signers have no display name yet — the caller
    // (AuthBloc/LoginScreen) uses this to route them through a
    // "what should we call you?" prompt. Returning users might already
    // have a name saved on the backend from a previous session/device,
    // so fetch it once and cache locally if we don't have it yet.
    final isNewUser = userJson?['isNew'] as bool? ?? false;
    String? name = await getUserName();
    if (!isNewUser && name == null) {
      name = await _fetchAndStoreProfile(realToken);
    }

    return LoginResult(isNewUser: isNewUser, name: name);
  }

  /// Pushes a new display name to the backend user record and caches it
  /// locally. Used both by the first-login "what should we call you?"
  /// prompt and any later "edit name" flow.
  Future<void> updateUserName(String name) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('Not logged in');
    }

    // Self-service endpoint — PUT /users/:id is admin-only and 403s for
    // customers.
    final response = await http
        .put(
          Uri.parse(profileUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      await handleUnauthorized();
      throw const SessionExpiredException();
    }

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to save name (${response.statusCode})');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  /// Backfills the user id for sessions that were logged in before this was
  /// tracked — safe to call repeatedly, no-ops once an id is already saved.
  Future<void> ensureUserId() async {
    if (await getUserId() != null) return;
    final token = await getToken();
    if (token == null) return;
    await _fetchAndStoreProfile(token);
  }

  /// Fetches `/users/profile`, caches whatever id/name it finds, and
  /// returns the name (if any) for callers that need it immediately.
  /// Best-effort — swallows network errors, since every call site here has
  /// a reasonable fallback (raw phone number, a re-prompt, etc).
  Future<String?> _fetchAndStoreProfile(String token) async {
    try {
      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      final data = (decoded is Map && decoded['data'] is Map)
          ? decoded['data'] as Map<String, dynamic>
          : decoded as Map<String, dynamic>;

      final prefs = await SharedPreferences.getInstance();

      final id = data['id'] ?? data['_id'] ?? data['userId'];
      if (id != null) {
        await prefs.setString(_userIdKey, id.toString());
      }

      final name = data['name'] as String?;
      if (name != null && name.trim().isNotEmpty) {
        await prefs.setString(_userNameKey, name);
      }
      return name;
    } catch (_) {
      return null;
    }
  }

  /// POSTs a JSON body to an unauthenticated auth endpoint, turning
  /// timeouts and connectivity failures into user-facing messages.
  Future<http.Response> _postAuth(String url, Map<String, String> body) async {
    try {
      return await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw const AuthApiException(
          'The server is taking too long to respond. Please try again.');
    } catch (_) {
      throw const AuthApiException(
          "Couldn't reach the server. Check your internet connection and try again.");
    }
  }

  Map<String, dynamic>? _decodeBody(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Builds the error for a non-2xx response from the backend's envelope:
  /// `{ success, code, message, data, errors, metadata }`.
  AuthApiException _errorFrom(
    http.Response response,
    Map<String, dynamic>? body, {
    required String fallback,
  }) {
    final message = body?['message'];
    final errors = body?['errors'];
    final data = body?['data'];

    if (response.statusCode == 429) {
      final retryAfter = data is Map ? data['retryAfterSeconds'] : null;
      return AuthApiException(
        message is String && message.isNotEmpty
            ? message
            : 'Too many attempts. Please try again later.',
        retryAfterSeconds: retryAfter is num ? retryAfter.toInt() : null,
      );
    }

    // Validation failures (400) put the useful reason in `errors`, with a
    // generic "Validation failed" as the `message`.
    if (response.statusCode == 400 && errors is List && errors.isNotEmpty) {
      return AuthApiException(errors.first.toString());
    }

    // 503 (SMS provider down) has a friendly message; other 5xx are just
    // "Internal server error", so prefer our own wording there.
    if (response.statusCode >= 500 && response.statusCode != 503) {
      return AuthApiException(fallback);
    }

    return AuthApiException(
        message is String && message.isNotEmpty ? message : fallback);
  }

  // Logout function
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
