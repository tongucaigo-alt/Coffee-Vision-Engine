package com.coffeeplatform.atlas_contribution_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

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
        introAudio = IntroAudioChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        traces = OpenCvTraceChannel(flutterEngine.dartExecutor.binaryMessenger)
        suitability = PhotoSuitabilityChannel(this, flutterEngine.dartExecutor.binaryMessenger)
        if (assets.list("")?.contains("atlas_screen_v5.onnx") == true) {
            imageScreen = Class.forName("com.coffeeplatform.atlas_contribution_app.LocalImageScreen")
                .getConstructor(android.app.Activity::class.java, io.flutter.plugin.common.BinaryMessenger::class.java)
                .newInstance(this, flutterEngine.dartExecutor.binaryMessenger) as java.io.Closeable
        }
    }
}
