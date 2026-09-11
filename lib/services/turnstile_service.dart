import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

// ponytail: flip to true only after Phase 0b confirms the baseUrl-origin
// approach doesn't pass on a real device. Same widget, same JS channel.
const bool _useRealPage = false;

const String _sitekey = '0x4AAAAAAEmwuOx0sKb7pWLw';
const String _action = 'quickpay_balance';

/// Pure HTML for the Cloudflare Turnstile challenge page. No I/O, no args,
/// so this is trivially unit-testable.
String turnstileHtml() {
  return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<style>
  html, body { margin: 0; padding: 0; background: transparent; }
  #cf-turnstile { display: flex; align-items: center; justify-content: center; }
</style>
</head>
<body>
<div id="cf-turnstile"></div>
<script>
  var _tsTimedOut = false;
  var _tsTimeoutId = setTimeout(function () {
    _tsTimedOut = true;
    Dart.postMessage(JSON.stringify({type: 'script_timeout'}));
  }, 8000);

  function cb() {
    clearTimeout(_tsTimeoutId);
    if (_tsTimedOut) return;
    turnstile.render('#cf-turnstile', {
      sitekey: '$_sitekey',
      action: '$_action',
      callback: function (token) {
        Dart.postMessage(JSON.stringify({type: 'callback', token: token}));
      },
      'error-callback': function (error) {
        Dart.postMessage(JSON.stringify({type: 'error-callback', error: String(error)}));
        return true;
      },
      'timeout-callback': function () {
        Dart.postMessage(JSON.stringify({type: 'timeout-callback'}));
      },
      'expired-callback': function () {
        Dart.postMessage(JSON.stringify({type: 'expired-callback'}));
      },
      'unsupported-callback': function () {
        Dart.postMessage(JSON.stringify({type: 'unsupported-callback'}));
      },
      'before-interactive-callback': function () {
        Dart.postMessage(JSON.stringify({type: 'before-interactive-callback'}));
      }
    });
  }
</script>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=cb&render=explicit" async defer></script>
</body>
</html>
''';
}

String _mapErrorType(String type) {
  switch (type) {
    case 'unsupported-callback':
    case 'unsupported':
      return 'Your device WebView is too old to complete verification. Please update WebView and try again.';
    case 'script_timeout':
      return 'Verification could not load. Please check your connection and try again.';
    case 'timeout-callback':
    case 'timeout':
    case 'expired-callback':
    case 'expired':
      return 'Verification timed out, please try again.';
    case 'error-callback':
      return 'Verification failed, please try again.';
    default:
      return 'Verification failed, please try again.';
  }
}

/// Shows a modal bottom sheet with an interactive Cloudflare Turnstile
/// challenge and resolves with the verification token.
Future<String> solveTurnstile(BuildContext context) async {
  final completer = Completer<String>();

  void completeError(String message) {
    if (!completer.isCompleted) {
      completer.completeError(Exception(message));
    }
  }

  void completeSuccess(String token) {
    if (!completer.isCompleted) {
      completer.complete(token);
    }
  }

  final controller = WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setBackgroundColor(Colors.transparent)
    ..setUserAgent(
      'Mozilla/5.0 (Linux; Android 13; Pixel 6) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
    )
    ..addJavaScriptChannel(
      'Dart',
      onMessageReceived: (JavaScriptMessage message) {
        try {
          final data = json.decode(message.message) as Map<String, dynamic>;
          final type = data['type'] as String?;
          if (type == 'callback') {
            final token = data['token'] as String?;
            if (token != null && token.isNotEmpty) {
              completeSuccess(token);
            } else {
              completeError(_mapErrorType(type ?? ''));
            }
          } else {
            completeError(_mapErrorType(type ?? ''));
          }
        } catch (_) {
          completeError('Verification failed, please try again.');
        }
      },
    );

  if (_useRealPage) {
    controller.setNavigationDelegate(
      NavigationDelegate(
        onPageFinished: (_) {
          controller.runJavaScript(
            '''
            (function() {
              var s = document.createElement('script');
              s.src = 'https://challenges.cloudflare.com/turnstile/v0/api.js?onload=cb&render=explicit';
              s.async = true;
              document.head.appendChild(s);
            })();
            ''',
          );
        },
      ),
    );
    unawaited(controller.loadRequest(Uri.parse('https://amiapp.dpdc.org.bd/')));
  } else {
    unawaited(
      controller.loadHtmlString(
        turnstileHtml(),
        baseUrl: 'https://amiapp.dpdc.org.bd',
      ),
    );
  }

  if (context.mounted) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (sheetContext) {
        return SizedBox(
          height: 200,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Verifying you are human...'),
              ),
              SizedBox(
                width: 320,
                height: 80,
                child: WebViewWidget(controller: controller),
              ),
            ],
          ),
        );
      },
    ).then((_) {
      completeError('Verification cancelled');
    });
  }

  return completer.future.timeout(
    const Duration(seconds: 45),
    onTimeout: () {
      throw Exception('Verification timed out, please try again.');
    },
  );
}
