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
                    // Comparison input is used by the isolated diagnostic harness only.
                    val comparisonClip = call.argument<Number>("comparisonClip")?.toDouble()
                    val value = if (call.argument<Boolean>("legacyDomain") == true) {
                        extract(bytes, 2.0, false)
                    } else if (comparisonClip == 1.0 || comparisonClip == 3.0) {
                        extract(bytes, comparisonClip)
                    } else analyze(bytes, call.argument<Boolean>("adaptive") == true,
                        (call.argument<Number>("extraBudgetMs")?.toLong() ?: 500L).coerceIn(0L, 500L))
                    main.post { result.success(value) }
                } catch (error: Throwable) {
                    main.post { result.error("analysis_failed", error.javaClass.simpleName, null) }
                }
            }
        }
    }
    fun close() { channel.setMethodCallHandler(null); worker.shutdown() }

    private fun extract(bytes: ByteArray, clip: Double = 2.0, cupDomain: Boolean = true): Map<String, Any> {
        check(OpenCVLoader.initLocal())
        val started = System.nanoTime()
        val bitmap = requireNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size))
        require(bitmap.width in 41..512 && bitmap.height in 41..512)
        val owned = mutableListOf<Mat>()
        fun mat() = Mat().also { owned.add(it) }
        val clahe = Imgproc.createCLAHE(clip, Size(8.0, 8.0))
        try {
            val rgba = mat(); val gray = mat(); val enhanced = mat(); val mask = mat()
            Utils.bitmapToMat(bitmap, rgba)
            Imgproc.cvtColor(rgba, gray, Imgproc.COLOR_RGBA2GRAY)
            clahe.apply(gray, enhanced)
            Imgproc.adaptiveThreshold(enhanced, mask, 255.0,
                Imgproc.ADAPTIVE_THRESH_GAUSSIAN_C, Imgproc.THRESH_BINARY_INV, 41, 12.0)
            val detected = if (cupDomain) OpenCvCupDomain.detect(gray, rgba) else null
            if (detected != null) owned.add(detected.mask)
            if (detected != null) {
                val levels = ByteArray(gray.rows()*gray.cols()); gray.get(0,0,levels)
                val colors = ByteArray(levels.size*4); rgba.get(0,0,colors)
                val region = ByteArray(levels.size); detected.mask.get(0,0,region)
                val foreground = ByteArray(levels.size); mask.get(0,0,foreground)
                val histogram = IntArray(256); var count = 0
                for (i in levels.indices) if (region[i].toInt()!=0) {
                    histogram[levels[i].toInt() and 255]++; count++
                }
                var cumulative = 0; var p90 = 255
                for (v in histogram.indices) {
                    cumulative += histogram[v]
                    if (count>0 && cumulative>=ceil(count*.9)) { p90=v; break }
                }
                val darkLimit = min(80.0,p90*.4)
                for (i in levels.indices) {
                    val r=colors[i*4].toInt() and 255; val g=colors[i*4+1].toInt() and 255
                    val b=colors[i*4+2].toInt() and 255; val level=levels[i].toInt() and 255
                    val maxChannel=max(r,max(g,b)); val minChannel=min(r,min(g,b))
                    val saturation=if(maxChannel==0) 0.0 else 255.0*(maxChannel-minChannel)/maxChannel
                    val coffee=(r>b+6 && r>=g-3 && saturation>30 && level<160) ||
                        (level<70 && r>=g && r>b+2 && saturation>20)
                    foreground[i]=if(region[i].toInt()==0 || !coffee) 0 else
                        if(level<darkLimit) 255.toByte() else foreground[i]
                }
                mask.put(0,0,foreground)
            }
            val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(3.0, 3.0))
            owned.add(kernel)
            Imgproc.morphologyEx(mask, mask, Imgproc.MORPH_OPEN, kernel)
            Imgproc.morphologyEx(mask, mask, Imgproc.MORPH_CLOSE, kernel)
            val w = mask.cols(); val h = mask.rows()
            val domain = detected?.mask ?: Mat.zeros(h, w, CvType.CV_8U).also { owned.add(it) }
            // Match the desktop experiment's elliptical domain, pixel centers included.
            val domainBytes = ByteArray(w * h)
            var domainSize = 0
            if (detected != null) {
                domain.get(0,0,domainBytes)
                domainSize=Core.countNonZero(domain)
            } else for (y in 0 until h) for (x in 0 until w) {
                if (((x + .5) / w - .5).pow(2) / .25 +
                    ((y + .5) / h - .5).pow(2) / .25 <= 1.0) {
                    domainBytes[y * w + x] = 255.toByte(); domainSize++
                }
            }
            if (detected == null) domain.put(0, 0, domainBytes)
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
                if (detected == null && (((nx - .5) / .40).pow(2) + ((ny - .5) / .40).pow(2) >= 1)) continue
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
                "durationMs" to (System.nanoTime() - started) / 1_000_000,
                "cupBoundary" to (detected?.ellipse?.let { listOf(it.center.x,it.center.y,it.size.width,it.size.height,it.angle) } ?: emptyList<Double>()))
        } finally {
            owned.forEach { it.release() }; clahe.collectGarbage(); bitmap.recycle()
        }
    }

    private fun overlap(a: Map<String, Any>, b: Map<String, Any>): Double {
        @Suppress("UNCHECKED_CAST")
        val x = a["box"] as List<Int>
        @Suppress("UNCHECKED_CAST")
        val y = b["box"] as List<Int>
        val area = max(0, min(x[0] + x[2], y[0] + y[2]) - max(x[0], y[0])) *
            max(0, min(x[1] + x[3], y[1] + y[3]) - max(x[1], y[1]))
        return area.toDouble() / min(x[2] * x[3], y[2] * y[3])
    }

    /** No work, result or cache changes in normal builds; optional bounded retry. */
    private fun analyze(bytes: ByteArray, adaptive: Boolean, budgetMs: Long): Map<String, Any> {
        val baseline = extract(bytes)
        if (!adaptive) return baseline
        val extraStarted = System.nanoTime()
        fun expired() = System.nanoTime() - extraStarted >= budgetMs * 1_000_000L
        fun fallback() = baseline + ("durationMs" to ((baseline["durationMs"] as Long) +
            (System.nanoTime() - extraStarted) / 1_000_000))
        if (expired()) return fallback()
        val bitmap = try { requireNotNull(BitmapFactory.decodeByteArray(bytes, 0, bytes.size)) }
            catch (_: Exception) { return fallback() }
        val rgba = Mat(); val gray = Mat()
        try {
            Utils.bitmapToMat(bitmap, rgba)
            Imgproc.cvtColor(rgba, gray, Imgproc.COLOR_RGBA2GRAY)
            val w = gray.cols(); val h = gray.rows()
            val levels = ByteArray(w * h); gray.get(0, 0, levels)
            val histogram = IntArray(256)
            var total = 0; var sum = 0L
            // Inner image area only, not a detected cup-bottom or cup boundary.
            fun radial(index: Int): Double {
                val x = (index % w + .5) / w - .5
                val y = (index / w + .5) / h - .5
                return sqrt(x * x + y * y)
            }
            for (i in levels.indices) if (radial(i) <= .28) {
                val level = levels[i].toInt() and 255
                histogram[level]++; sum += level; total++
            }
            fun percentile(fraction: Double): Int {
                var n = 0
                for (i in histogram.indices) {
                    n += histogram[i]
                    if (n >= ceil(total * fraction)) return i
                }
                return 255
            }
            @Suppress("UNCHECKED_CAST")
            val current = baseline["candidates"] as List<Map<String, Any>>
            val strong = current.take(4)
            var edgePixels = 0; var allPixels = 0
            for (candidate in strong) for (pixel in candidate["pixels"] as IntArray) {
                allPixels++
                if (radial(pixel) > .28) edgePixels++
            }
            // Locked calibration defaults, not accuracy estimates.
            val shadow = total > 0 && sum.toDouble() / total <= 95.0
            val weakContrast = percentile(.90) - percentile(.10) <= 55
            val edgeHeavy = allPixels > 0 && edgePixels.toDouble() / allPixels >= .65
            if (!shadow || !weakContrast || !edgeHeavy || expired()) return fallback()

            // One additional extraction at the milder calibrated contrast setting.
            val alternative = extract(bytes, 1.0)
            if (expired()) return fallback()
            @Suppress("UNCHECKED_CAST")
            val alternatives = alternative["candidates"] as List<Map<String, Any>>
            val added = mutableListOf<Map<String, Any>>()
            for (candidate in alternatives) {
                if (expired()) return fallback()
                val pixels = candidate["pixels"] as IntArray
                @Suppress("UNCHECKED_CAST")
                val box = candidate["box"] as List<Int>
                var inner = 0; var lightSum = 0L; val local = IntArray(256)
                for (pixel in pixels) {
                    if (radial(pixel) <= .28) inner++
                    lightSum += levels[pixel].toInt() and 255
                }
                for (y in box[1] until box[1] + box[3]) for (x in box[0] until box[0] + box[2]) {
                    local[levels[y * w + x].toInt() and 255]++
                }
                fun localPercentile(fraction: Double): Int {
                    var n = 0
                    for (i in local.indices) {
                        n += local[i]
                        if (n >= ceil(box[2] * box[3] * fraction)) return i
                    }
                    return 255
                }
                // Keep meaningful source contrast; do not reward bright noise or rims.
                if (inner < 70 || inner.toDouble() / pixels.size < .6 ||
                    lightSum.toDouble() / pixels.size > 140 ||
                    localPercentile(.9) - localPercentile(.1) < 12 ||
                    pixels.size.toDouble() / (box[2] * box[3]) > .85) continue
                if ((current + added).any { overlap(it, candidate) > .25 }) continue
                added.add(candidate + ("id" to (100000 + (candidate["id"] as Int))))
            }
            if (added.isEmpty() || expired()) return fallback()
            val merged = (current + added).sortedByDescending { it["score"] as Double }.take(24)
            // If candidate cap would discard every new region, retain baseline exactly.
            if (merged.none { (it["id"] as Int) >= 100000 }) return fallback()
            return baseline + mapOf("candidates" to merged,
                "durationMs" to ((baseline["durationMs"] as Long) +
                    (System.nanoTime() - extraStarted) / 1_000_000))
        } catch (_: Exception) {
            // Optional contrast failure must never lose the successful first pass.
            return fallback()
        } finally {
            rgba.release(); gray.release(); bitmap.recycle()
        }
    }
}
