part of 'sms_bloc.dart';

abstract class SmsEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class SendSmsEvent extends SmsEvent {
  final String to;
  final String message;

  SendSmsEvent({required this.to, required this.message});

  @override
  List<Object?> get props => [to, message];
}
