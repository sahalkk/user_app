import 'package:http/http.dart' as http;
import '../../shared/sms_country_config.dart';
import 'models/sms_message.dart';

class SmsCountryApi {
  final SmsCountryConfig config;

  SmsCountryApi(this.config);

  Future<http.Response> sendSms(SmsMessage message) async {
    final uri = Uri.parse(config.baseUrl).replace(queryParameters: message.toQueryParams(username: config.username, apiKey: config.apiKey));
    final response = await http.get(uri);
    return response;
  }
}
