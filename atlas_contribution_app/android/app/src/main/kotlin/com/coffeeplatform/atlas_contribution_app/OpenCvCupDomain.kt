package com.coffeeplatform.atlas_contribution_app

import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import kotlin.math.*

/** Analysis-only domain. Does not crop, resize, draw on or persist user photos. */
internal object OpenCvCupDomain {
    data class Result(val mask: Mat, val ellipse: RotatedRect?)
    private data class Proposal(val score: Double, val ellipse: RotatedRect, val rimEvidence: Double = 0.0)

    fun detect(gray: Mat, rgba: Mat): Result {
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
            val histogram=IntArray(256)
            for(v in levels) histogram[v.toInt() and 255]++
            var cumulative=0;var p90=255
            for(v in histogram.indices) {
                cumulative+=histogram[v]
                if(cumulative>=ceil(w*h*.9)) { p90=v;break }
            }
            val whiteLimit=max(95.0,p90*.75)
            val white=BooleanArray(w*h);val broadWhite=ByteArray(w*h)
            for(i in strong.indices) {
                val r=colors[i*4].toInt() and 255;val g=colors[i*4+1].toInt() and 255
                val b=colors[i*4+2].toInt() and 255;val light=levels[i].toInt() and 255
                val hi=max(r,max(g,b));val lo=min(r,min(g,b))
                val saturation=if(hi==0) 0.0 else 255.0*(hi-lo)/hi
                // Bright skin must not support a rim or seed an enclosing hand/body
                // ellipse. This only classifies ceramic, not the coffee pixels.
                val ceramic=saturation<105 && r>b-15 && g>b-15 && r-g<=35 && r-b<=65
                white[i]=ceramic && light>whiteLimit
                if(ceramic && light>130) broadWhite[i]=255.toByte()
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
            Imgproc.GaussianBlur(gray, smooth, Size(5.0, 5.0), 1.0)
            Imgproc.Canny(smooth, edges, 50.0, 120.0)
            Core.bitwise_not(edges, inverted)
            Imgproc.distanceTransform(inverted, distances, Imgproc.DIST_L2, 3)
            val distancePixels=FloatArray(w*h);distances.get(0,0,distancePixels)
            // Spatially balanced evidence keeps a dark bottom from dominating the
            // rim score. Sample once; never allocate a full mask per proposal.
            val step=max(1,ceil(sqrt(w*h/4096.0)).toInt())
            val coffeeSamples=ArrayList<Int>();val quadrantTotals=IntArray(4)
            fun quadrant(x:Int,y:Int)=(if(x>=w/2) 1 else 0)+(if(y>=h/2) 2 else 0)
            for(y in 0 until h step step) for(x in 0 until w step step) {
                val i=y*w+x
                if(strong[i].toInt()!=0) { coffeeSamples.add(i);quadrantTotals[quadrant(x,y)]++ }
            }
            fun measuredProposal(e:RotatedRect):Proposal? {
                val ew=e.size.width;val eh=e.size.height;val cx=e.center.x;val cy=e.center.y
                val area=PI*ew*eh/4
                if(!listOf(cx,cy,ew,eh,e.angle).all { it.isFinite() } || min(ew,eh)<30 ||
                    max(ew,eh)>max(w,h)*1.6 || area<=w*h*.08 || area>=w*h*1.2 ||
                    ew/eh !in .30..3.33 || cx !in w*.1..w*.9 || cy !in h*.1..h*.9) return null
                val ca=cos(e.angle*PI/180);val sa=sin(e.angle*PI/180)
                var support=0;var ceramic=0;var contrast=0
                for(i in 0 until 72) {
                    val a=i*2*PI/72
                    val dx=ew/2*cos(a)*ca-eh/2*sin(a)*sa
                    val dy=ew/2*cos(a)*sa+eh/2*sin(a)*ca
                    val x=(cx+dx).roundToInt();val y=(cy+dy).roundToInt()
                    if(x !in 0 until w || y !in 0 until h) continue
                    if(distancePixels[y*w+x]<=max(3.0,min(ew,eh)*.0175)) support++
                    for(scale in doubleArrayOf(.96,1.0,1.04)) {
                        val px=(cx+dx*scale).roundToInt();val py=(cy+dy*scale).roundToInt()
                        if(px in 0 until w && py in 0 until h && white[py*w+px]) { ceramic++;break }
                    }
                    val ix=(cx+dx*.96).roundToInt();val iy=(cy+dy*.96).roundToInt()
                    val ox=(cx+dx*1.08).roundToInt();val oy=(cy+dy*1.08).roundToInt()
                    if(ix in 0 until w && iy in 0 until h && ox in 0 until w && oy in 0 until h &&
                        (levels[iy*w+ix].toInt() and 255)-(levels[oy*w+ox].toInt() and 255)>=18) contrast++
                }
                if(support<31 || ceramic<36) return null
                val covered=IntArray(4)
                for(pixel in coffeeSamples) {
                    val x=pixel%w-cx;val y=pixel/w-cy
                    if(((x*ca+y*sa)/(ew/2)).pow(2)+((-x*sa+y*ca)/(eh/2)).pow(2)<=.92*.92)
                        covered[quadrant(pixel%w,pixel/w)]++
                }
                var distributed=0.0;var quadrants=0
                for(q in 0 until 4) if(quadrantTotals[q]*step*step>70) {
                    distributed+=covered[q].toDouble()/quadrantTotals[q];quadrants++
                }
                if(quadrants>0) distributed/=quadrants
                val rimEvidence=ceramic/72.0*2+support/72.0+contrast/72.0*2
                return Proposal(rimEvidence+distributed+min(1.0,area/(w*h))*.5,e,rimEvidence)
            }
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
            // Bright ceramic arcs remain useful when residue breaks the rim's
            // edge contour. Upper arcs omit handles; hulls remove inward notches.
            val ceramicMask=Mat()
            try {
                for(broad in listOf(false,true)) {
                    val pixels=if(broad) broadWhite else ByteArray(w*h) { if(white[it]) 255.toByte() else 0 }
                    ceramicMask.create(h,w,CvType.CV_8U);ceramicMask.put(0,0,pixels)
                    Imgproc.morphologyEx(ceramicMask,ceramicMask,Imgproc.MORPH_CLOSE,anchorKernel)
                    contours.forEach { it.release() };contours.clear()
                    Imgproc.findContours(ceramicMask,contours,hierarchy,Imgproc.RETR_EXTERNAL,Imgproc.CHAIN_APPROX_NONE)
                    for(contour in contours.sortedByDescending { Imgproc.contourArea(it) }.take(4)) {
                        if(Imgproc.contourArea(contour)<w*h*.05) continue
                        val points=contour.toArray();val low=points.minOf { it.y };val high=points.maxOf { it.y }
                        for(fraction in listOf(.6,.7,.8,1.0)) {
                            val arc=points.filter { it.y<=low+(high-low)*fraction }.toTypedArray()
                            if(arc.size<40) continue
                            val floating=MatOfPoint2f(*arc)
                            try { proposals.add(Proposal(0.0,Imgproc.fitEllipse(floating))) } finally { floating.release() }
                            val integer=MatOfPoint(*arc);val hull=MatOfInt()
                            try {
                                Imgproc.convexHull(integer,hull)
                                val hullPoints=hull.toArray().map { arc[it] }.toTypedArray()
                                if(hullPoints.size>=5) {
                                    val fit=MatOfPoint2f(*hullPoints)
                                    try { proposals.add(Proposal(0.0,Imgproc.fitEllipse(fit))) } finally { fit.release() }
                                }
                            } finally { integer.release();hull.release() }
                        }
                    }
                }
            } finally { ceramicMask.release() }
            // All sources use the same evidence, replacing incomparable Hough ranks
            // and contour-area scores. A weak nonempty result also triggers retry.
            val measured=proposals.mapNotNull { p -> measuredProposal(p.ellipse) }
            proposals.clear();proposals.addAll(measured)
            if ((proposals.maxOfOrNull { it.score } ?: 0.0)<4.2) {
                // Geometry-only temporary views support shallow oval rims. All results
                // are mapped back to unchanged input coordinates, never used for drawing.
                val deadline=System.nanoTime()+1_000_000_000L
                for (scale in listOf(1.5, 2.0, .75)) {
                    if(System.nanoTime()>=deadline) break
                    val stretched = Mat(); val ovalCircles = Mat()
                    try {
                        val bounded=min(1.0,512.0/max(w.toDouble(),h*scale))
                        Imgproc.resize(smooth, stretched, Size((w*bounded).roundToInt().toDouble(), (h*scale*bounded).roundToInt().toDouble()))
                        Imgproc.HoughCircles(stretched, ovalCircles, Imgproc.HOUGH_GRADIENT,
                            1.2, max(10.0,min(w,h)*.1*bounded), 100.0,40.0,
                            max(10,(min(w,h)*.12*bounded).toInt()),(min(w,h)*.65*bounded).toInt())
                        for (rank in 0 until min(32,ovalCircles.cols())) {
                            if(System.nanoTime()>=deadline) break
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
                            if(coverage>=.42) measuredProposal(ellipse)?.let { proposals.add(it) }
                        }
                    } finally { stretched.release(); ovalCircles.release() }
                }
            }
            val ranked=proposals.sortedByDescending { it.score }
            val best=ranked.firstOrNull()
            // Prefer the measured enclosing opening over its nested bottom if
            // their evidence is comparable; size alone never makes a valid rim.
            val chosen=if(best==null) null else ranked.firstOrNull {
                it.score>=best.score-.15 && it.rimEvidence>=best.rimEvidence &&
                    it.ellipse.size.area()>best.ellipse.size.area()*1.15 &&
                    encloses(it.ellipse,best.ellipse)
            }?.ellipse ?: best.ellipse
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

    private fun encloses(outer:RotatedRect,inner:RotatedRect):Boolean {
        val ca=cos(outer.angle*PI/180);val sa=sin(outer.angle*PI/180)
        val ci=cos(inner.angle*PI/180);val si=sin(inner.angle*PI/180)
        for(i in 0 until 16) {
            val a=i*2*PI/16
            val x=inner.center.x+inner.size.width/2*cos(a)*ci-inner.size.height/2*sin(a)*si-outer.center.x
            val y=inner.center.y+inner.size.width/2*cos(a)*si+inner.size.height/2*sin(a)*ci-outer.center.y
            if(((x*ca+y*sa)/(outer.size.width/2)).pow(2)+((-x*sa+y*ca)/(outer.size.height/2)).pow(2)>1.05) return false
        }
        return true
    }
}
