import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models/sms_message.dart';
import '../../shared/sms_country_config.dart';
import 'sms_country_api.dart';

class SmsCountryService {
  final SmsCountryApi _api;

  SmsCountryService(SmsCountryConfig config) : _api = SmsCountryApi(config);

  Future<bool> sendSms(SmsMessage message) async {
    try {
      final http.Response res = await _api.sendSms(message);
      if (res.statusCode == 200) {
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
