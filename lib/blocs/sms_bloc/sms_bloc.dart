import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../data/repositories/sms_repository.dart';

part 'sms_event.dart';
part 'sms_state.dart';

class SmsBloc extends Bloc<SmsEvent, SmsState> {
  final SmsRepository repository;

  SmsBloc({required this.repository}) : super(SmsInitial()) {
    on<SendSmsEvent>(_onSendSms);
  }

  Future<void> _onSendSms(SendSmsEvent event, Emitter<SmsState> emit) async {
    emit(SmsSending());
    final ok = await repository.sendOtp(to: event.to, message: event.message);
    if (ok) {
      emit(SmsSent());
    } else {
      emit(SmsError('Failed to send SMS'));
    }
  }
}
