package com.coffeeplatform.atlas_contribution_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import android.content.Intent
import android.net.Uri
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var introAudio: IntroAudioChannel? = null
    private var imageScreen: java.io.Closeable? = null
    private var traces: OpenCvTraceChannel? = null
    private var suitability: PhotoSuitabilityChannel? = null
    override fun onDestroy() {
        introAudio?.close()
        introAudio = null
        traces?.close()
        traces = null
        imageScreen?.close()
        imageScreen = null
        suitability?.close()
        suitability = null
        super.onDestroy()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "atlas.app/links").setMethodCallHandler { call, result ->
            if (call.method != "open") { result.notImplemented(); return@setMethodCallHandler }
            val uri = call.argument<String>("url")?.let(Uri::parse)
            val allowed = uri != null && ((uri.scheme == "https" && !uri.host.isNullOrBlank() && uri.userInfo == null) ||
                (uri.scheme == "mailto" && !uri.schemeSpecificPart.contains('\n') && !uri.schemeSpecificPart.contains('\r')))
            if (!allowed) { result.error("invalid_link", "Adres açılamadı.", null); return@setMethodCallHandler }
            try { startActivity(Intent(Intent.ACTION_VIEW, uri)); result.success(true) }
            catch (_: android.content.ActivityNotFoundException) { result.success(false) }
        }
        introAudio = IntroAudioChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        traces = OpenCvTraceChannel(flutterEngine.dartExecutor.binaryMessenger)
        suitability = PhotoSuitabilityChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        if (assets.list("")?.contains("atlas_screen_v6.onnx") == true) {
            imageScreen = Class.forName("com.coffeeplatform.atlas_contribution_app.LocalImageScreen")
                .getConstructor(android.app.Activity::class.java, io.flutter.plugin.common.BinaryMessenger::class.java)
                .newInstance(this, flutterEngine.dartExecutor.binaryMessenger) as java.io.Closeable
        }
    }
}
