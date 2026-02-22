import '../../services/sms_country/models/sms_message.dart';
import '../../services/sms_country/sms_country_service.dart';

class SmsRepository {
  final SmsCountryService _service;

  SmsRepository(this._service);

  Future<bool> sendOtp({required String to, required String message}) async {
    final sms = SmsMessage(to: to, message: message);
    return await _service.sendSms(sms);
  }
}
