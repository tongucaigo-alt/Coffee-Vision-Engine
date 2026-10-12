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

  Future<void> _moveSetPhoto(ContributionPhoto photo, int delta) async {
    final cups = _draft!.cups;
    final from = cups.indexWhere((p) => p.id == photo.id);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= cups.length) return;
    cups.removeAt(from);
    cups.insert(to, photo);
    await _save(_draft!.copy(photos: [...cups, ..._draft!.saucers]));
    _photoSetChanged();
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        key: const ValueKey('coffee-preview-body'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              draft.isSet && !draft.cupSelectionDone
                  ? 'Fotoğraflar'
                  : draft.isSet && !draft.saucerDecided
                  ? 'İsteğe bağlı tabak'
                  : 'Fotoğrafları onayla',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: atlasSage),
            ),
          ),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: atlasCard,
                border: Border.all(color: atlasBorder),
                borderRadius: BorderRadius.circular(14),
              ),
              child: photo == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Henüz fotoğraf eklemedin',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, color: atlasSage),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (_, constraints) {
                        final ratio = photo.visibleCrop.aspectRatio(
                          photo.width,
                          photo.height,
                        );
                        final width = (constraints.maxHeight * ratio)
                            .clamp(0.0, constraints.maxWidth)
                            .toDouble();
                        return Center(
                          child: SizedBox(
                            width: width,
                            height: width / ratio,
                            child: AtlasPhoto(
                              photo: photo,
                              image: FileImage(
                                widget.store.file(photo.localName),
                              ),
                              height: width / ratio,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 8),
          if (photo != null) ...[
            PhotoNavigation(
              index: index,
              count: draft.photos.length,
              onSelect: _atlasBusy || draft.queued
                  ? null
                  : (i) => _change(() => _previewIndex = i),
            ),
          ],
          if (tools.isNotEmpty)
            Wrap(alignment: WrapAlignment.center, spacing: 4, children: tools),
          if (_galleryRetry != null)
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Fotoğraflar eklenemedi. Önceki fotoğrafların korunuyor. En fazla 3 fincan ve 1 tabak seç.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                TextButton(
                  onPressed: _atlasBusy ? null : _galleryRetry,
                  child: const Text('Yeniden dene'),
                ),
              ],
            )
          else if (photo != null)
            _coffeeCheckStatus(photo),
          ...phase,
          if (_atlasBusy) const LinearProgressIndicator(minHeight: 2),
        ],
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
                    await _setSaucerCamera(replace: p);
                  } else if (p.origin == 'gallery') {
                    await _setGallery(replace: p);
                  } else {
                    await _capture(p.angle!);
                  }
                },
          icon: Icons.refresh,
          tooltip: p.surface == PhotoSurface.saucer
              ? 'Tabak çek'
              : 'Fotoğrafı değiştir',
        ),
        if (p.surface == PhotoSurface.saucer)
          CoffeeAction(
            'Galeriden değiştir',
            disabled
                ? null
                : () => _setGallery(surface: PhotoSurface.saucer, replace: p),
            icon: Icons.photo_library_outlined,
          ),
        CoffeeAction(
          'Kaldır',
          disabled ? null : () => _removeSetPhoto(p),
          icon: Icons.remove_circle_outline,
        ),
      ],
      if (draft.complete && draft.saucers.isEmpty)
        CoffeeAction(
          'Tabak ekle',
          disabled ? null : () => _save(draft.copy(saucerDecided: false)),
          icon: Icons.add_circle_outline,
          tooltip: 'Tabak fotoğrafı ekle',
        ),
      if (draft.cupSelectionDone && !draft.saucerDecided) ...[
        CoffeeAction(
          'Tabak çek',
          disabled ? null : _setSaucerCamera,
          icon: Icons.camera_alt,
        ),
        CoffeeAction(
          'Galeriden seç',
          disabled ? null : () => _setGallery(surface: PhotoSurface.saucer),
          icon: Icons.photo_library_outlined,
          tooltip: 'Galeriden tabak seç',
        ),
      ],
    ];
    final tools = <Widget>[
      if (actions.isNotEmpty)
        SizedBox(
          width: double.infinity,
          child: CoffeeActions(
            actions,
            compact: true,
            referenceLabels:
                draft.cupSelectionDone && p?.surface == PhotoSurface.cup
                ? const ['Değiştir', 'Kaldır', 'Tabak çek', 'Galeriden seç']
                : const [],
          ),
        ),
      if (draft.isGallery &&
          draft.cups.length > 1 &&
          p?.surface == PhotoSurface.cup)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Öne taşı',
              onPressed: disabled || draft.cups.first.id == p!.id
                  ? null
                  : () => _moveSetPhoto(p, -1),
              icon: const Icon(Icons.arrow_back, size: 20),
            ),
            Text(
              'Sıra ${draft.cups.indexWhere((q) => q.id == p!.id) + 1}/${draft.cups.length}',
              style: const TextStyle(fontSize: 12),
            ),
            IconButton(
              tooltip: 'Sona taşı',
              onPressed: disabled || draft.cups.last.id == p!.id
                  ? null
                  : () => _moveSetPhoto(p, 1),
              icon: const Icon(Icons.arrow_forward, size: 20),
            ),
          ],
        ),
    ];
    final phase = <Widget>[
      if (p != null && p.surface == PhotoSurface.cup && p.origin == 'gallery')
        DropdownButtonFormField<String>(
          key: ValueKey('${p.id}-${p.angle?.name}'),
          initialValue:
              (p.angle == CaptureRole.top ? CaptureRole.free : p.angle)?.name ??
              'unknown',
          isExpanded: true,
          style: const TextStyle(fontSize: 12, color: atlasCoffee),
          decoration: const InputDecoration(
            labelText: 'Fotoğrafın açısı',
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: [
            const DropdownMenuItem(
              value: 'unknown',
              child: Text('Açı seç — isteğe bağlı'),
            ),
            for (final angle in freeCaptureRoles)
              if (p.angle == angle ||
                  !draft.cups.any(
                    (q) =>
                        q.id != p.id &&
                        (q.angle == CaptureRole.top
                                ? CaptureRole.free
                                : q.angle) ==
                            angle,
                  ))
                DropdownMenuItem(value: angle.name, child: Text(angle.title)),
          ],
          onChanged: disabled
              ? null
              : (v) {
                  if (v != null) _setAngle(p, v);
                },
        ),
      if (!draft.cupSelectionDone) ...[
        if (draft.photos.isEmpty)
          CoffeeActions([
            CoffeeAction(
              draft.isGallery ? 'Galeriden fotoğraf seç' : 'Çekime Devam Et',
              disabled
                  ? null
                  : draft.isGallery
                  ? _setGallery
                  : _continueAtlasCapture,
              icon: draft.isGallery
                  ? Icons.photo_library_outlined
                  : Icons.camera_alt,
            ),
            CoffeeAction(
              draft.isGallery ? 'Kameraya geç' : 'Galeriden seç',
              disabled
                  ? null
                  : draft.isGallery
                  ? _startNewCamera
                  : _startSetGallery,
            ),
          ])
        else if (draft.isGallery && draft.cups.length < 3)
          OutlinedButton.icon(
            onPressed: disabled ? null : _setGallery,
            icon: const Icon(Icons.add_photo_alternate, size: 20),
            label: const Text(
              'Fincan fotoğrafı ekle',
              textAlign: TextAlign.center,
            ),
          )
        else if (!draft.isGallery && draft.cups.length < 3)
          OutlinedButton.icon(
            onPressed: disabled ? null : _continueAtlasCapture,
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text('Çekime Devam Et'),
          ),
      ] else if (draft.complete && draft.photos.length > 1)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          visualDensity: VisualDensity.compact,
          value: _sameSample,
          title: const Tooltip(
            message: 'Fotoğraflar aynı fincana ve varsa ona ait tabağa ait.',
            child: Text(
              'Hepsi aynı fincana ait.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          onChanged: disabled
              ? null
              : (v) => _change(() => _sameSample = v == true),
        ),
    ];
    return _coffeePreview(photo: p, tools: tools, phase: phase);
  }
}
