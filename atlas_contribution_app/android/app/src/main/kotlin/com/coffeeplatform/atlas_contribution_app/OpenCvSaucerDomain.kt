package com.coffeeplatform.atlas_contribution_app

import org.opencv.core.*
import org.opencv.imgproc.Imgproc
import kotlin.math.*

/** A plate surface, not the cup-opening detector. Coordinates stay unchanged. */
internal object OpenCvSaucerDomain {
    fun detect(gray: Mat, rgba: Mat): OpenCvCupDomain.Result {
        val w = gray.cols(); val h = gray.rows()
        val owned = mutableListOf<Mat>()
        fun mat() = Mat().also { owned.add(it) }
        val contours = mutableListOf<MatOfPoint>()
        val proposals = mutableListOf<RotatedRect>()
        try {
            val levels = ByteArray(w*h); gray.get(0,0,levels)
            val colors = ByteArray(w*h*4); rgba.get(0,0,colors)
            val histogram=IntArray(256)
            for (v in levels) histogram[v.toInt() and 255]++
            var cumulative=0; var brightLimit=255
            for (v in histogram.indices) {
                cumulative+=histogram[v]
                if (cumulative>=ceil(w*h*.90)) { brightLimit=v; break }
            }
            val reference=DoubleArray(3); var brightCount=0
            for (i in levels.indices) if ((levels[i].toInt() and 255)>=brightLimit) {
                for (c in 0..2) reference[c]+=colors[i*4+c].toInt() and 255
                brightCount++
            }
            val target=reference.sum()/max(1,brightCount)/3
            val gains=DoubleArray(3) { (target/(reference[it]/max(1,brightCount)).coerceAtLeast(1.0)).coerceIn(.65,1.55) }
            val balanced=IntArray(w*h*3)
            val white = ByteArray(w*h); val coffee = ByteArray(w*h)
            for (i in levels.indices) {
                val r=colors[i*4].toInt() and 255; val g=colors[i*4+1].toInt() and 255
                val b=colors[i*4+2].toInt() and 255; val light=levels[i].toInt() and 255
                val hi=max(r,max(g,b)); val lo=min(r,min(g,b))
                val sat=if(hi==0) 0.0 else 255.0*(hi-lo)/hi
                val rr=(r*gains[0]).roundToInt().coerceIn(0,255)
                val gg=(g*gains[1]).roundToInt().coerceIn(0,255)
                val bb=(b*gains[2]).roundToInt().coerceIn(0,255)
                balanced[i*3]=rr; balanced[i*3+1]=gg; balanced[i*3+2]=bb
                val maxBalanced=max(rr,max(gg,bb)); val minBalanced=min(rr,min(gg,bb))
                val neutral=if(maxBalanced==0) 255.0 else 255.0*(maxBalanced-minBalanced)/maxBalanced
                if (light>max(100.0,brightLimit*.65) && neutral<65 && rr-gg<=25 && rr-bb<=35) white[i]=255.toByte()
                if ((light<120 && r>=g-3 && r>b+6 && sat>50) ||
                    (light<60 && r>=g && r>b+2 && sat>30)) coffee[i]=255.toByte()
            }
            val whites=mat(); whites.create(h,w,CvType.CV_8U); whites.put(0,0,white)
            val residue=mat(); residue.create(h,w,CvType.CV_8U); residue.put(0,0,coffee)
            val kernel=Imgproc.getStructuringElement(Imgproc.MORPH_ELLIPSE,Size(5.0,5.0)).also { owned.add(it) }
            Imgproc.morphologyEx(whites,whites,Imgproc.MORPH_CLOSE,kernel)
            val smooth=mat(); val edges=mat(); val inv=mat(); val distances=mat(); val hierarchy=mat()
            Imgproc.GaussianBlur(gray,smooth,Size(5.0,5.0),1.0)
            Imgproc.Canny(smooth,edges,25.0,75.0)
            Core.bitwise_not(edges,inv); Imgproc.distanceTransform(inv,distances,Imgproc.DIST_L2,3)
            val edgeDistance=FloatArray(w*h); distances.get(0,0,edgeDistance)
            // Reject a tiny dark speck; keep independent central coffee evidence.
            val labels=mat(); val stats=mat(); val centres=mat()
            val n=Imgproc.connectedComponentsWithStats(residue,labels,stats,centres,8,CvType.CV_32S)
            var primary=0; var primaryArea=0.0
            for (i in 1 until n) {
                val area=stats.get(i,Imgproc.CC_STAT_AREA)[0]
                if (area>primaryArea && area>=100 && centres.get(i,0)[0] in w*.15..w*.85 && centres.get(i,1)[0] in h*.15..h*.85) {
                    primary=i; primaryArea=area
                }
            }
            if (primary==0) return OpenCvCupDomain.Result(Mat.zeros(h,w,CvType.CV_8U),null)
            val labelPixels=IntArray(w*h); labels.get(0,0,labelPixels)
            val step=max(1,ceil(sqrt(w*h/4096.0)).toInt())
            val primaryOrder=(1 until n).filter {
                stats.get(it,Imgproc.CC_STAT_AREA)[0]>=max(100.0,primaryArea*.10) &&
                centres.get(it,0)[0] in w*.15..w*.85 && centres.get(it,1)[0] in h*.15..h*.85
            }.sortedByDescending { stats.get(it,Imgproc.CC_STAT_AREA)[0] }.take(3)
            var activePrimary=primary
            var samples=(levels.indices step step).filter { labelPixels[it]==primary }
            fun collect(source:Mat, external:Boolean) {
                contours.forEach { it.release() }; contours.clear()
                Imgproc.findContours(source,contours,hierarchy,if(external) Imgproc.RETR_EXTERNAL else Imgproc.RETR_LIST,Imgproc.CHAIN_APPROX_NONE)
                for (c in contours.sortedByDescending { abs(Imgproc.contourArea(it)) }.take(32)) {
                    if (c.total()<40 || abs(Imgproc.contourArea(c))<w*h*.08) continue
                    val points=c.toArray(); val hull=MatOfInt()
                    try {
                        Imgproc.convexHull(c,hull)
                        for (ps in listOf(points,hull.toArray().map { points[it] }.toTypedArray())) {
                            if (ps.size<5) continue
                            val f=MatOfPoint2f(*ps)
                            try { proposals.add(Imgproc.fitEllipse(f)) } finally { f.release() }
                        }
                    } finally { hull.release() }
                }
            }
            val whiteCopy=mat(); whites.copyTo(whiteCopy); collect(whiteCopy,true)
            val edgeCopy=mat(); edges.copyTo(edgeCopy); collect(edgeCopy,false)
            data class Measured(val ellipse:RotatedRect,val score:Double,val area:Double)
            fun measured(e:RotatedRect):Measured? {
                val ew=e.size.width; val eh=e.size.height; val cx=e.center.x; val cy=e.center.y
                val area=PI*ew*eh/4
                if (!listOf(cx,cy,ew,eh,e.angle).all { it.isFinite() } || min(ew,eh)<40 ||
                    ew/eh !in .35..2.86 || area !in w*h*.12..w*h*1.10 ||
                    max(ew,eh)>max(w,h)*1.5 || cx !in w*.15..w*.85 || cy !in h*.15..h*.85) return null
                val ca=cos(e.angle*PI/180); val sa=sin(e.angle*PI/180)
                fun contains(pixel:Int):Boolean {
                    val x=pixel%w-cx; val y=pixel/w-cy
                    return ((x*ca+y*sa)/(ew*.48)).pow(2)+((-x*sa+y*ca)/(eh*.48)).pow(2)<=1
                }
                val coverage=samples.count { contains(it) }.toDouble()/max(1,samples.size)

                var visible=0; var support=0; var ceramic=0; var separation=0; var beyond=0; var beyondWhite=0
                for (i in 0 until 72) {
                    val a=i*2*PI/72; val dx=ew/2*cos(a)*ca-eh/2*sin(a)*sa
                    val dy=ew/2*cos(a)*sa+eh/2*sin(a)*ca
                    val x=(cx+dx).roundToInt(); val y=(cy+dy).roundToInt()
                    if (x !in 0 until w || y !in 0 until h) continue
                    visible++
                    if (edgeDistance[y*w+x]<=max(3.0,min(ew,eh)*.015)) support++
                    val bx=(cx+dx*1.15).roundToInt(); val by=(cy+dy*1.15).roundToInt()
                    if (bx in 0 until w && by in 0 until h) {
                        beyond++
                        if (white[by*w+bx].toInt()!=0) beyondWhite++
                    }
                    val ix=(cx+dx*.98).roundToInt(); val iy=(cy+dy*.98).roundToInt()
                    val ox=(cx+dx*1.06).roundToInt(); val oy=(cy+dy*1.06).roundToInt()
                    if (ix in 0 until w && iy in 0 until h && ox in 0 until w && oy in 0 until h && white[iy*w+ix].toInt()!=0) {
                        val inside=iy*w+ix; val outside=oy*w+ox
                        val delta=(0..2).sumOf { abs(balanced[inside*3+it]-balanced[outside*3+it]) }
                        if (white[outside].toInt()==0 || delta>60) separation++
                    }
                    for (scale in listOf(.94,.98,1.0)) {
                        val px=(cx+dx*scale).roundToInt(); val py=(cy+dy*scale).roundToInt()
                        if (px in 0 until w && py in 0 until h && white[py*w+px].toInt()!=0) { ceramic++; break }
                    }
                }
                val px=centres.get(activePrimary,0)[0]-cx; val py=centres.get(activePrimary,1)[0]-cy
                val central=((px*ca+py*sa)/(ew/2)).pow(2)+((-px*sa+py*ca)/(eh/2)).pow(2)
                val strongRim=support>=ceil(visible*.75) && ceramic>=ceil(visible*.65) && separation>=ceil(visible*.33)
                if (visible<40 || support<ceil(visible*.50) || ceramic<ceil(visible*.50) ||
                    separation<ceil(visible*(if(support>=ceil(visible*.75) && ceramic>=ceil(visible*.70)) .33 else .35)) ||
                    beyond<20 || beyondWhite.toDouble()/beyond>.45 ||
                    !(coverage>=.80 && central<=.70*.70 || strongRim && coverage>=.40)) return null
                return Measured(e,support.toDouble()/visible+ceramic.toDouble()/visible+coverage,area)
            }
            var accepted=proposals.mapNotNull { measured(it) }
            if ((accepted.maxOfOrNull { it.score } ?: 0.0)<2.8) {
                // One bounded fallback; a known poor candidate does not block it.
                val deadline=System.nanoTime()+1_000_000_000L
                val circles=mat()
                for (stretch in listOf(1.0,1.5,2.0)) {
                    if (System.nanoTime()>=deadline) break
                    val bounded=min(1.0,512.0/max(w.toDouble(),h*stretch)); val view=mat()
                    Imgproc.resize(smooth,view,Size((w*bounded).roundToInt().toDouble(),(h*stretch*bounded).roundToInt().toDouble()))
                    Imgproc.HoughCircles(view,circles,Imgproc.HOUGH_GRADIENT,1.2,30.0,100.0,40.0,
                        max(15,(min(w,h)*.2*bounded).toInt()),(min(w,h)*.6*bounded).toInt())
                    for (i in 0 until min(12,circles.cols())) {
                        if (System.nanoTime()>=deadline) break
                        val c=circles.get(0,i)
                        val centre=Point(c[0]/bounded,c[1]/(stretch*bounded))
                        val ew=c[2]*2/bounded; val eh=c[2]*2/(stretch*bounded)
                        for (scale in listOf(.92,1.0,1.08)) for (dx in listOf(-.03,0.0,.03)) for (dy in listOf(-.03,0.0,.03)) {
                            proposals.add(RotatedRect(Point(centre.x+dx*ew,centre.y+dy*eh),Size(ew*scale,eh*scale),0.0))
                        }
                    }
                }
                accepted=proposals.mapNotNull { measured(it) }
            }
            // A warm tabletop can form the largest dark component. Only try
            // another primary when the first has no supported plate boundary.
            for (alternative in primaryOrder.drop(1)) {
                if (accepted.isNotEmpty()) break
                activePrimary=alternative
                samples=(levels.indices step step).filter { labelPixels[it]==alternative }
                accepted=proposals.mapNotNull { measured(it) }
            }
            // The outside plate edge encloses its nested cup-rest circle.
            val best=accepted.maxOfOrNull { it.score } ?: return OpenCvCupDomain.Result(Mat.zeros(h,w,CvType.CV_8U),null)
            val chosen=accepted.filter { it.score>=best-.25 }.maxByOrNull { it.area }!!.ellipse
            val interior=RotatedRect(chosen.center,Size(chosen.size.width*.96,chosen.size.height*.96),chosen.angle)
            val mask=Mat.zeros(h,w,CvType.CV_8U); Imgproc.ellipse(mask,interior,Scalar(255.0),-1)
            // Repeated annular ornament must not become coloured coffee findings.
            // Conservative: remove that band when many small similar-sized marks
            // repeat around the rim, rather than trying to interpret them.
            val a=interior.angle*PI/180; val ca=cos(a); val sa=sin(a)
            fun polar(x:Double,y:Double):Pair<Double,Double> {
                val dx=x-interior.center.x; val dy=y-interior.center.y
                val u=(dx*ca+dy*sa)/(interior.size.width/2); val v=(-dx*sa+dy*ca)/(interior.size.height/2)
                return sqrt(u*u+v*v) to atan2(v,u)
            }
            val marks=mutableListOf<Pair<Int,Double>>()
            for (i in 1 until n) {
                val area=stats.get(i,Imgproc.CC_STAT_AREA)[0]
                if (area !in 20.0..(PI*interior.size.area()/4*.012)) continue
                val p=polar(centres.get(i,0)[0],centres.get(i,1)[0])
                if (p.first in .70..1.0) marks.add((((p.second+PI)/(2*PI)*16).toInt().coerceIn(0,15)) to area)
            }
            if (marks.map { it.first }.toSet().size>=8) {
                val median=marks.map { it.second }.sorted()[marks.size/2]
                if (marks.count { it.second in median*.5..median*2 }>=8) {
                    val pixels=ByteArray(w*h); mask.get(0,0,pixels)
                    for (i in pixels.indices) if (pixels[i].toInt()!=0 && polar((i%w).toDouble(),(i/w).toDouble()).first>.70) pixels[i]=0
                    mask.put(0,0,pixels)
                }
            }
            // A hand may overlap the plate while still being inside its ellipse.
            // Exclude warm midtone occluders connected to the outside, without
            // removing similarly coloured isolated residue inside the plate.
            val skinPixels=ByteArray(w*h)
            for (i in levels.indices) {
                val r=colors[i*4].toInt() and 255; val g=colors[i*4+1].toInt() and 255
                val b=colors[i*4+2].toInt() and 255; val light=levels[i].toInt() and 255
                if (light>=60 && r-g in 10..110 && g-b in -10..40 && r-b>10) skinPixels[i]=255.toByte()
            }
            val skin=mat(); skin.create(h,w,CvType.CV_8U); skin.put(0,0,skinPixels)
            Imgproc.morphologyEx(skin,skin,Imgproc.MORPH_CLOSE,kernel)
            val skinLabels=mat(); val skinCount=Imgproc.connectedComponents(skin,skinLabels,8,CvType.CV_32S)
            val skinIds=IntArray(w*h); skinLabels.get(0,0,skinIds)
            val domainPixels=ByteArray(w*h); mask.get(0,0,domainPixels)
            val outside=BooleanArray(skinCount)
            for (i in skinIds.indices) if (skinIds[i]>0 && domainPixels[i].toInt()==0) outside[skinIds[i]]=true
            for (i in skinIds.indices) if (skinIds[i]>0 && outside[skinIds[i]]) domainPixels[i]=0
            mask.put(0,0,domainPixels)
            return OpenCvCupDomain.Result(mask,interior)
        } finally { contours.forEach { it.release() }; owned.forEach { it.release() } }
    }
}
