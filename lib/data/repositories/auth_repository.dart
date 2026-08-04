import 'dart:convert';
import 'package:beeyo_customer/shared/constants/api_constants.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  // Added 'https://' so the app knows how to connect to it securely
  final String loginUrl = '${ApiConstants.baseUrl}/api/v1/auth/signin';
  final String profileUrl = '${ApiConstants.baseUrl}/api/v1/users/profile';

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_phone';
  static const String _userIdKey = 'user_id';
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

  // --- INTEGRATED API LOGIN FUNCTION ---
  Future<void> login(String phone, String otp) async {
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
        // { success, code, message, data: { accessToken, user: { id, ... } }, errors, metadata }
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
        // The signin response already includes it, so no extra request is
        // needed on the common path; _fetchAndStoreUserId is only a
        // fallback for unexpected response shapes.
        final userId = (data?['user'] as Map<String, dynamic>?)?['id'];
        if (userId != null) {
          await prefs.setString(_userIdKey, userId.toString());
        } else {
          await _fetchAndStoreUserId(realToken);
        }
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

  /// Backfills the user id for sessions that were logged in before this was
  /// tracked — safe to call repeatedly, no-ops once an id is already saved.
  Future<void> ensureUserId() async {
    if (await getUserId() != null) return;
    final token = await getToken();
    if (token == null) return;
    await _fetchAndStoreUserId(token);
  }

  Future<void> _fetchAndStoreUserId(String token) async {
    try {
      final response = await http.get(
        Uri.parse(profileUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      final data = (decoded is Map && decoded['data'] is Map)
          ? decoded['data'] as Map<String, dynamic>
          : decoded as Map<String, dynamic>;
      final id = data['id'] ?? data['_id'] ?? data['userId'];
      if (id == null) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, id.toString());
    } catch (_) {
      // Best-effort — order placement will surface a clear "please log in
      // again" error if the id is still missing when it's actually needed.
    }
  }

  // Logout function
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
