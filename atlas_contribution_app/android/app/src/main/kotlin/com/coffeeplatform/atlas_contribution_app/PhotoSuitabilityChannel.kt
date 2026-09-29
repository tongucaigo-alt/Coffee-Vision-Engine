package com.coffeeplatform.atlas_contribution_app

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.imageclassifier.ImageClassifier
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** One worker serializes native inference; no image is sent over a network. */
class PhotoSuitabilityChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private var classifier: ImageClassifier? = null
    private val channel = MethodChannel(messenger, "atlas.photo/suitability")
    fun close() {
        channel.setMethodCallHandler(null)
        worker.execute { classifier?.close(); classifier = null }
        worker.shutdown()
    }
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "classify") { result.notImplemented(); return@setMethodCallHandler }
            worker.execute {
                try {
                    val source = File(requireNotNull(call.argument<String>("path"))).canonicalFile
                    val roots = listOf(activity.filesDir.parentFile!!, activity.cacheDir)
                    val diagnostic = activity.packageName.endsWith(".diagnostic") &&
                        source.path.startsWith("/data/local/tmp/atlas-suitability/")
                    require(source.isFile && (diagnostic || roots.any { source.path.startsWith(it.canonicalPath + File.separator) }))
                    val crop = requireNotNull(call.argument<List<Double>>("crop"))
                    require(crop.size == 4 && crop.all { it.isFinite() } && crop[0] >= 0 && crop[1] >= 0 && crop[2] > 0 && crop[3] > 0 && crop[0]+crop[2] <= 1.000001 && crop[1]+crop[3] <= 1.000001)
                    val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    BitmapFactory.decodeFile(source.path, options)
                    require(options.outWidth > 0 && options.outHeight > 0)
                    options.inJustDecodeBounds = false
                    options.inPreferredConfig = Bitmap.Config.ARGB_8888
                    while (options.outWidth/options.inSampleSize.coerceAtLeast(1) > 2048 || options.outHeight/options.inSampleSize.coerceAtLeast(1) > 2048) {
                        options.inSampleSize = options.inSampleSize.coerceAtLeast(1) * 2
                    }
                    val bitmap = requireNotNull(BitmapFactory.decodeFile(source.path, options))
                    try {
                        val x = (crop[0]*bitmap.width).toInt().coerceIn(0, bitmap.width-1)
                        val y = (crop[1]*bitmap.height).toInt().coerceIn(0, bitmap.height-1)
                        val w = (crop[2]*bitmap.width).toInt().coerceIn(1, bitmap.width-x)
                        val h = (crop[3]*bitmap.height).toInt().coerceIn(1, bitmap.height-y)
                        val cropped = Bitmap.createBitmap(bitmap,x,y,w,h)
                        val response = try { mapOf("full" to classify(bitmap), "crop" to classify(cropped)) }
                        finally { if (cropped !== bitmap) cropped.recycle() }
                        activity.runOnUiThread { result.success(response) }
                    } finally { bitmap.recycle() }
                } catch (_: Exception) {
                    activity.runOnUiThread { result.error("classification_failed", "Fotoğraf kontrolü tamamlanamadı.", null) }
                }
            }
        }
    }
    private fun classify(bitmap: Bitmap): List<Map<String, Any>> {
        val engine = classifier ?: ImageClassifier.createFromOptions(activity.applicationContext,
            ImageClassifier.ImageClassifierOptions.builder()
                .setBaseOptions(BaseOptions.builder().setModelAssetPath("efficientnet_lite0.tflite").build())
                .setRunningMode(RunningMode.IMAGE).setMaxResults(3).build()).also { classifier = it }
        val image = BitmapImageBuilder(bitmap.copy(Bitmap.Config.ARGB_8888, false)).build()
        return try { engine.classify(image).classificationResult().classifications().flatMap { it.categories() }
            .map { mapOf("label" to it.categoryName(), "score" to it.score().toDouble()) } }
        finally { image.close() }
    }
}
