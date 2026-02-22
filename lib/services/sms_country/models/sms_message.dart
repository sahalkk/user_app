class SmsMessage {
  final String to;
  final String message;

  SmsMessage({required this.to, required this.message});

  Map<String, String> toQueryParams({required String username, required String apiKey, String sender = 'SMSGATE'}) {
    return {
      'username': username,
      'password': apiKey,
      'to': to,
      'message': message,
      'sender': sender,
      'route': 'TRANS',
    };
  }
}
