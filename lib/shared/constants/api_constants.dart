class ApiConstants {
  static const String _rawBaseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://10.0.2.2:3000', // your local URL
  );

  // Strip trailing slashes so '${baseUrl}/api/...' never becomes '//api/...'.
  static final String baseUrl = _rawBaseUrl.replaceAll(RegExp(r'/+$'), '');
}
