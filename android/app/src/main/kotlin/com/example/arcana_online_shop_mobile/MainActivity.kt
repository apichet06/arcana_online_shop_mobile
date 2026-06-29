package com.example.arcana_online_shop_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import me.leolin.shortcutbadger.ShortcutBadger

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "arcana/app_badge")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setBadge" -> {
                        val count = call.argument<Int>("count") ?: 0
                        try {
                            if (count > 0) {
                                ShortcutBadger.applyCount(applicationContext, count)
                            } else {
                                ShortcutBadger.removeCount(applicationContext)
                            }
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("BADGE_ERROR", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
