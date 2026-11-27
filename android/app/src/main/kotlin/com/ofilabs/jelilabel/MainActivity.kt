package com.ofilabs.jelilabel

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
    private fun isHealthPermissionIntent(intent: Intent?): Boolean {
        val action = intent?.action ?: return false
        return action == "androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" ||
            action == "android.intent.action.VIEW_PERMISSION_USAGE"
    }

    override fun getInitialRoute(): String? {
        if (isHealthPermissionIntent(intent)) {
            return "/aktivitas/izin"
        }
        return super.getInitialRoute()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (isHealthPermissionIntent(intent)) {
            flutterEngine?.navigationChannel?.pushRouteInformation("/aktivitas/izin")
        }
    }
}
