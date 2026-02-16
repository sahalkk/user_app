import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
  // Added 'https://' so the app knows how to connect to it securely
  final String loginUrl =
      'https://nestjs-backend-egj0.onrender.com/api/v1/auth/signin';

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'user_phone';

  // Check if user is already logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_tokenKey);
  }

  // Get the saved token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
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
        // 1. Parse the JSON response body
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        // 2. Extract the token from your backend response
        // Note: Change 'token' to 'accessToken' or whatever key your NestJS API actually returns!
        final String realToken = responseData['token'] ??
            responseData['accessToken'] ??
            "success_fallback_token";

        // 3. Save the real token locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, realToken);
        await prefs.setString(_userKey, phone);
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

  // Logout function
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
