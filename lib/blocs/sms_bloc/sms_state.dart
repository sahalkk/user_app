part of 'sms_bloc.dart';

abstract class SmsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SmsInitial extends SmsState {}

class SmsSending extends SmsState {}

class SmsSent extends SmsState {}

class SmsError extends SmsState {
  final String message;
  SmsError(this.message);

  @override
  List<Object?> get props => [message];
}
