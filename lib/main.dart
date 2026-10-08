import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app.dart';
import 'debug/debug_log.dart';
import 'simple_bloc_observer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // dart:io's HttpOverrides has no meaning on web (the browser owns TLS) —
  // skip it there rather than relying on the web stub to no-op safely.
  if (!kIsWeb) {
    HttpOverrides.global = MyHttpOverrides();
  }

  await dotenv.load(fileName: '.env');

  Bloc.observer = SimpleBlocObserver();

  // TEMP: on-screen request/error log — see lib/debug/debug_log.dart.
  DebugLog.runZoned(() => runApp(const MyApp()));
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}
