import 'package:flutter/material.dart';
import 'opencv_traces.dart';
import 'photo_crop.dart';
import 'models.dart';
import 'cropped_photo.dart';

/// Original-coordinate pixel hit test; taps outside the mask do not select a trace.
TraceCandidate? traceAt(
  TraceSet set,
  ContributionPhoto photo,
  Offset normalized,
) {
  final index = set.indexOf(photo);
  for (final t in set.selected) {
    if (t.photoIndex != index) continue;
    final x = ((normalized.dx - t.area.x) / t.area.width * t.width).floor();
    final y = ((normalized.dy - t.area.y) / t.area.height * t.height).floor();
    if (x >= 0 &&
        y >= 0 &&
        x < t.width &&
        y < t.height &&
        t.pixels.contains(y * t.width + x)) {
      return t;
    }
  }
  return null;
}

class TraceOverlay extends StatelessWidget {
  const TraceOverlay({
    required this.set,
    required this.photo,
    required this.crop,
    super.key,
  });
  final TraceSet set;
  final ContributionPhoto photo;
  final PhotoCrop crop;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ExcludeSemantics(
      child: CustomPaint(
        painter: TracePainter(
          traces: set.selected,
          photoIndex: set.indexOf(photo),
          display: crop,
        ),
      ),
    ),
  );
}

/// Read-only photo viewer. No pan recognizer, so the containing page can scroll.
class TracePhoto extends StatelessWidget {
  const TracePhoto({
    required this.photo,
    required this.image,
    required this.set,
    this.colored = true,
    this.crop,
    this.onTrace,
    super.key,
  });
  final ContributionPhoto photo;
  final ImageProvider image;
  final TraceSet set;
  final bool colored;
  final PhotoCrop? crop;
  final ValueChanged<TraceCandidate>? onTrace;
  @override
  Widget build(BuildContext context) {
    final display = crop ?? photo.visibleCrop;
    return AspectRatio(
      aspectRatio: display.aspectRatio(photo.width, photo.height),
      child: LayoutBuilder(
        builder: (_, size) => GestureDetector(
          onTapUp: !colored || onTrace == null
              ? null
              : (details) {
                  final hit = traceAt(
                    set,
                    photo,
                    Offset(
                      display.x +
                          details.localPosition.dx /
                              size.maxWidth *
                              display.width,
                      display.y +
                          details.localPosition.dy /
                              size.maxHeight *
                              display.height,
                    ),
                  );
                  if (hit != null) onTrace!(hit);
                },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                CroppedPhoto(
                  image: image,
                  photoWidth: photo.width,
                  photoHeight: photo.height,
                  crop: display,
                  errorBuilder: (_, _, _) =>
                      const Center(child: Text('Fotoğraf yüklenemedi.')),
                ),
                if (colored)
                  TraceOverlay(set: set, photo: photo, crop: display),
                for (final r in photo.regions.where(
                  (r) => display.containsBox(r.box),
                ))
                  Positioned(
                    left: display.toDisplayBox(r.box).x * size.maxWidth,
                    top: display.toDisplayBox(r.box).y * size.maxHeight,
                    width: display.toDisplayBox(r.box).width * size.maxWidth,
                    height: display.toDisplayBox(r.box).height * size.maxHeight,
                    child: IgnorePointer(
                      child: Semantics(
                        label: r.title,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: const Color(0xff4A7C59),
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showTraceCloseup(
  BuildContext context,
  ContributionPhoto photo,
  ImageProvider image,
  TraceSet set,
  TraceCandidate trace,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (ctx) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Telve izi'),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .55,
            ),
            child: TracePhoto(
              photo: photo,
              image: image,
              set: set,
              crop: trace.closeup,
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    ),
  ),
);

/// Lives in the existing photo dialog; never starts analysis or paid requests.
class TracePhotoViewer extends StatefulWidget {
  const TracePhotoViewer({
    required this.photo,
    required this.image,
    required this.set,
    super.key,
  });
  final ContributionPhoto photo;
  final ImageProvider image;
  final TraceSet set;
  @override
  State<TracePhotoViewer> createState() => _TracePhotoViewerState();
}

class _TracePhotoViewerState extends State<TracePhotoViewer> {
  bool colored = true;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.photo.surface == PhotoSurface.cup &&
          widget.set.indexOf(widget.photo) >= 0)
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          children: [
            for (final option in [false, true])
              ChoiceChip(
                label: Text(option ? 'Renkli izler' : 'Orijinal'),
                selected: colored == option,
                onSelected: (_) => setState(() => colored = option),
              ),
          ],
        ),
      const SizedBox(height: 12),
      TracePhoto(
        photo: widget.photo,
        image: widget.image,
        set: widget.set,
        colored: colored,
        onTrace: (trace) => showTraceCloseup(
          context,
          widget.photo,
          widget.image,
          widget.set,
          trace,
        ),
      ),
      if (widget.photo.regions.isNotEmpty)
        Wrap(
          spacing: 8,
          children: [
            for (final region in widget.photo.regions)
              Chip(label: Text(region.title)),
          ],
        ),
    ],
  );
}

class TracePainter extends CustomPainter {
  TracePainter({
    required this.traces,
    required this.photoIndex,
    required this.display,
  });
  final List<TraceCandidate> traces;
  final int photoIndex;
  final PhotoCrop display;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < traces.length; i++) {
      final t = traces[i];
      if (t.photoIndex != photoIndex) continue;
      final dx = t.area.width / t.width / display.width * size.width;
      final dy = t.area.height / t.height / display.height * size.height;
      final origin = Offset(
        (t.area.x - display.x) / display.width * size.width,
        (t.area.y - display.y) / display.height * size.height,
      );
      Path region(List<int> pixels) {
        final path = Path();
        // Merge adjacent pixels into scanline runs; preserve anisotropic pixel bounds.
        for (var j = 0; j < pixels.length;) {
          final first = pixels[j];
          var last = first;
          while (++j < pixels.length &&
              pixels[j] == last + 1 &&
              pixels[j] ~/ t.width == first ~/ t.width) {
            last = pixels[j];
          }
          path.addRect(
            Rect.fromLTWH(
              origin.dx + first % t.width * dx,
              origin.dy + first ~/ t.width * dy,
              (last - first + 1) * dx,
              dy,
            ),
          );
        }
        return path;
      }

      final paint = Paint()
        ..color = traceColors[i].withValues(alpha: .65)
        ..isAntiAlias = false;
      canvas.drawPath(region(t.pixels), paint);
      paint.color = traceColors[i].withValues(alpha: .95);
      canvas.drawPath(region(t.boundary), paint);
    }
  }

  @override
  bool shouldRepaint(covariant TracePainter old) => true;
}
