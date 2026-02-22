class SmsCountryConfig {
  final String username;
  final String apiKey;
  final String baseUrl;

  const SmsCountryConfig({
    required this.username,
    required this.apiKey,
    this.baseUrl = 'https://www.smscountry.com/SMSCwebservice_bulk.aspx',
  });
}
