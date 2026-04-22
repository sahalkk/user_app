import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'simple_bloc_observer.dart';
import 'shared/sms_country_config.dart';
import 'services/sms_country/sms_country_service.dart';
import 'data/repositories/sms_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();

  await dotenv.load(fileName: '.env');

  Bloc.observer = SimpleBlocObserver();

  final smsConfig = SmsCountryConfig(
    username: dotenv.env['SMSCOUNTRY_USERNAME'] ?? '',
    apiKey: dotenv.env['SMSCOUNTRY_APIKEY'] ?? '',
  );

  final smsService = SmsCountryService(smsConfig);
  final smsRepository = SmsRepository(smsService);

  runApp(
    RepositoryProvider.value(
      value: smsRepository,
      child: const MyApp(),
    ),
  );
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
