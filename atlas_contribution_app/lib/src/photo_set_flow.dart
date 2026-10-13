part of 'contribution_home.dart';

extension _PhotoSetFlow on _ContributionHomeState {
  Future<void> _startSetGallery() => _startNewCoffee(gallery: true);

  Future<void> _setGallery({
    PhotoSurface surface = PhotoSurface.cup,
    ContributionPhoto? replace,
  }) async {
    if (_atlasBusy || _draft == null || _draft!.queued) return;
    _change(() {
      _busy = true;
      _galleryRetry = null;
    });
    try {
      final next = await PhotoSetGallery(
        widget.store,
        widget.galleryPicker ?? AndroidGalleryPicker(),
      ).select(_draft!, surface: surface, replaceId: replace?.id);
      if (next != null) {
        await _save(next);
        _photoSetChanged();
        if (surface == PhotoSurface.saucer && next.saucers.isNotEmpty) {
          _change(
            () => _previewIndex = next.photos.indexWhere(
              (p) => p.id == next.saucers.first.id,
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _change(
          () =>
              _galleryRetry = () =>
                  _setGallery(surface: surface, replace: replace),
        );
      }
    } finally {
      _change(() => _busy = false);
    }
  }

  void _photoSetChanged() {
    _change(() {
      _usable.removeWhere(
        (key) => !_draft!.photos.any((p) => _photoIdentity(p) == key),
      );
      _sameSample = false;
      _savePhase = _SavePhase.idle;
      _galleryRetry = null;
    });
  }

  Future<void> _setSaucerCamera({ContributionPhoto? replace}) async {
    if (_atlasBusy || _draft == null || _draft!.queued) return;
    _change(() => _busy = true);
    try {
      final capture =
          await (widget.saucerLauncher ?? (ctx) => showSaucerCamera(ctx))(
            context,
          );
      if (capture == null) return;
      final imported = await widget.store.importCapture(
        CaptureRole.free,
        capture,
        preserveDisplayCrop: true,
      );
      final photo = imported.asSetPhoto(
        photoId: replace?.id,
        type: PhotoSurface.saucer,
      );
      await _save(_draft!.withPhoto(photo).copy(saucerDecided: true));
      _photoSetChanged();
      _change(
        () =>
            _previewIndex = _draft!.photos.indexWhere((p) => p.id == photo.id),
      );
      try {
        await widget.store.releaseCapture(capture);
      } catch (_) {
        /* Durable photo is retained. */
      }
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Tabak fotoğrafı kaydedilemedi. Fincan fotoğrafların korunuyor.',
        );
      }
    } finally {
      _change(() => _busy = false);
    }
  }

  Future<void> _chooseSaucer({ContributionPhoto? replace}) async {
    final draft = _draft;
    if (_atlasBusy ||
        draft == null ||
        draft.queued ||
        !draft.isSet ||
        draft.cups.isEmpty ||
        (replace == null && draft.saucers.isNotEmpty)) {
      return;
    }
    String? source;
    _change(() => _saucerChoiceOpen = true);
    try {
      source = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            replace == null
                ? 'Tabak fotoğrafı ekle'
                : 'Tabak fotoğrafını değiştir',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Kamera'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeri'),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Vazgeç'),
            ),
          ],
        ),
      );
    } finally {
      _change(() => _saucerChoiceOpen = false);
    }
    if (!mounted ||
        source == null ||
        _draft?.id != draft.id ||
        _draft!.queued) {
      return;
    }
    if (source == 'camera') {
      await _setSaucerCamera(replace: replace);
    } else {
      await _setGallery(surface: PhotoSurface.saucer, replace: replace);
    }
  }

  Future<void> _removeSetPhoto(ContributionPhoto photo) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fotoğrafı bu çalışmadan kaldır?'),
        content: const Text(
          'Bu fotoğrafın mevcut işaretleri de bu taslaktan kaldırılır. Kaydedilmiş önceki gözlem geçmişi korunur.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _save(
      _draft!.copy(
        photos: _draft!.photos.where((p) => p.id != photo.id),
        cupSelectionDone: photo.surface == PhotoSurface.cup ? false : null,
        saucerDecided: photo.surface == PhotoSurface.saucer ? true : null,
      ),
    );
    _photoSetChanged();
  }

  Future<void> _setAngle(ContributionPhoto photo, String value) async {
    await _save(
      _draft!.withPhoto(
        photo.asSetPhoto(
          angle: value == 'unknown' ? null : CaptureRole.values.byName(value),
          clearAngle: value == 'unknown',
        ),
      ),
    );
    _photoSetChanged();
  }

  Widget? _coffeeAngleHeader() {
    final draft = _draft;
    if (draft == null || !draft.isSet || draft.photos.isEmpty) return null;
    final p = draft.photos[_previewIndex.clamp(0, draft.photos.length - 1)];
    if (p.surface != PhotoSurface.cup || p.origin != 'gallery') return null;
    final angle = p.angle == CaptureRole.top ? CaptureRole.free : p.angle;
    return LayoutBuilder(
      builder: (context, box) {
        final scale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(
          1.0,
          2.0,
        );
        final menuWidth = (280 * scale).clamp(0.0, box.maxWidth - 32);
        final targetWidth = (180 * scale).clamp(0.0, box.maxWidth - 112);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              bottom: -4,
              left: (box.maxWidth - targetWidth) / 2,
              width: targetWidth,
              height: 48,
              child: PopupMenuButton<String>(
                key: const ValueKey('coffee-angle-control'),
                enabled: !_atlasBusy && !draft.queued,
                tooltip: 'Fotoğrafın açısı — isteğe bağlı',
                padding: EdgeInsets.zero,
                position: PopupMenuPosition.under,
                offset: Offset((targetWidth - menuWidth) / 2, 0),
                constraints: BoxConstraints(
                  minWidth: menuWidth,
                  maxWidth: menuWidth,
                ),
                onSelected: (value) => _setAngle(p, value),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'unknown',
                    child: Text('Açı seç — isteğe bağlı'),
                  ),
                  for (final value in freeCaptureRoles)
                    if (angle == value ||
                        !draft.cups.any(
                          (q) =>
                              q.id != p.id &&
                              (q.angle == CaptureRole.top
                                      ? CaptureRole.free
                                      : q.angle) ==
                                  value,
                        ))
                      PopupMenuItem(
                        value: value.name,
                        child: Text(value.title),
                      ),
                ],
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Material(
                    color: atlasCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: atlasBorder),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            angle?.title ?? 'Açı seç',
                            style: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              height: 1,
                              color: atlasCoffee,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 14,
                            color: atlasCoffee,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _coffeePreview({
    required ContributionPhoto? photo,
    required List<Widget> tools,
    required List<Widget> phase,
  }) {
    final draft = _draft!;
    final index = _previewIndex.clamp(
      0,
      draft.photos.isEmpty ? 0 : draft.photos.length - 1,
    );
    final large = MediaQuery.textScalerOf(context).scale(14) > 19;
    final navBottom = large ? 80.0 : 8.0;
    return CoffeePhotoLayout(
      key: const ValueKey('coffee-preview-body'),
      photo: Stack(
        fit: StackFit.expand,
        children: [
          if (photo == null)
            const Center(child: Text('Henüz fotoğraf eklemedin'))
          else
            LayoutBuilder(
              builder: (context, box) {
                final crop = coffeeDisplayCrop(photo);
                final ratio = crop.aspectRatio(photo.width, photo.height);
                final width = (box.maxHeight * ratio).clamp(0.0, box.maxWidth);
                return Center(
                  child: SizedBox(
                    key: const ValueKey('coffee-photo-image'),
                    width: width,
                    height: width / ratio,
                    child: CroppedPhoto(
                      image: FileImage(widget.store.file(photo.localName)),
                      crop: crop,
                      photoWidth: photo.width,
                      photoHeight: photo.height,
                      semanticLabel: photo.title,
                    ),
                  ),
                );
              },
            ),
          if (photo != null)
            Positioned.fill(
              child: PhotoNavigation(
                index: index,
                count: draft.photos.length,
                onSelect: _atlasBusy || draft.queued
                    ? null
                    : (i) => _change(() => _previewIndex = i),
                overlay: true,
                bottomInset: navBottom,
              ),
            ),
          if (draft.cups.length < 3)
            Positioned(
              top: 8,
              right: 8,
              child: CoffeeOverlayButton(
                tooltip: 'Fotoğraf ekle',
                onPressed: _atlasBusy || draft.queued
                    ? null
                    : draft.isGallery
                    ? _setGallery
                    : () => _continueAtlasCapture(addRemaining: true),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_photo_alternate_outlined, size: 18),
                    SizedBox(width: 4),
                    Text('Fotoğraf ekle', style: TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            ),
          if (phase.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: navBottom + 48,
              child: phase.first,
            ),
          if (draft.queued)
            const Positioned(
              top: 64,
              left: 8,
              right: 8,
              child: CoffeeControlSurface(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Text('Çalışman gönderim kuyruğunda.'),
                ),
              ),
            ),
          if (_galleryRetry != null)
            Positioned(
              top: 64,
              left: 8,
              right: 8,
              child: CoffeeControlSurface(
                child: Row(
                  children: [
                    const Expanded(
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Text(
                          'Fotoğraf eklenemedi.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _atlasBusy ? null : _galleryRetry,
                      child: const Text('Yeniden dene'),
                    ),
                  ],
                ),
              ),
            ),
          if (_galleryRetry == null &&
              photo != null &&
              !suitabilityAccepted(
                _photoChecks[suitabilityIdentity(photo)],
                photo,
              ))
            Positioned(
              top: 64,
              left: 8,
              right: 8,
              child: CoffeeControlSurface(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _coffeeCheckStatus(photo),
                ),
              ),
            ),
          if (_busy || _sequenceRunning)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
      tools: tools.isEmpty ? const SizedBox.shrink() : tools.first,
      footer: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 8),
        child: _atlasFlowActions(),
      ),
    );
  }

  Widget _coffeeCheckStatus(ContributionPhoto photo) {
    final value = _photoChecks[suitabilityIdentity(photo)];
    if (value == null) {
      return const Text(
        'Fotoğraf kontrol ediliyor…',
        style: TextStyle(fontSize: 12),
      );
    }
    if (suitabilityAccepted(value, photo)) return const SizedBox.shrink();
    final failure = PhotoSuitabilityFailure(photo, value);
    final message =
        '${photo.title}: ${failure.message}'
        '${value['experimental'] == true && value['status'] == 'uncertain' ? ' Kontrol henüz deneme aşamasında; mevcut fotoğrafla devam edebilirsin.' : ''}';
    return Row(
      children: [
        Expanded(
          child: Tooltip(
            message: message,
            child: Semantics(
              liveRegion: true,
              child: Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        ),
        if (failure.technical)
          IconButton(
            tooltip: 'Kontrolü Yeniden Dene',
            onPressed:
                _atlasBusy ||
                    _checkingPhotos.contains(suitabilityIdentity(photo))
                ? null
                : () => _checkPhoto(photo, retry: true),
            icon: const Icon(Icons.refresh, size: 20),
          ),
      ],
    );
  }

  Widget _photoSetDraft() {
    final draft = _draft!;
    final disabled = _atlasBusy || draft.queued;
    final index = _previewIndex.clamp(
      0,
      draft.photos.isEmpty ? 0 : draft.photos.length - 1,
    );
    final p = draft.photos.isEmpty ? null : draft.photos[index];
    final actions = <CoffeeAction>[
      if (p != null) ...[
        CoffeeAction(
          'Değiştir',
          disabled
              ? null
              : () async {
                  if (p.surface == PhotoSurface.saucer) {
                    await _chooseSaucer(replace: p);
                  } else if (p.origin == 'gallery') {
                    await _setGallery(replace: p);
                  } else {
                    await _capture(p.angle!);
                  }
                },
          icon: Icons.refresh,
          tooltip: p.surface == PhotoSurface.saucer
              ? 'Tabak fotoğrafını değiştir'
              : 'Fotoğrafı değiştir',
        ),
        if (draft.saucers.isEmpty)
          CoffeeAction(
            'Tabak ekle',
            disabled ? null : _chooseSaucer,
            icon: Icons.add_circle_outline,
            tooltip: 'Tabak fotoğrafı ekle',
          ),
        CoffeeAction(
          'Kaldır',
          disabled ? null : () => _removeSetPhoto(p),
          icon: Icons.remove_circle_outline,
        ),
      ],
    ];
    if (draft.reviewed) {
      actions.add(
        CoffeeAction(
          'İşaretler',
          disabled ? null : _continuePhotoSet,
          icon: Icons.draw_outlined,
          tooltip: 'İşaretleri Gözden Geçir',
        ),
      );
    }
    final tools = <Widget>[
      if (actions.isNotEmpty)
        CoffeeActionStrip(actions, iconsAbove: true)
      else
        CoffeeActionStrip([
          CoffeeAction(
            draft.isGallery ? 'Galeriden fotoğraf seç' : 'Çekime Devam Et',
            disabled
                ? null
                : draft.isGallery
                ? _setGallery
                : _continueAtlasCapture,
          ),
          CoffeeAction(
            draft.isGallery ? 'Kameraya geç' : 'Galeriden seç',
            disabled
                ? null
                : draft.isGallery
                ? _startNewCamera
                : _startSetGallery,
          ),
        ]),
    ];
    return _coffeePreview(photo: p, tools: tools, phase: const []);
  }
}
