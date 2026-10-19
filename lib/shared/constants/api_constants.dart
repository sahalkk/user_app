class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:3000', // your local URL
  );
}
