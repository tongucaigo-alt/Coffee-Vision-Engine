package com.coffeeplatform.atlas_contribution_app

import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.opencv.android.OpenCVLoader
import org.opencv.android.Utils
import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import java.util.concurrent.Executors
import kotlin.math.*

/** Receives already oriented/cropped, bounded-size pixels; never reads user files. */
class OpenCvTraceChannel(messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val channel = MethodChannel(messenger, "atlas.opencv/traces")
    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "analyze") { result.notImplemented(); return@setMethodCallHandler }
            val bytes = call.argument<ByteArray>("png")
            if (bytes == null || bytes.size > 4 * 1024 * 1024) {
                result.error("invalid_image", "Invalid working image", null)
                return@setMethodCallHandler
            }
            worker.execute {
                try {
                    val value = analyze(bytes)
                    main.post { result.success(value) }
                } catch (error: Throwable) {
                    main.post { result.error("analysis_failed", error.javaClass.simpleName, null) }
                }
            }
        }
    }
    fun close() { channel.setMethodCallHandler(null); worker.shutdown() }

    private fun analyze(bytes: ByteArray): Map<String, Any> {
        check(OpenCVLoader.initLocal())
        val started = System.nanoTime()
        val bitmap = requireNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size))
        require(bitmap.width in 41..512 && bitmap.height in 41..512)
        val owned = mutableListOf<Mat>()
        fun mat() = Mat().also { owned.add(it) }
        val clahe = Imgproc.createCLAHE(2.0, Size(8.0, 8.0))
        try {
            val rgba = mat(); val gray = mat(); val enhanced = mat(); val mask = mat()
            Utils.bitmapToMat(bitmap, rgba)
            Imgproc.cvtColor(rgba, gray, Imgproc.COLOR_RGBA2GRAY)
            clahe.apply(gray, enhanced)
            Imgproc.adaptiveThreshold(enhanced, mask, 255.0,
                Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C, Imgproc.THRESH_BINARY_INV, 41, 12.0)
            val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(3.0, 3.0))
            owned.add(kernel)
            Imgproc.morphologyEx(mask, mask, Imgproc.MORPH_OPEN, kernel)
            Imgproc.morphologyEx(mask, mask, Imgproc.MORPH_CLOSE, kernel)
            val w = mask.cols(); val h = mask.rows()
            val domain = Mat.zeros(h, w, CvType.CV_8U); owned.add(domain)
            // Match the desktop experiment's elliptical domain, pixel centers included.
            val domainBytes = ByteArray(w * h)
            var domainSize = 0
            for (y in 0 until h) for (x in 0 until w) {
                if (((x + .5) / w - .5).pow(2) / .25 +
                    ((y + .5) / h - .5).pow(2) / .25 <= 1.0) {
                    domainBytes[y * w + x] = 255.toByte(); domainSize++
                }
            }
            domain.put(0, 0, domainBytes)
            Core.bitwise_and(mask, domain, mask)
            val labels = mat(); val stats = mat(); val centroids = mat()
            val count = Imgproc.connectedComponentsWithStats(mask, labels, stats, centroids, 8, CvType.CV_32S)
            val labelPixels = IntArray(w * h); labels.get(0, 0, labelPixels)
            val candidates = mutableListOf<Map<String, Any>>()
            for (id in 1 until count) {
                val area = stats.get(id, Imgproc.CC_STAT_AREA)[0]
                val x = stats.get(id, Imgproc.CC_STAT_LEFT)[0].toInt()
                val y = stats.get(id, Imgproc.CC_STAT_TOP)[0].toInt()
                val bw = stats.get(id, Imgproc.CC_STAT_WIDTH)[0].toInt()
                val bh = stats.get(id, Imgproc.CC_STAT_HEIGHT)[0].toInt()
                val fill = area / (bw * bh)
                val nx = (centroids.get(id, 0)[0] + .5) / w
                val ny = (centroids.get(id, 1)[0] + .5) / h
                if (area < 70 || area > domainSize * .12 || bw < 8 || bh < 8 || fill < .12) continue
                if (((nx - .5) / .40).pow(2) + ((ny - .5) / .40).pow(2) >= 1) continue
                val pixels = mutableListOf<Int>(); val boundary = mutableListOf<Int>()
                val signature = IntArray(64)
                for (py in y until y + bh) for (px in x until x + bw) {
                    val index = py * w + px
                    if (labelPixels[index] != id) continue
                    pixels.add(index)
                    signature[min(7, (py - y) * 8 / bh) * 8 + min(7, (px - x) * 8 / bw)]++
                    if (px == 0 || py == 0 || px == w - 1 || py == h - 1 ||
                        labelPixels[index - 1] != id || labelPixels[index + 1] != id ||
                        labelPixels[index - w] != id || labelPixels[index + w] != id) boundary.add(index)
                }
                candidates.add(mapOf("id" to id, "pixels" to pixels.toIntArray(),
                    "boundary" to boundary.toIntArray(), "box" to listOf(x, y, bw, bh),
                    "score" to sqrt(area) * (1 - fill * .3),
                    "signature" to signature.toList(), "aspect" to bw.toDouble() / bh))
            }
            return mapOf("width" to w, "height" to h,
                "candidates" to candidates.sortedByDescending { it["score"] as Double }.take(24),
                "durationMs" to (System.nanoTime() - started) / 1_000_000)
        } finally {
            owned.forEach { it.release() }; clahe.collectGarbage(); bitmap.recycle()
        }
    }
}
