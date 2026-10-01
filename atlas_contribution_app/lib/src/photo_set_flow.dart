part of 'contribution_home.dart';

extension _PhotoSetFlow on _ContributionHomeState {
  Future<void> _startSetGallery() async {
    if (_atlasBusy || !widget.service.isOffline) return;
    if (_draft != null) {
      _change(() {
        _flowOpen = true;
        _resumePrompt = false;
      });
      showNotice(context, 'Önce mevcut çalışmanı tamamla veya taslağı sil.');
      return;
    }
    if (!await _consent() || !mounted) return;
    final now = DateTime.now().toUtc().toIso8601String();
    final id = const Uuid().v4();
    await _save(
      ContributionDraft(
        id: id,
        rootId: id,
        groupId: const Uuid().v4(),
        createdAt: now,
        consentedAt: now,
        kind: ContributionKind.photoSet,
        galleryStart: true,
      ),
    );
    _change(() {
      _flowOpen = true;
      _resumePrompt = false;
    });
    await _setGallery();
  }

  Future<void> _setGallery({
    PhotoSurface surface = PhotoSurface.cup,
    ContributionPhoto? replace,
  }) async {
    if (_atlasBusy || _draft == null || _draft!.queued) return;
    _change(() => _busy = true);
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
        showNotice(
          context,
          'Fotoğraflar eklenemedi. En fazla 3 fincan ve 1 tabak seçebilirsin. Önceki fotoğrafların korunuyor.',
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

  Widget _photoSetDraft() {
    final draft = _draft!;
    final disabled = _atlasBusy || draft.queued;
    final selecting = !draft.cupSelectionDone;
    return PageBody(
      children: [
        Text(
          draft.photoSummary,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (draft.isGallery && draft.cups.length < 3)
          const AtlasNotice(
            'Farklı açılardan üç fotoğraf ekleyebilirsin. Tek fincan fotoğrafıyla da devam edebilirsin.',
          ),
        if (draft.complete)
          const AtlasNotice(
            'Fotoğrafların netliğini ve aynı fincana ait olduğunu kontrol et. Tabak varsa bu fincana ait olmalı.',
          ),
        for (final p in draft.photos) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(p.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  AtlasPhoto(
                    photo: p,
                    image: FileImage(widget.store.file(p.localName)),
                    height: 190,
                  ),
                  if (p.surface == PhotoSurface.cup && p.origin == 'gallery')
                    DropdownButtonFormField<String>(
                      key: ValueKey('${p.id}-${p.angle?.name}'),
                      initialValue:
                          (p.angle == CaptureRole.top
                                  ? CaptureRole.free
                                  : p.angle)
                              ?.name ??
                          'unknown',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Fotoğrafın açısı',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'unknown',
                          child: Text('Açı belirtilmedi'),
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
                            DropdownMenuItem(
                              value: angle.name,
                              child: Text(angle.title),
                            ),
                      ],
                      onChanged: disabled
                          ? null
                          : (v) {
                              if (v != null) _setAngle(p, v);
                            },
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: disabled
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
                        icon: const Icon(Icons.refresh),
                        label: Text(
                          p.surface == PhotoSurface.saucer
                              ? 'Tabak çek'
                              : 'Değiştir',
                        ),
                      ),
                      if (p.surface == PhotoSurface.saucer)
                        TextButton(
                          onPressed: disabled
                              ? null
                              : () => _setGallery(
                                  surface: PhotoSurface.saucer,
                                  replace: p,
                                ),
                          child: const Text('Galeriden değiştir'),
                        ),
                      TextButton(
                        onPressed: disabled ? null : () => _removeSetPhoto(p),
                        child: const Text('Kaldır'),
                      ),
                      if (draft.isGallery && p.surface == PhotoSurface.cup) ...[
                        IconButton(
                          tooltip: 'Öne taşı',
                          onPressed: disabled || draft.cups.first.id == p.id
                              ? null
                              : () => _moveSetPhoto(p, -1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: 'Sona taşı',
                          onPressed: disabled || draft.cups.last.id == p.id
                              ? null
                              : () => _moveSetPhoto(p, 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                      ],
                    ],
                  ),
                  _photoCheckNotice(p),
                  if (draft.complete) Text(_decisionText(p)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (draft.isGallery && draft.cups.length < 3)
          OutlinedButton.icon(
            onPressed: disabled ? null : _setGallery,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Fincan fotoğrafı ekle'),
          ),
        if (!draft.isGallery && draft.cups.length < 3)
          FilledButton.icon(
            onPressed: disabled ? null : _continueAtlasCapture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Çekime Devam Et'),
          ),
        if (selecting && draft.cupsComplete)
          FilledButton(
            onPressed: disabled
                ? null
                : () => _save(draft.copy(cupSelectionDone: true)),
            child: const Text('Bu fotoğraflarla devam et'),
          ),
        if (draft.cupSelectionDone && !draft.saucerDecided) ...[
          Text(
            'Tabak fotoğrafı da eklemek ister misin?',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Text(
            'İsteğe bağlı. Tabak eklemeden de falını oluşturabilirsin.',
          ),
        ],
        if (draft.cupSelectionDone && draft.saucers.isEmpty) ...[
          OutlinedButton.icon(
            onPressed: disabled ? null : _setSaucerCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Tabak çek'),
          ),
          OutlinedButton.icon(
            onPressed: disabled
                ? null
                : () => _setGallery(surface: PhotoSurface.saucer),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galeriden tabak seç'),
          ),
          if (!draft.saucerDecided)
            FilledButton(
              onPressed: disabled
                  ? null
                  : () => _save(draft.copy(saucerDecided: true)),
              child: const Text('Tabaksız devam et'),
            ),
        ],
        if (draft.complete) ...[
          if (draft.photos.length > 1)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _sameSample,
              title: const Text(
                'Fotoğraflar aynı fincana ve varsa ona ait tabağa ait.',
              ),
              onChanged: disabled
                  ? null
                  : (v) => _change(() => _sameSample = v == true),
            ),
          const Text(
            'Şekil bulman gerekmiyor. İnceleme ekranından atlayabilirsin.',
          ),
        ],
        if (_atlasBusy) ...[const LinearProgressIndicator(), Text(_saveLabel)],
        TextButton(
          onPressed: disabled ? null : _discard,
          child: const Text('Taslağı sil'),
        ),
      ],
    );
  }
}
