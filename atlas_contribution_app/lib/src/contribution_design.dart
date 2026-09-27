part of 'contribution_home.dart';

extension _AtlasHomePresentation on _ContributionHomeState {
  bool get _atlasBusy => _busy || _sequenceRunning;
  String _photoIdentity(ContributionPhoto p) => '${p.localName}|${p.checksum}';

  Future<void> _startAtlas() async {
    if (_atlasBusy) return;
    if (_draft == null) await _new();
    if (!mounted || _draft == null) return;
    _change(() {
      _flowOpen = true;
      _resumePrompt = false;
    });
    await _continueAtlasCapture();
  }

  Future<void> _continueAtlasCapture() async {
    if (_atlasBusy || _draft == null || _draft!.isGallery || _draft!.queued) {
      return;
    }
    _change(() => _sequenceRunning = true);
    try {
      while (mounted && _draft != null && !_draft!.cupsComplete) {
        final before = _draft!.cups.length;
        await _capture(
          _draft!.captureRoles.firstWhere((r) => _draft!.photo(r) == null),
        );
        // Cancellation and failed durable writes both stop the sequence.
        if (_draft == null || _draft!.cups.length == before) break;
      }
      if (_draft?.isSet == true && _draft!.cupsComplete) {
        await _save(_draft!.copy(cupSelectionDone: true));
      }
    } finally {
      _change(() => _sequenceRunning = false);
    }
  }

  Future<void> _atlasGallery() async {
    await _pickGallery();
    if (mounted && _draft != null) _change(() => _flowOpen = true);
  }

  Future<void> _atlasAnnotations() async {
    final draft = _draft;
    if (_atlasBusy || draft == null || draft.queued) return;
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AnnotationSequence(
          photos: draft.photos,
          imageFor: (p) => FileImage(widget.store.file(p.localName)),
          onSave: (p) async {
            await _save(_draft!.withPhoto(p));
          },
        ),
      ),
    );
    _change(() {});
  }

  Future<void> _atlasExport() async {
    if (_atlasBusy) return;
    _change(() => _busy = true);
    try {
      await widget.onExport?.call();
    } catch (error) {
      if (mounted) {
        await showResearchExportFailure(
          context,
          error,
          openPermissions: widget.onReview,
        );
      }
    } finally {
      _change(() => _busy = false);
    }
  }

  Future<void> _atlasEdit(Map<String, dynamic> row) async {
    if (_draft != null) return;
    final old = ContributionDraft.fromJson(
      Map<String, dynamic>.from(row['document'] as Map),
    );
    for (final photo in old.photos) {
      if (!await widget.store.file(photo.localName).exists()) {
        final bytes = await widget.service.readPhoto(old.id, photo);
        await widget.store
            .file(photo.localName)
            .writeAsBytes(bytes, flush: true);
      }
    }
    await _save(
      ContributionDraft(
        id: const Uuid().v4(),
        rootId: old.rootId,
        groupId: old.groupId,
        revision: old.revision + 1,
        supersedesId: old.id,
        createdAt: DateTime.now().toUtc().toIso8601String(),
        consentedAt: old.consentedAt,
        kind: ContributionKind.photoSet,
        galleryStart: old.isGallery,
        cupSelectionDone: true,
        saucerDecided: old.isSet ? old.saucerDecided : false,
        photos: old.photos.map((p) => p.asSetPhoto()),
      ),
    );
    if (!mounted) return;
    Navigator.popUntil(context, (route) => route.isFirst);
    _change(() {
      _tab = 0;
      _flowOpen = true;
      _sameSample = false;
      _usable.clear();
    });
  }

  Widget _buildAtlas() {
    final inFlow = _flowOpen && _draft != null;
    return PopScope(
      canPop: !inFlow && _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_atlasBusy) {
          _change(() {
            _flowOpen = false;
            _tab = 0;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: inFlow
              ? IconButton(
                  tooltip: 'Ana sayfaya dön',
                  onPressed: _atlasBusy
                      ? null
                      : () => _change(() => _flowOpen = false),
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          title: inFlow
              ? Text(
                  _draft!.isGallery
                      ? 'Fotoğrafını İncele'
                      : 'Çekimlerini Doğrula',
                )
              : _tab == 0
              ? const AtlasBrand()
              : Text(_tab == 1 ? 'Kayıtlarım' : 'Ayarlar'),
        ),
        bottomNavigationBar: inFlow
            ? null
            : NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: _atlasBusy
                    ? null
                    : (index) => _change(() => _tab = index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon: Icon(Icons.home),
                    label: 'Ana Sayfa',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.history),
                    label: 'Kayıtlarım',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: 'Ayarlar',
                  ),
                ],
              ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : inFlow
            ? _atlasDraft()
            : _tab == 1
            ? ContributionHistory(
                key: ValueKey(_draft?.id),
                store: widget.store,
                service: widget.service,
                canStart: _draft == null,
                modern: true,
                embedded: true,
                currentDraft: _draft,
                recordState: widget.recordState,
                onContinue: _startAtlas,
                onReadFortune: widget.onReadFortune,
                onEdit: _atlasEdit,
                onRepeat: (group) async {
                  Navigator.popUntil(context, (route) => route.isFirst);
                  await _new(groupId: group);
                  if (mounted) _change(() => _tab = 0);
                  await _startAtlas();
                },
              )
            : _tab == 2
            ? _atlasSettings()
            : _atlasLanding(),
      ),
    );
  }

  Widget _atlasLanding() => PageBody(
    children: [
      if (_error != null) ...[AtlasNotice(_error!), const SizedBox(height: 16)],
      const SizedBox(height: 20),
      const Center(child: AtlasBrand(size: 192, showName: false)),
      const SizedBox(height: 16),
      Center(
        child: Text(
          '3 Açılı Çekim',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: atlasSage),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        'Fincanını Keşfet',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 12),
      Text(
        widget.onReadFortune == null
            ? 'Üç açıdan çek, gördüğün şekilleri işaretle ve gözlemlerini kaydet.'
            : 'Üç açıdan çek, gördüğün şekilleri işaretle, falını oku.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 20),
      const AtlasNotice(
        'Fotoğrafların AI’ya gönderilmez; yalnız metinsel özet paylaşılır.',
        icon: Icons.shield_outlined,
      ),
      const SizedBox(height: 24),
      if (_draft != null) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Fincanın seni bekliyor',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('${_draft!.photoSummary} kayıtlı'),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _atlasBusy ? null : _startAtlas,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Kaldığın Yerden Devam Et'),
                ),
              ],
            ),
          ),
        ),
      ] else
        FilledButton.icon(
          onPressed: _atlasBusy || _error != null ? null : _startAtlas,
          icon: const Icon(Icons.camera_alt, color: Color(0xff22c55e)),
          label: const Text('Fincanını Tara'),
        ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _atlasBusy ? null : _atlasGallery,
        icon: const Icon(Icons.photo_library_outlined),
        label: const Text('Galeriden Seç'),
      ),
      const SizedBox(height: 8),
      const Text(
        '1–3 fincan fotoğrafıyla falını oluştur. Üç farklı açı önerilir; tabak isteğe bağlıdır.',
        textAlign: TextAlign.center,
      ),
    ],
  );

  Widget _atlasSettings() => PageBody(
    children: [
      const AtlasNotice(
        'Fotoğrafların ve gözlemlerin bu telefonda saklanır. Araştırma paketini dışa aktarmayı sen yönetirsin.',
      ),
      const SizedBox(height: 20),
      if (widget.onAiSettings != null) ...[
        OutlinedButton.icon(
          onPressed: _atlasBusy ? null : widget.onAiSettings,
          icon: const Icon(Icons.science_outlined),
          label: const Text('AI Laboratuvarı · Test'),
        ),
        const SizedBox(height: 12),
      ],
      if (widget.onReview != null) ...[
        OutlinedButton.icon(
          onPressed: _atlasBusy ? null : widget.onReview,
          icon: const Icon(Icons.manage_search),
          label: const Text('İnceleme Araçları'),
        ),
        const SizedBox(height: 12),
      ],
      if (widget.onExport != null) ...[
        const Text(
          'Çekim ve galeri kayıtlarının izinli fotoğrafları ile işaretlerini ZIP olarak kaydeder.',
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _atlasBusy ? null : _atlasExport,
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Araştırma Paketini Dışa Aktar'),
        ),
      ],
      if (_busy) const LinearProgressIndicator(),
    ],
  );

  Widget _atlasDraft() {
    final draft = _draft!;
    if (draft.isSet) return _photoSetDraft();
    final confirmed =
        draft.isGallery ||
        (_sameSample &&
            draft.photos.every((p) => _usable.contains(_photoIdentity(p))));
    return PageBody(
      children: [
        Text(
          '${draft.photos.length} / ${draft.requiredPhotos} fotoğraf',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (!draft.isGallery)
          const AtlasNotice(
            'Fotoğrafların aynı fincana ait olduğunu ve telvenin net göründüğünü kontrol et.',
          ),
        const SizedBox(height: 16),
        for (final p in draft.photos) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          p.title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: '${p.title} yeniden çek',
                        onPressed: _atlasBusy || draft.queued
                            ? null
                            : () async {
                                if (draft.isGallery) {
                                  await _pickGallery(replace: true);
                                } else {
                                  await _capture(p.role!);
                                }
                              },
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  AtlasPhoto(
                    photo: p,
                    image: FileImage(widget.store.file(p.localName)),
                    height: 190,
                  ),
                  const SizedBox(height: 8),
                  if (!draft.isGallery)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _usable.contains(_photoIdentity(p)),
                      title: const Text(
                        'Telve net ve kullanılabilir görünüyor',
                      ),
                      onChanged: _atlasBusy || draft.queued
                          ? null
                          : (v) => _change(() {
                              if (v == true) {
                                _usable.add(_photoIdentity(p));
                              } else {
                                _usable.remove(_photoIdentity(p));
                              }
                            }),
                    ),
                  Text(_decisionText(p)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (!draft.complete && !draft.isGallery)
          FilledButton.icon(
            onPressed: _atlasBusy ? null : _continueAtlasCapture,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Çekime Devam Et'),
          ),
        if (draft.complete) ...[
          if (!draft.isGallery)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _sameSample,
              title: const Text('Üç fotoğraf aynı fincan / telve grubuna ait.'),
              onChanged: _atlasBusy || draft.queued
                  ? null
                  : (v) => _change(() => _sameSample = v == true),
            ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _atlasBusy || draft.queued || !confirmed
                ? null
                : _atlasAnnotations,
            icon: const Icon(Icons.draw_outlined),
            label: Text(
              draft.reviewed
                  ? 'İşaretleri Gözden Geçir'
                  : 'Fotoğrafları Onayla · Şekilleri İncele',
            ),
          ),
          const SizedBox(height: 12),
          _saveActions(!_atlasBusy && draft.reviewed && confirmed),
          if (!draft.reviewed)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Şekil bulman gerekmiyor. İnceleme ekranından atlayabilirsin.',
              ),
            ),
        ],
        if (_atlasBusy) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
          Text(
            _savePhase == _SavePhase.saving ||
                    _savePhase == _SavePhase.analyzing
                ? _saveLabel
                : 'İşlem sürüyor…',
          ),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: _atlasBusy ? null : _discard,
          child: const Text('Taslağı sil'),
        ),
      ],
    );
  }
}

extension _AtlasHistoryPresentation on _ContributionHistoryState {
  Widget _atlasHistory() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < 3; i++)
              ChoiceChip(
                label: Text(['Tümü', 'Kayıtlı', 'Taslaklar'][i]),
                selected: _filter == i,
                selectedColor: const Color(0xffeaf2ec),
                onSelected: (_) => _changeFilter(i),
              ),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_message != null) AtlasNotice(_message!),
              if (_filter != 1 && widget.currentDraft != null) ...[
                Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: const Text('Yarım kalan çalışman'),
                    subtitle: Text(
                      '${widget.currentDraft!.photoSummary} · Taslak',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: widget.onContinue,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_filter != 2)
                for (final row in _rows) ...[
                  _atlasRecordCard(row),
                  const SizedBox(height: 12),
                ],
              if (!_busy &&
                  (_filter == 2
                      ? widget.currentDraft == null
                      : _rows.isEmpty &&
                            (_filter == 1 || widget.currentDraft == null)))
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text(
                    'Burada henüz kayıt yok.',
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _atlasRecordCard(Map<String, dynamic> row) {
    final draft = ContributionDraft.fromJson(
      Map<String, dynamic>.from(row['document'] as Map),
    );
    final date = DateTime.tryParse(
      row['submitted_at'] as String? ?? draft.createdAt,
    )?.toLocal();
    final count = draft.photos.fold<int>(0, (sum, p) => sum + p.regions.length);
    final status = _recordStates[row['root_id']] ?? 'Telefona kaydedildi';
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _busy
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ContributionHistory(
                      store: widget.store,
                      service: widget.service,
                      canStart: widget.canStart,
                      onEdit: widget.onEdit,
                      onRepeat: widget.onRepeat,
                      onReadFortune: widget.onReadFortune,
                      modern: true,
                      onlyRoot: row['root_id'] as String,
                      recordState: widget.recordState,
                    ),
                  ),
                );
                if (mounted) await _refresh();
              },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (draft.photos.isNotEmpty)
                    SizedBox(
                      width: 72,
                      child: AtlasPhoto(
                        photo: draft.photos.first,
                        image: FileImage(
                          widget.store.file(draft.photos.first.localName),
                        ),
                        height: 72,
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${draft.isGallery ? 'Galeri İncelemesi' : 'Fincanın Hikâyesi'}${date == null ? '' : ' · ${date.day}.${date.month}'}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text('${draft.photoSummary} · $count işaret'),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Text(status, style: const TextStyle(color: atlasSage)),
            ],
          ),
        ),
      ),
    );
  }
}
