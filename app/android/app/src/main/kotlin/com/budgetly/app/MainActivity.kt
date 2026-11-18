package com.budgetly.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the Flutter engine and bridges Android deep-link intents to Dart.
 *
 * Flutter's built-in `getInitialRoute()` only reflects the launcher intent's
 * data on some OEMs, and never sees VIEW intents delivered while the app is
 * already running. So we expose our own channel that returns:
 *   - `initialLink`  : the data URI from the intent that started the activity
 *   - `onLink` events: every subsequent VIEW intent (onNewIntent)
 */
class MainActivity : FlutterActivity() {

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null

    /** Retained so late-subscribed Dart code still gets the cold-start link. */
    private var pendingLink: String? = null

    /** Non-null once Dart has subscribed to the event stream. */
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialLink" -> result.success(pendingLink ?: intent?.data?.toString())
                else -> result.notImplemented()
            }
        }

        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENTS)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                // Flush anything that arrived before Dart subscribed.
                pendingLink?.let { events?.success(it) }
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Capture a cold-start VIEW intent right away.
        intent?.data?.toString()?.takeIf(::isJoinLink)?.let { pendingLink = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.data?.toString()?.takeIf(::isJoinLink)?.let(::dispatchLink)
    }

    /** Only join links are interesting to the Flutter side. */
    private fun isJoinLink(uri: String): Boolean {
        return uri.startsWith("budgetly://join") || uri.contains("/join")
    }

    private fun dispatchLink(uri: String) {
        pendingLink = uri
        eventSink?.success(uri)
    }

    override fun onDestroy() {
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        eventSink = null
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "budgetly/deep_link"
        private const val EVENTS = "budgetly/deep_link/events"
    }
}