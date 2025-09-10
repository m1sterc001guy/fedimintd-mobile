package org.fedimint.mobile

import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "org.fedimint.mobile/settings"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "openBatterySettings") {
                try {
                    val intent = Intent()
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        intent.action = Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS
                    } else {
                        intent.action = Settings.ACTION_SETTINGS
                    }
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(null)
                } catch (e: Exception) {
                    result.error("UNAVAILABLE", "Could not open settings", e.message)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
