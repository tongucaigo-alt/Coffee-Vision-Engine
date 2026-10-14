package com.coffeeplatform.atlas_contribution_app

import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import kotlin.math.*

/** Analysis-only domain. Does not crop, resize, draw on or persist user photos. */
internal object OpenCvCupDomain {
    data class Result(val mask: Mat, val ellipse: RotatedRect?)
    private data class Proposal(val score: Double, val ellipse: RotatedRect)

    fun detect(gray: Mat, rgba: Mat): Result {
        val started=System.nanoTime()
        val h = gray.rows(); val w = gray.cols()
        val smooth = Mat(); val edges = Mat(); val distances = Mat(); val circles = Mat()
        val inverted = Mat(); val hierarchy = Mat()
        val kernel = Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE, Size(5.0, 5.0))
        val contours = mutableListOf<MatOfPoint>()
        val proposals = mutableListOf<Proposal>()
        val anchorMask=Mat();val anchorLabels=Mat();val anchorStats=Mat();val anchorCenters=Mat()
        val anchorKernel=Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE,Size(7.0,7.0))
        try {
            val levels=ByteArray(w*h);gray.get(0,0,levels)
            val colors=ByteArray(w*h*4);rgba.get(0,0,colors)
            val strong=ByteArray(w*h)
            for(i in strong.indices) {
                val r=colors[i*4].toInt() and 255;val g=colors[i*4+1].toInt() and 255
                val b=colors[i*4+2].toInt() and 255;val light=levels[i].toInt() and 255
                val hi=max(r,max(g,b));val lo=min(r,min(g,b))
                val saturation=if(hi==0) 0.0 else 255.0*(hi-lo)/hi
                if((light<120 && r>=g-3 && r>b+6 && saturation>50) ||
                    (light<60 && r>=g && r>b+2 && saturation>30)) strong[i]=255.toByte()
            }
            anchorMask.create(h,w,CvType.CV_8U);anchorMask.put(0,0,strong)
            Imgproc.morphologyEx(anchorMask,anchorMask,Imgproc.MORPH_CLOSE,anchorKernel)
            val count=Imgproc.connectedComponentsWithStats(anchorMask,anchorLabels,anchorStats,anchorCenters,8,CvType.CV_32S)
            var anchor=0;var largest=0.0
            for(i in 1 until count) {
                val area=anchorStats.get(i,Imgproc.CC_STAT_AREA)[0]
                val x=anchorCenters.get(i,0)[0];val y=anchorCenters.get(i,1)[0]
                if(area>=100 && area>largest && x in w*.15..w*.85 && y in h*.15..h*.85) {
                    anchor=i;largest=area
                }
            }
            if(anchor==0) return Result(Mat.zeros(h,w,CvType.CV_8U),null)
            val labels=IntArray(w*h);anchorLabels.get(0,0,labels)
            val anchorPixels=ArrayList<Int>()
            val stride=max(1,ceil(largest/1024).toInt());var seen=0
            for(i in labels.indices) if(labels[i]==anchor) {
                if(seen%stride==0) anchorPixels.add(i)
                seen++
            }
            fun coversAnchor(ellipse: RotatedRect): Boolean {
                val angle=ellipse.angle*PI/180;val ca=cos(angle);val sa=sin(angle);var covered=0
                for(pixel in anchorPixels) {
                    val x=pixel%w-ellipse.center.x;val y=pixel/w-ellipse.center.y
                    val xx=(x*ca+y*sa)/(ellipse.size.width/2)
                    val yy=(-x*sa+y*ca)/(ellipse.size.height/2)
                    if(xx*xx+yy*yy<=1) covered++
                }
                return covered.toDouble()/anchorPixels.size>=.6
            }
            Imgproc.GaussianBlur(gray, smooth, Size(5.0, 5.0), 1.0)
            Imgproc.Canny(smooth, edges, 50.0, 120.0)
            Core.bitwise_not(edges, inverted)
            Imgproc.distanceTransform(inverted, distances, Imgproc.DIST_L2, 3)
            Imgproc.HoughCircles(smooth, circles, Imgproc.HOUGH_GRADIENT, 1.2,
                max(20.0, min(w, h) * .1), 100.0, 40.0,
                max(20, (min(w, h) * .17).toInt()), (min(w, h) * .49).toInt())
            for (rank in 0 until min(32, circles.cols())) {
                val c = circles.get(0, rank) ?: continue
                val x = c[0]; val y = c[1]; val radius = c[2]
                if (x !in w*.15..w*.85 || y !in h*.15..h*.85) continue
                if (x-radius < -w*.03 || x+radius > w*1.03 ||
                    y-radius < -h*.03 || y+radius > h*1.03) continue
                var supported = 0
                for (i in 0 until 72) {
                    val angle = i * 2.0 * PI / 72
                    val px = (x + radius * cos(angle)).roundToInt()
                    val py = (y + radius * sin(angle)).roundToInt()
                    if (px in 0 until w && py in 0 until h &&
                        distances.get(py, px)[0] <= max(3.0, radius*.035)) supported++
                }
                val coverage = supported / 72.0
                if (coverage >= .65) proposals.add(Proposal(coverage / (1 + rank*.1),
                    RotatedRect(Point(x, y), Size(radius*2, radius*2), 0.0)))
            }
            // Oval fallback for oblique views; reject irregular hand/background contours.
            for ((low, high) in listOf(25.0 to 75.0, 50.0 to 120.0, 80.0 to 180.0)) {
                contours.forEach { it.release() }; contours.clear()
                Imgproc.Canny(smooth, edges, low, high)
                Imgproc.morphologyEx(edges, edges, Imgproc.MORPH_CLOSE, kernel)
                Imgproc.findContours(edges, contours, hierarchy, Imgproc.RETR_LIST, Imgproc.CHAIN_APPROX_NONE)
                for (contour in contours) {
                    if (contour.total() < 40) continue
                    val points = contour.toArray()
                    val floating = MatOfPoint2f(*points)
                    val ellipse = try { Imgproc.fitEllipse(floating) } finally { floating.release() }
                    val x = ellipse.center.x; val y = ellipse.center.y
                    val ew = ellipse.size.width; val eh = ellipse.size.height
                    val area = PI * ew * eh / 4
                    if (!area.isFinite() || area <= w*h*.08 || area >= w*h*1.5 ||
                        ew/eh !in .30..3.33 || x !in w*.1..w*.9 || y !in h*.1..h*.9) continue
                    val angle = ellipse.angle * PI / 180
                    val errors = ArrayList<Double>(); val bins = mutableSetOf<Int>()
                    for (p in points) {
                        val xx = ((p.x-x)*cos(angle)+(p.y-y)*sin(angle))/(ew/2)
                        val yy = (-(p.x-x)*sin(angle)+(p.y-y)*cos(angle))/(eh/2)
                        val error = abs(sqrt(xx*xx+yy*yy)-1)
                        errors.add(error)
                        if (error < .12) bins.add(((atan2(yy,xx)+PI)/(2*PI)*36).toInt()%36)
                    }
                    errors.sort()
                    val median = errors[errors.size/2]
                    val p90 = errors[(errors.size*.90).toInt().coerceAtMost(errors.lastIndex)]
                    val coverage = bins.size / 36.0
                    if (median <= .08 && p90 <= .25 && coverage >= .65)
                        proposals.add(Proposal(area/(w*h)*coverage*(1-median*3), ellipse))
                }
            }
            proposals.removeAll { !coversAnchor(it.ellipse) }
            if (proposals.isEmpty()) {
                // Geometry-only temporary views support shallow oval rims. All results
                // are mapped back to unchanged input coordinates, never used for drawing.
                for (scale in listOf(1.5, 2.0, .75)) {
                    if(System.nanoTime()-started>300_000_000L) break
                    val stretched = Mat(); val ovalCircles = Mat()
                    try {
                        val bounded=min(1.0,512.0/max(w.toDouble(),h*scale))
                        Imgproc.resize(smooth, stretched, Size((w*bounded).roundToInt().toDouble(), (h*scale*bounded).roundToInt().toDouble()))
                        Imgproc.HoughCircles(stretched, ovalCircles, Imgproc.HOUGH_GRADIENT,
                            1.2, max(10.0,min(w,h)*.1*bounded), 100.0,40.0,
                            max(10,(min(w,h)*.12*bounded).toInt()),(min(w,h)*.65*bounded).toInt())
                        for (rank in 0 until min(32,ovalCircles.cols())) {
                            val c=ovalCircles.get(0,rank) ?: continue
                            val x=c[0]/bounded;val y=c[1]/(scale*bounded)
                            val rx=c[2]/bounded;val ry=c[2]/(scale*bounded)
                            if(x !in w*.1..w*.9 || y !in h*.1..h*.9) continue
                            if(x-rx < -w*.15 || x+rx > w*1.15 || y-ry < -h*.15 || y+ry > h*1.15) continue
                            var supported=0
                            for(i in 0 until 72) {
                                val angle=i*2.0*PI/72
                                val px=(x+rx*cos(angle)).roundToInt();val py=(y+ry*sin(angle)).roundToInt()
                                if(px in 0 until w && py in 0 until h &&
                                    distances.get(py,px)[0]<=max(3.0,min(rx,ry)*.035)) supported++
                            }
                            val coverage=supported/72.0
                            val ellipse=RotatedRect(Point(x,y),Size(rx*2,ry*2),0.0)
                            if(coverage>=.65 && coversAnchor(ellipse))
                                proposals.add(Proposal(coverage/(1+rank*.1),ellipse))
                        }
                    } finally { stretched.release(); ovalCircles.release() }
                }
            }
            val chosen = proposals.maxByOrNull { it.score }?.ellipse
            val mask = Mat.zeros(h, w, CvType.CV_8U)
            if (chosen != null) {
                val interior = RotatedRect(chosen.center,
                    Size(chosen.size.width*.92, chosen.size.height*.92), chosen.angle)
                Imgproc.ellipse(mask, interior, Scalar(255.0), -1)
                return Result(mask, interior)
            }
            // Unknown boundary: no coloured claims on arbitrary background regions.
            return Result(mask, null)
        } finally {
            contours.forEach { it.release() }
            listOf(smooth,edges,distances,circles,inverted,hierarchy,kernel,
                anchorMask,anchorLabels,anchorStats,anchorCenters,anchorKernel).forEach { it.release() }
        }
    }
}
