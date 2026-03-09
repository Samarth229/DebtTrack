package com.example.myfinance

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.view.accessibility.AccessibilityEvent

class GPayWatcherService : AccessibilityService() {

    private var wasGPayActive = false
    private val gPayPackage = "com.google.android.apps.nbu.paisa.user"

    override fun onServiceConnected() {
        val info = AccessibilityServiceInfo()
        info.eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED
        info.feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
        info.notificationTimeout = 100
        serviceInfo = info
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        if (event.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val packageName = event.packageName?.toString() ?: return

        if (packageName == gPayPackage) {
            wasGPayActive = true
        } else if (wasGPayActive) {
            wasGPayActive = false
            onGPayClosed()
        }
    }

    private fun onGPayClosed() {
        // Launch transparent PaymentDialogActivity directly — no notification tap needed
        try {
            val intent = Intent(this, PaymentDialogActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
        } catch (_: Exception) {
            // If direct launch is restricted (Android 10+ background limit),
            // fall back to nothing — user opens app manually
        }
    }

    override fun onInterrupt() {}
}
