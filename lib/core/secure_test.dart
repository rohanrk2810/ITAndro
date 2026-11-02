import 'dart:io';

import 'package:flutter/services.dart';

/// Android-only lock-down for a secure test: screen pinning plus no screenshots. Elsewhere it does nothing.
class SecureTest {
  static const _channel = MethodChannel('itilms/secure_test');

  static bool get supported => Platform.isAndroid;

  static Future<void> enter() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('enter');
    } catch (_) {}
  }

  static Future<void> exit() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('exit');
    } catch (_) {}
  }

  /// True while the app is pinned. Unknown (a failed call) counts as pinned, so a glitch never accuses anyone.
  static Future<bool> isPinned() async {
    if (!supported) return true;
    try {
      return await _channel.invokeMethod<bool>('isPinned') ?? true;
    } catch (_) {
      return true;
    }
  }
}
