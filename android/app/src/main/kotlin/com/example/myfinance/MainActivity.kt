package com.example.myfinance

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val channel = "com.example.myfinance/gpay"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                val prefs = getSharedPreferences("myfinance_prefs", Context.MODE_PRIVATE)
                when (call.method) {

                    "checkGPayClosed" -> {
                        val closed = prefs.getBoolean("gpay_just_closed", false)
                        if (closed) prefs.edit().putBoolean("gpay_just_closed", false).apply()
                        result.success(closed)
                    }

                    "getPendingAction" -> {
                        val action = prefs.getString("pending_action", null)
                        if (action != null) prefs.edit().remove("pending_action").apply()
                        result.success(action)
                    }

                    "getPendingPersonalExpenses" -> {
                        val raw = prefs.getString("pending_personal_expenses", "") ?: ""
                        if (raw.isNotEmpty()) {
                            prefs.edit().remove("pending_personal_expenses").apply()
                        }
                        // Return list of amounts as comma-separated string
                        result.success(raw)
                    }

                    "openAccessibilitySettings" -> {
                        val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(null)
                    }

                    "isAccessibilityEnabled" -> {
                        result.success(isAccessibilityServiceEnabled())
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        val serviceName = "$packageName/${GPayWatcherService::class.java.name}"
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false
        return enabledServices.split(":").any { it.equals(serviceName, ignoreCase = true) }
    }
}
