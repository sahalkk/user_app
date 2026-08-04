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

class AuthRepository {
  // Added 'https://' so the app knows how to connect to it securely
  final String loginUrl = '${ApiConstants.baseUrl}/api/v1/auth/signin';
  final String profileUrl = '${ApiConstants.baseUrl}/api/v1/users/profile';

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_phone';
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _fallbackToken = 'success_fallback_token';

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

  // --- INTEGRATED API LOGIN FUNCTION ---
  Future<LoginResult> login(String phone, String otp) async {
    try {
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'mobile': phone,
          'otp': otp,
        }),
      );

      print("=== LOGIN API RESPONSE ===");
      print("Status Code: ${response.statusCode}");
      print("Body: ${response.body}");
      print("==========================");

      // Check if the API returned 201 Created (or 200 OK)
      if (response.statusCode == 201 || response.statusCode == 200) {
        // 1. Parse the JSON response body. Real shape (confirmed live):
        // { success, code, message, data: { accessToken, user: { id, isNew, ... } }, errors, metadata }
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final data = responseData['data'] as Map<String, dynamic>?;

        // 2. Extract the token — prefer the nested `data.accessToken` shape,
        // fall back to a few likely alternates in case the backend shape
        // ever changes, but never silently store a fake token.
        final String? realToken = data?['accessToken'] as String? ??
            data?['token'] as String? ??
            responseData['accessToken'] as String? ??
            responseData['token'] as String?;

        if (realToken == null) {
          throw Exception('Login succeeded but no token was returned');
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
      } else {
        // If the API returns an error (like 400 Wrong OTP), we throw an error
        // so the AuthBloc can catch it and show a message on the screen.
        throw Exception('Invalid OTP or Phone Number. Please try again.');
      }
    } catch (e) {
      // Catches network errors (no internet) or the exception we threw above
      throw Exception('Login failed: $e');
    }
  }

  /// Pushes a new display name to the backend user record and caches it
  /// locally. Used both by the first-login "what should we call you?"
  /// prompt and any later "edit name" flow.
  Future<void> updateUserName(String name) async {
    final userId = await getUserId();
    final token = await getToken();
    if (userId == null || token == null) {
      throw Exception('Not logged in');
    }

    final response = await http
        .put(
          Uri.parse('${ApiConstants.baseUrl}/api/v1/users/$userId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'name': name}),
        )
        .timeout(const Duration(seconds: 10));

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

  // Logout function
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
