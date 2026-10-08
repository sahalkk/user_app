// TEMPORARY on-screen debug log — for diagnosing backend connectivity on
// release builds where there's no `flutter run` console.
//
// To remove: delete this file, then drop the `debug_log.dart` import plus the
// `DebugLog.*` / `DebugLogOverlay` references in main.dart and app_view.dart.
// Or just flip [kShowDebugLog] to false to hide the button but keep logging.

import 'dart:async';
import 'dart:convert';

import 'package:beeyo_customer/shared/constants/api_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const bool kShowDebugLog = true;

class DebugLogEntry {
  final DateTime time;
  final String message;
  final bool isError;

  DebugLogEntry(this.message, {this.isError = false}) : time = DateTime.now();

  String get timeLabel {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(time.hour)}:${two(time.minute)}:${two(time.second)}';
  }

  @override
  String toString() => '[$timeLabel]${isError ? ' ERROR' : ''} $message';
}

class DebugLog {
  DebugLog._();

  static const int _maxEntries = 200;
  static final entries = ValueNotifier<List<DebugLogEntry>>(const []);

  static int get errorCount => entries.value.where((e) => e.isError).length;

  static void add(String message, {bool isError = false}) {
    debugPrint('[DebugLog] $message');
    final next = [...entries.value, DebugLogEntry(message, isError: isError)];
    entries.value = next.length > _maxEntries
        ? next.sublist(next.length - _maxEntries)
        : next;
  }

  static void error(Object error, [StackTrace? stack]) {
    final firstFrames = stack?.toString().split('\n').take(4).join('\n');
    add(
      '${error.runtimeType}: $error'
      '${firstFrames != null && firstFrames.isNotEmpty ? '\n$firstFrames' : ''}',
      isError: true,
    );
  }

  static void clear() => entries.value = const [];

  /// Runs [body] (i.e. `runApp`) with every `package:http` request routed
  /// through [_LoggingClient], and hooks Flutter's global error handlers.
  static void runZoned(void Function() body) {
    final previousFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      error(details.exception, details.stack);
      previousFlutterOnError?.call(details);
    };
    PlatformDispatcher.instance.onError = (e, stack) {
      error(e, stack);
      return false; // keep default handling (crash reporting / console)
    };

    // Created outside the zone, so this is the real platform client.
    final inner = http.Client();
    add('App start — baseUrl="${ApiConstants.baseUrl}"');
    http.runWithClient(body, () => _LoggingClient(inner));
  }
}

class _LoggingClient extends http.BaseClient {
  final http.Client _inner;
  _LoggingClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final sw = Stopwatch()..start();
    final label = '${request.method} ${request.url}';
    try {
      final response = await _inner.send(request);
      if (response.statusCode < 400) {
        DebugLog.add('$label → ${response.statusCode} (${sw.elapsedMilliseconds}ms)');
        return response;
      }
      // Buffer error bodies so we can show the backend's message, then hand
      // the caller an equivalent response.
      final bytes = await response.stream.toBytes();
      var body = utf8.decode(bytes, allowMalformed: true);
      if (body.length > 500) body = '${body.substring(0, 500)}…';
      DebugLog.add(
        '$label → ${response.statusCode} (${sw.elapsedMilliseconds}ms)\n$body',
        isError: true,
      );
      return http.StreamedResponse(
        Stream.value(bytes),
        response.statusCode,
        contentLength: bytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (e) {
      DebugLog.add(
        '$label → FAILED after ${sw.elapsedMilliseconds}ms\n'
        '${e.runtimeType}: $e',
        isError: true,
      );
      rethrow;
    }
  }

  // Top-level http.get/post close their client after every call — keep the
  // shared inner client alive.
  @override
  void close() {}
}

/// Small floating bug button (with error count) layered over the whole app.
/// Needs [navigatorKey] because it sits above the Navigator in the tree.
class DebugLogOverlay extends StatelessWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  const DebugLogOverlay({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    if (!kShowDebugLog) return child;
    return Stack(
      children: [
        child,
        Positioned(
          right: 8,
          bottom: 120,
          child: ValueListenableBuilder<List<DebugLogEntry>>(
            valueListenable: DebugLog.entries,
            builder: (context, _, __) {
              final errors = DebugLog.errorCount;
              return Material(
                color: errors > 0 ? Colors.red : Colors.black54,
                shape: const StadiumBorder(),
                elevation: 4,
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () => _open(),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      errors > 0 ? '🐞 $errors' : '🐞',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _open() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    showDialog<void>(context: ctx, builder: (_) => const _DebugLogDialog());
  }
}

class _DebugLogDialog extends StatelessWidget {
  const _DebugLogDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      title: Text(
        'Debug log\n${ApiConstants.baseUrl}',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.55,
        child: ValueListenableBuilder<List<DebugLogEntry>>(
          valueListenable: DebugLog.entries,
          builder: (context, entries, _) {
            if (entries.isEmpty) {
              return const Center(child: Text('No entries yet'));
            }
            final newestFirst = entries.reversed.toList();
            return ListView.separated(
              itemCount: newestFirst.length,
              separatorBuilder: (_, __) => const Divider(height: 8),
              itemBuilder: (_, i) {
                final e = newestFirst[i];
                return SelectableText(
                  '${e.timeLabel}  ${e.message}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: e.isError ? Colors.red.shade700 : Colors.black87,
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: DebugLog.clear, child: const Text('Clear')),
        TextButton(
          onPressed: () {
            Clipboard.setData(
                ClipboardData(text: DebugLog.entries.value.join('\n')));
            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Log copied')));
          },
          child: const Text('Copy'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
