import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../auth/auth_service.dart';
import '../core/env.dart';

/// State of the "verify you are human" check for one form: whether the server wants it and the token once passed.
class CaptchaController extends ChangeNotifier {
  bool enabled = false;
  bool loaded = false;
  bool failed = false;
  String? token;
  WebViewController? _web;

  /// A token works once: call this after a failed submit to ask for a fresh one.
  void reset() {
    token = null;
    _web?.runJavaScript('if (window.turnstile) turnstile.reset();');
    notifyListeners();
  }

  void _update({bool? enabled, bool? loaded, bool? failed, String? token, bool clearToken = false}) {
    this.enabled = enabled ?? this.enabled;
    this.loaded = loaded ?? this.loaded;
    this.failed = failed ?? this.failed;
    if (clearToken) this.token = null;
    if (token != null) this.token = token;
    notifyListeners();
  }
}

/// Shows Cloudflare Turnstile in a WebView when the server has the check switched on; nothing otherwise.
class CaptchaField extends StatefulWidget {
  const CaptchaField({super.key, required this.controller});

  final CaptchaController controller;

  @override
  State<CaptchaField> createState() => _CaptchaFieldState();
}

class _CaptchaFieldState extends State<CaptchaField> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final c = widget.controller;
    try {
      final res = await context.read<AuthService>().api.dio.get('/api/auth/captcha-config');
      final data = res.data as Map<String, dynamic>;
      final siteKey = data['siteKey'] as String? ?? '';
      // The key is public but is placed into a page: accept only the characters a real key has.
      if (data['enabled'] != true || !RegExp(r'^[0-9A-Za-z_-]+$').hasMatch(siteKey)) {
        c._update(enabled: false, loaded: true);
        return;
      }
      final web = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..addJavaScriptChannel('Captcha', onMessageReceived: (m) {
          final msg = m.message;
          if (msg.startsWith('ok:')) {
            c._update(token: msg.substring(3), failed: false);
          } else if (msg == 'expired') {
            c._update(clearToken: true);
          } else {
            c._update(clearToken: true, failed: true);
          }
        })
        ..loadHtmlString(_page(siteKey), baseUrl: appOrigin);
      c._web = web;
      c._update(enabled: true, loaded: true);
    } catch (_) {
      // Cannot ask the server: treat the check as not shown. A submit then fails with the server's own message.
      c._update(enabled: false, loaded: true, failed: true);
    }
  }

  static String _page(String siteKey) => '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>html,body{margin:0;background:transparent}body{display:flex;justify-content:center;align-items:center;min-height:70px}</style>
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=ready&render=explicit" async defer></script>
</head><body><div id="w"></div>
<script>
function ready(){
  turnstile.render('#w',{
    sitekey:'$siteKey',
    callback:function(t){Captcha.postMessage('ok:'+t)},
    'expired-callback':function(){Captcha.postMessage('expired')},
    'error-callback':function(){Captcha.postMessage('error')}
  });
}
</script></body></html>''';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        if (!c.loaded) return const SizedBox(height: 70, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        if (!c.enabled || c._web == null) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(height: 78, child: WebViewWidget(controller: c._web!)),
          if (c.failed)
            Text(
              'The check could not load. Check your connection and try again.',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
            ),
        ]);
      },
    );
  }
}
