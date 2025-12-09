package com.example.voicerecognition

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.voicerecognition/connectivity"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableWiFi" -> {
                    // Note: Direct WiFi control requires system-level permissions
                    // This is a placeholder - actual implementation would need
                    // WRITE_SETTINGS permission or system app status
                    try {
                        // Open WiFi settings as fallback
                        val intent = android.content.Intent(android.provider.Settings.ACTION_WIFI_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to open WiFi settings", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}

