import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../auth/auth_service.dart';
import '../core/env.dart';

const _tokenKey = 'itilms.refreshToken';

/// Runs on every page load. A WebView cannot save a file made in the page (a blob: link) or open a new window, so
/// both are handed to the app: downloads go to the "Download" channel, outside links to "Native".
const _bridgeScript = r'''
(function () {
  if (window.__svBridge) return;
  window.__svBridge = true;
  function sendBlob(href, name) {
    fetch(href).then(function (r) { return r.blob(); }).then(function (b) {
      var fr = new FileReader();
      fr.onload = function () {
        Download.postMessage(JSON.stringify({ name: name || 'download', mime: b.type, data: String(fr.result).split(',')[1] || '' }));
      };
      fr.readAsDataURL(b);
    });
  }
  var click = HTMLAnchorElement.prototype.click;
  HTMLAnchorElement.prototype.click = function () {
    if (this.href && this.href.indexOf('blob:') === 0) {
      sendBlob(this.href, this.getAttribute('download'));
      return;
    }
    return click.apply(this, arguments);
  };
  document.addEventListener('click', function (e) {
    var a = e.target && e.target.closest ? e.target.closest('a') : null;
    if (!a || !a.href) return;
    if (a.href.indexOf('blob:') === 0) {
      e.preventDefault();
      sendBlob(a.href, a.getAttribute('download'));
    } else if (a.target === '_blank' && a.href.indexOf(location.origin) !== 0) {
      e.preventDefault();
      Native.postMessage('open:' + a.href);
    }
  }, true);
  window.open = function (url) {
    if (!url) return null;
    var u = String(url);
    if (u.indexOf('blob:') === 0) sendBlob(u, '');
    else if (u.indexOf(location.origin) === 0 || u.charAt(0) === '/') location.href = u;
    else Native.postMessage('open:' + u);
    return null;
  };
})();
''';

/// The whole IT-ILMS website, signed in as the person who just logged in, filling the screen. Every feature of the
/// web app is therefore in the app: the app only adds what a browser tab cannot (camera and file permissions,
/// saving and opening files, keeping the person signed in).
class SiteScreen extends StatefulWidget {
  const SiteScreen({super.key});

  @override
  State<SiteScreen> createState() => _SiteScreenState();
}

class _SiteScreenState extends State<SiteScreen> {
  late final WebViewController _web;
  late final AuthService _auth;
  Timer? _watch;
  String _latest = '';
  bool _ready = false;
  bool _loading = true;
  bool _failed = false;
  bool _seenApp = false;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    // The website now owns the rotating refresh token; the app must not spend it behind its back.
    _auth.webHolds++;
    _start();
  }

  Future<void> _start() async {
    final token = await _auth.readRefreshToken();
    _latest = token ?? '';
    // The site signs in from a stored refresh token, so hand it the app's one before the site boots.
    final html = '<!doctype html><script>'
        'try{localStorage.setItem(${jsonEncode(_tokenKey)},${jsonEncode(_latest)});}catch(e){}'
        'location.replace(${jsonEncode('$appOrigin/app')});'
        '</script>';
    final web = WebViewController(onPermissionRequest: _onPermission)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('Download', onMessageReceived: (m) => _saveDownload(m.message))
      ..addJavaScriptChannel('Native', onMessageReceived: (m) {
        if (m.message.startsWith('open:')) _openOutside(m.message.substring(5));
      })
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) {
            setState(() {
              _loading = true;
              _failed = false;
            });
          }
        },
        onPageFinished: (url) {
          _web.runJavaScript(_bridgeScript);
          if (mounted) setState(() => _loading = false);
        },
        onUrlChange: (change) => _onUrl(change.url ?? ''),
        onWebResourceError: (e) {
          if (e.isForMainFrame ?? false) {
            if (mounted) setState(() => _failed = true);
          }
        },
        onNavigationRequest: (req) {
          final host = Uri.tryParse(req.url)?.host ?? '';
          final own = <String>{Uri.parse(appOrigin).host, Uri.parse(apiBaseUrl).host};
          final inside = req.url.startsWith('about:') || req.url.startsWith('data:') || req.url.startsWith('blob:') || own.contains(host);
          // Frames inside a page (a Jitsi room, a video) load freely; leaving the site for another one opens outside.
          if (inside || !req.isMainFrame) return NavigationDecision.navigate;
          _openOutside(req.url);
          return NavigationDecision.prevent;
        },
      ))
      ..loadHtmlString(html, baseUrl: appOrigin);

    final platform = web.platform;
    if (platform is AndroidWebViewController) {
      await platform.setMediaPlaybackRequiresUserGesture(false);
      await platform.setOnShowFileSelector(_pickFiles);
    }
    _web = web;
    // The site rotates the token as it boots and as it runs: keep the newest copy so the app stays signed in.
    _watch = Timer.periodic(const Duration(seconds: 5), (_) => _snapshot());
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _snapshot() async {
    try {
      final raw = await _web.runJavaScriptReturningResult('localStorage.getItem(${jsonEncode(_tokenKey)}) || ""');
      var token = raw.toString();
      if (token.startsWith('"')) token = jsonDecode(token) as String;
      if (token.isNotEmpty && token != _latest) {
        _latest = token;
        await _auth.rememberRefreshToken(token);
      }
    } catch (_) {
      // The page is between loads: the next tick tries again.
    }
  }

  /// The site asked for the camera or microphone (face check, live class, video lesson): ask the phone, then answer.
  Future<void> _onPermission(WebViewPermissionRequest request) async {
    final needs = <Permission>[
      if (request.types.contains(WebViewPermissionResourceType.camera)) Permission.camera,
      if (request.types.contains(WebViewPermissionResourceType.microphone)) Permission.microphone,
    ];
    final results = await needs.request();
    if (results.values.every((s) => s.isGranted)) {
      await request.grant();
    } else {
      await request.deny();
    }
  }

  /// An <input type=file> in the site: open the phone's picker and give back what was chosen.
  Future<List<String>> _pickFiles(FileSelectorParams params) async {
    final picked = await FilePicker.platform.pickFiles(allowMultiple: params.mode == FileSelectorMode.openMultiple);
    if (picked == null) return const [];
    return [for (final f in picked.files) if (f.path != null) Uri.file(f.path!).toString()];
  }

  Future<void> _saveDownload(String message) async {
    try {
      final m = jsonDecode(message) as Map<String, dynamic>;
      final bytes = base64Decode(m['data'] as String);
      var name = (m['name'] as String? ?? '').replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      if (name.isEmpty) name = 'sutravidya-file${_extensionFor(m['mime'] as String? ?? '')}';
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${DateTime.now().millisecondsSinceEpoch}_$name');
      await file.writeAsBytes(bytes);
      final res = await OpenFilex.open(file.path);
      if (res.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No app on this phone can open this file.')));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save the file.')));
    }
  }

  String _extensionFor(String mime) {
    if (mime.contains('pdf')) return '.pdf';
    if (mime.contains('csv')) return '.csv';
    if (mime.contains('png')) return '.png';
    if (mime.contains('jpeg')) return '.jpg';
    if (mime.contains('spreadsheet')) return '.xlsx';
    return '';
  }

  Future<void> _openOutside(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http' || uri.scheme == 'mailto' || uri.scheme == 'tel')) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// The site sends a signed-out person to /login: sign out of the app too, so both agree.
  void _onUrl(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    if (path.startsWith('/app')) {
      _seenApp = true;
    } else if (_seenApp && (path == '/login' || path.startsWith('/login/'))) {
      _auth.logout();
    }
  }

  @override
  void dispose() {
    _watch?.cancel();
    _auth.webHolds--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_ready && await _web.canGoBack()) {
          await _web.goBack();
        } else {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              if (_ready && !_failed) WebViewWidget(controller: _web),
              if (_failed)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.cloud_off, size: 48),
                      const SizedBox(height: 12),
                      const Text('Cannot reach SutraVidya. Check the connection.', textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () {
                          setState(() => _failed = false);
                          _web.loadHtmlString(
                            '<!doctype html><script>location.replace(${jsonEncode('$appOrigin/app')});</script>',
                            baseUrl: appOrigin,
                          );
                        },
                        child: const Text('Try again'),
                      ),
                      TextButton(onPressed: () => _auth.logout(), child: const Text('Sign out')),
                    ]),
                  ),
                ),
              if (_loading || !_ready) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
