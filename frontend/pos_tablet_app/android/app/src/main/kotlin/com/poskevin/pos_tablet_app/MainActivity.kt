package com.poskevin.pos_tablet_app

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val kioskChannel = "pos_kevin/kiosk_mode"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kioskChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isLockTaskSupported" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP)
                "isLockTaskActive" -> result.success(isLockTaskActive())
                "startLockTask" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    try {
                        startLockTask()
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                "stopLockTask" -> {
                    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) {
                        result.success(false)
                        return@setMethodCallHandler
                    }

                    try {
                        stopLockTask()
                        result.success(true)
                    } catch (_: Exception) {
                        result.success(false)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isLockTaskActive(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            activityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            @Suppress("DEPRECATION")
            activityManager.isInLockTaskMode
        }
    }
}
