package com.coffeeplatform.atlas_contribution_app

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

/** Read-only audio eligibility. No volume changes, focus request or permissions. */
class IntroAudioChannel(private val context: Context, messenger: BinaryMessenger) :
    EventChannel.StreamHandler, java.io.Closeable {
    private val channel = EventChannel(messenger, "atlas.app/intro_audio")
    private var sink: EventChannel.EventSink? = null
    private var registered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { publish() }
    }
    init { channel.setStreamHandler(this) }
    private fun publish() {
        val allowed = try {
            val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            audio.ringerMode == AudioManager.RINGER_MODE_NORMAL &&
                audio.getStreamVolume(AudioManager.STREAM_MUSIC) > 0 &&
                notifications.currentInterruptionFilter == NotificationManager.INTERRUPTION_FILTER_ALL
        } catch (_: Exception) { false }
        sink?.success(allowed)
    }
    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        sink = events
        val filter = IntentFilter().apply {
            addAction(AudioManager.RINGER_MODE_CHANGED_ACTION)
            addAction(NotificationManager.ACTION_INTERRUPTION_FILTER_CHANGED)
        }
        try {
            if (Build.VERSION.SDK_INT >= 33) context.registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            else {
                @Suppress("DEPRECATION")
                context.registerReceiver(receiver, filter)
            }
            registered = true
            publish()
        } catch (_: Exception) { sink?.success(false) }
    }
    override fun onCancel(arguments: Any?) {
        if (registered) { context.unregisterReceiver(receiver); registered = false }
        sink = null
    }
    override fun close() { onCancel(null); channel.setStreamHandler(null) }
}
