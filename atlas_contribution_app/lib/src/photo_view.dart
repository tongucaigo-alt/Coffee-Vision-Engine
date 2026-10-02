import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'models.dart';
import 'photo_crop.dart';
import 'cropped_photo.dart';

class MarkedPhoto extends StatefulWidget {
  const MarkedPhoto({
    required this.photo,
    required this.image,
    this.displayCrop,
    this.maxPreviewHeight,
    super.key,
  });
  final ContributionPhoto photo;
  final ImageProvider image;
  final PhotoCrop? displayCrop;
  final double? maxPreviewHeight;
  @override
  State<MarkedPhoto> createState() => _MarkedPhotoState();
}

class _MarkedPhotoState extends State<MarkedPhoto> {
  String? selected;
  PhotoCrop get crop {
    final proposed = widget.displayCrop ?? widget.photo.displayCrop;
    return proposed != null &&
            widget.photo.regions.every((r) => proposed.containsBox(r.box))
        ? proposed
        : PhotoCrop.full;
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(widget.photo.title, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      LayoutBuilder(
        builder: (context, constraints) => Align(
          alignment: Alignment.center,
          child: SizedBox(
            width: widget.maxPreviewHeight == null
                ? constraints.maxWidth
                : (widget.maxPreviewHeight! *
                          crop.aspectRatio(
                            widget.photo.width,
                            widget.photo.height,
                          ))
                      .clamp(0, constraints.maxWidth),
            child: AspectRatio(
              aspectRatio: crop.aspectRatio(
                widget.photo.width,
                widget.photo.height,
              ),
              child: LayoutBuilder(
                builder: (_, c) => Stack(
                  children: [
                    Positioned.fill(
                      child: CroppedPhoto(
                        image: widget.image,
                        photoWidth: widget.photo.width,
                        photoHeight: widget.photo.height,
                        crop: crop,
                        errorBuilder: (_, _, _) => const Center(
                          child: Text(
                            'Fotoğraf yüklenemedi. Sayfayı yeniden aç.',
                          ),
                        ),
                      ),
                    ),
                    for (final r in widget.photo.regions)
                      Positioned(
                        left: crop.toDisplayBox(r.box).x * c.maxWidth,
                        top: crop.toDisplayBox(r.box).y * c.maxHeight,
                        width: crop.toDisplayBox(r.box).width * c.maxWidth,
                        height: crop.toDisplayBox(r.box).height * c.maxHeight,
                        child: GestureDetector(
                          onTap: () => setState(() => selected = r.id),
                          child: Semantics(
                            label: r.title,
                            button: true,
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selected == r.id
                                      ? Colors.amber
                                      : Colors.tealAccent,
                                  width: selected == r.id ? 4 : 2,
                                ),
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
        ),
      ),
      for (final r in widget.photo.regions)
        ListTile(
          selected: selected == r.id,
          onTap: () => setState(() => selected = r.id),
          title: Text(r.title),
        ),
      const SizedBox(height: 16),
    ],
  );
}

class CaptureGuide extends StatelessWidget {
  const CaptureGuide(this.role, {super.key});
  final CaptureRole role;
  @override
  Widget build(BuildContext context) {
    final top = role == CaptureRole.top;
    final free = role == CaptureRole.free;
    final mirror = role == CaptureRole.handleLeft
        ? 'translate(280 0) scale(-1 1)'
        : '';
    return Semantics(
      image: true,
      label: '${role.title} çekim örneği',
      child: SizedBox(
        height: 150,
        child: SvgPicture.string('''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 280 150">
<rect width="280" height="150" fill="#f1f6f3"/>
<g transform="$mirror" fill="#ffffff" stroke="#186354" stroke-width="4">
${top ? '<circle cx="130" cy="75" r="52"/><circle cx="130" cy="75" r="39" stroke="#879c93"/><path d="M181 57c40-4 40 40 0 36" fill="none"/>' : '<path d="M72 57l10 55q48 32 96 0l10-55z"/><ellipse cx="130" cy="56" rx="58" ry="29"/><ellipse cx="130" cy="56" rx="46" ry="20" stroke="#879c93"/>${free ? '<path d="M100 57q12-16 22-2t22-5 20 10" fill="none" stroke="#735644"/>' : '<path d="M190 64c42-3 38 45-7 36" fill="none"/>'}'}
</g></svg>'''),
      ),
    );
  }
}
