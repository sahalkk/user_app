import 'package:shared_preferences/shared_preferences.dart';

class AuthRepository {
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

  // LOGIN FUNCTION (Mock)
  Future<void> login(String phone, String otp) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    // MOCK LOGIC: In real app, you send phone/otp to backend and get a token.
    // For now, we just generate a fake token.
    final fakeToken = "mock_token_${DateTime.now().millisecondsSinceEpoch}";

    // Save data locally
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, fakeToken);
    await prefs.setString(_userKey, phone);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
