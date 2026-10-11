package com.coffeeplatform.atlas_contribution_app

import android.app.Activity
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.view.WindowManager
import androidx.exifinterface.media.ExifInterface
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.Closeable
import java.io.File
import java.nio.FloatBuffer
import java.security.MessageDigest
import java.util.concurrent.Executors

/** Local image screening. No images leave the device. */
class LocalImageScreen(private val activity: Activity, messenger: BinaryMessenger) : Closeable {
    private val worker = Executors.newSingleThreadExecutor()
    private val channel = MethodChannel(messenger, "atlas.photo/image_screen")
    private val environment = OrtEnvironment.getEnvironment()
    private var session: OrtSession? = null
    private val modelHash = "17cb073e902c459ebc04fe9b14a2ba10ec968a4c378c40fbd8199f7c5b0ff5d4"
    init {

        if (activity.packageName.endsWith(".diagnostic")) activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        channel.setMethodCallHandler { call, result ->
            if (call.method != "assess") { result.notImplemented(); return@setMethodCallHandler }
            worker.execute {
                try {
                    val source = File(requireNotNull(call.argument<String>("path"))).canonicalFile
                    require(source.isFile && source.path.startsWith(activity.filesDir.parentFile!!.canonicalPath + File.separator))
                    val crop = requireNotNull(call.argument<List<Double>>("crop"))
                    require(crop.size == 4 && crop.all { it.isFinite() } && crop[0] >= 0 && crop[1] >= 0 && crop[2] > 0 && crop[3] > 0 && crop[0]+crop[2] <= 1.000001 && crop[1]+crop[3] <= 1.000001)
                    val raw = requireNotNull(BitmapFactory.decodeFile(source.path))
                    val oriented = orient(raw, source.path)
                    try {
                        val x = (crop[0]*oriented.width).toInt().coerceIn(0, oriented.width-1)
                        val y = (crop[1]*oriented.height).toInt().coerceIn(0, oriented.height-1)
                        val w = (crop[2]*oriented.width).toInt().coerceIn(1, oriented.width-x)
                        val h = (crop[3]*oriented.height).toInt().coerceIn(1, oriented.height-y)
                        val view = Bitmap.createBitmap(oriented, x, y, w, h)
                        val measurements = try { listOf(score(oriented), score(view)) }
                        finally { if (view !== oriented) view.recycle() }
                        activity.runOnUiThread { result.success(mapOf("scores" to measurements.map { it.first }, "preprocessSha256" to measurements.map { it.second }, "modelSha256" to modelHash)) }
                    } finally { if (oriented !== raw) oriented.recycle(); raw.recycle() }
                } catch (error: Exception) {
                    android.util.Log.w("AtlasImageScreen", error.javaClass.simpleName)
                    activity.runOnUiThread { result.error("screen_failed", "Fotoğraf kontrolü tamamlanamadı.", null) }
                }
            }
        }
    }
    private fun orient(bitmap: Bitmap, path: String): Bitmap {
        val value = ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)
        val matrix = Matrix()
        when (value) {
            2 -> matrix.setScale(-1f, 1f)
            3 -> matrix.setRotate(180f)
            4 -> matrix.setScale(1f, -1f)
            5 -> { matrix.setRotate(90f); matrix.postScale(-1f, 1f) }
            6 -> matrix.setRotate(90f)
            7 -> { matrix.setRotate(270f); matrix.postScale(-1f, 1f) }
            8 -> matrix.setRotate(270f)
            else -> return bitmap
        }
        return Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
    }
    /** Separable antialiased bilinear resampling, matching Pillow's RGB path.
     * Android's two-tap scaling drops thin grounds when reducing large photos. */
    private fun resizeRgb(bitmap: Bitmap): ByteArray {
        data class Kernel(val start: Int, val weights: IntArray)
        fun kernels(length: Int): List<Kernel> {
            val scale = length / 224.0
            val support = maxOf(1.0, scale)
            return (0 until 224).map { out ->
                val center = (out + .5) * scale
                val start = (center - support + .5).toInt().coerceAtLeast(0)
                val end = (center + support + .5).toInt().coerceAtMost(length)
                val weights = (start until end).map { i -> maxOf(0.0, 1.0 - kotlin.math.abs((i + .5 - center) / support)) }
                val sum = weights.sum()
                Kernel(start, weights.map { (it / sum * (1 shl 22) + .5).toInt() }.toIntArray())
            }
        }
        val horizontal = kernels(bitmap.width)
        val vertical = kernels(bitmap.height)
        val intermediate = ByteArray(224 * bitmap.height * 3)
        val row = IntArray(bitmap.width)
        for (y in 0 until bitmap.height) {
            bitmap.getPixels(row, 0, bitmap.width, 0, y, bitmap.width, 1)
            for (x in 0 until 224) for (c in 0..2) {
                val kernel = horizontal[x]
                var sum = 1L shl 21
                for (j in kernel.weights.indices) sum += ((row[kernel.start+j] shr (16-c*8)) and 255).toLong() * kernel.weights[j]
                intermediate[(y*224+x)*3+c] = (sum shr 22).coerceIn(0,255).toByte()
            }
        }
        val result = ByteArray(224*224*3)
        for (y in 0 until 224) for (x in 0 until 224) for (c in 0..2) {
            val kernel = vertical[y]
            var sum = 1L shl 21
            for (j in kernel.weights.indices) sum += (intermediate[((kernel.start+j)*224+x)*3+c].toInt() and 255).toLong() * kernel.weights[j]
            result[(y*224+x)*3+c] = (sum shr 22).coerceIn(0,255).toByte()
        }
        return result
    }
    private fun score(bitmap: Bitmap): Pair<Double, String> {
        val engine = session ?: run {
            val bytes = activity.assets.open("atlas_screen_v5.onnx").use { it.readBytes() }
            val hash = MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it.toInt() and 255) }
            require(hash == modelHash)
            val options = OrtSession.SessionOptions()
            options.setIntraOpNumThreads(2)
            try { environment.createSession(bytes, options).also { session = it } } finally { options.close() }
        }
        val pixels = resizeRgb(bitmap)
        val pixelCount = 224*224
        val inputHash = MessageDigest.getInstance("SHA-256").digest(pixels).joinToString("") { "%02x".format(it.toInt() and 255) }
        val values = FloatArray(3*224*224)
        val means = floatArrayOf(.485f, .456f, .406f)
        val deviations = floatArrayOf(.229f, .224f, .225f)
        for (c in 0..2) for (i in 0 until pixelCount) {
            val v = pixels[i*3+c].toInt() and 255
            values[c*pixelCount+i] = (v/255f-means[c])/deviations[c]
        }
        OnnxTensor.createTensor(environment, FloatBuffer.wrap(values), longArrayOf(1, 3, 224, 224)).use { tensor ->
            engine.run(mapOf("image" to tensor)).use { output ->
                val score = (output[0].value as FloatArray)[0].toDouble()
                require(score.isFinite())
                return Pair(score, inputHash)
            }
        }
    }
    override fun close() {
        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        channel.setMethodCallHandler(null)
        worker.execute { session?.close(); session = null }
        worker.shutdown()
    }
}
