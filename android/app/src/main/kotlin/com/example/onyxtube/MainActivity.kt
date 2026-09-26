package com.example.onyxtube

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.horis.cncverse.CNCVersePlugin

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.horis.cncverse/stream"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStreamUrl" -> {
                    val title = call.argument("title") ?: ""
                    val mediaType = call.argument("mediaType") ?: "movie"
                    val provider = call.argument("provider") ?: "netmirror"
                    val season = call.argument("season") ?: 1
                    val episode = call.argument("episode") ?: 1

                    // Call Native Kotlin Provider
                    try {
                        val streamUrl = CNCVersePlugin.fetchStreamUrl(provider, title, mediaType, season, episode)
                        if (streamUrl != null) {
                            result.success(streamUrl)
                        } else {
                            result.error("NOT_FOUND", "Stream URL not found on $provider", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", e.localizedMessage, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}