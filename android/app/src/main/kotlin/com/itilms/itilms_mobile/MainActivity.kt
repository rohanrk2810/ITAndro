package com.itilms.itilms_mobile

import android.app.ActivityManager
import android.content.Context
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Secure test support. `enter` pins the app (screen pinning, the system asks the student to confirm) and blocks
 * screenshots and screen recording; `exit` undoes both; `isPinned` lets the app notice the student unpinned it.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "itilms/secure_test").setMethodCallHandler { call, result ->
            when (call.method) {
                "enter" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    try {
                        startLockTask()
                    } catch (_: Exception) {
                        // Pinning refused by the device: the lifecycle checks in the app still report leaving.
                    }
                    result.success(null)
                }
                "exit" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    try {
                        stopLockTask()
                    } catch (_: Exception) {
                        // Not pinned: nothing to undo.
                    }
                    result.success(null)
                }
                "isPinned" -> {
                    val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    result.success(am.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE)
                }
                else -> result.notImplemented()
            }
        }
    }
}
