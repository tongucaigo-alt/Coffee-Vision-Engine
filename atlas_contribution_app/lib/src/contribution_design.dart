part of 'contribution_home.dart';

extension _AtlasHomePresentation on _ContributionHomeState {
  bool get _hasTarot => widget.tarotPage != null;
  int get _historyTab => _hasTarot ? 2 : 1;
  int get _settingsTab => _hasTarot ? 3 : 2;
  bool get _atlasBusy => _busy || _sequenceRunning || _saucerChoiceOpen;
  String _photoIdentity(ContributionPhoto p) => '${p.localName}|${p.checksum}';

  Future<void> _startNewCamera() => _startNewCoffee(gallery: false);

  Future<void> _startNewCoffee({required bool gallery}) async {
    if (_atlasBusy || _startChoiceOpen) return;
    if (gallery && !widget.service.isOffline) return;
    _startChoiceOpen = true;
    try {
      final draft = _draft;
      if (draft?.queued == true) {
        _change(() {
          _flowOpen = true;
          _resumePrompt = false;
        });
        showNotice(
          context,
          'Çalışman gönderim kuyruğunda. Gönderim durumunu buradan takip edebilirsin.',
        );
        return;
      }
      if (draft != null && draft.photos.isNotEmpty) {
        final choice = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Yarım kalan çalışman var'),
            content: Text(
              '${draft.photoSummary} içeren taslağına devam edebilir veya bu taslağı silerek yeni çekime başlayabilirsin. Kayıtlı falların korunur.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Vazgeç'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'continue'),
                child: const Text('Mevcut çalışmaya devam et'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, 'new'),
                child: Text(
                  gallery
                      ? 'Taslağı sil ve galeriden başlat'
                      : 'Taslağı sil ve yeni çekim başlat',
                ),
              ),
            ],
          ),
        );
        if (!mounted || choice == null) return;
        if (choice == 'continue') {
          await _startAtlas();
          return;
        }
      }
      if (_atlasBusy) return;
      if (gallery && (!await _consent() || !mounted)) return;
      if (_draft != null) {
        await widget.store.clear();
        if (!mounted) return;
        _change(() {
          _draft = null;
          _usable.clear();
          _sameSample = false;
          _savePhase = _SavePhase.idle;
          _error = null;
          _galleryRetry = null;
          _previewIndex = 0;
        });
      }
      if (gallery) {
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
      } else {
        await _startAtlas();
      }
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Yeni çalışma başlatılamadı. Mevcut kayıtların korunuyor; tekrar dene.',
        );
      }
    } finally {
      _startChoiceOpen = false;
    }
  }

  Widget _coffeeSecondaryActions(
    VoidCallback? save, {
    List<CoffeeAction> extra = const [],
  }) => CoffeeActionStrip([
    CoffeeAction(
      _savePhase == _SavePhase.idle ? 'Yalnız Kaydet' : _saveLabel,
      save,
    ),
    CoffeeAction(
      'Taslağı sil',
      _atlasBusy || _draft?.queued == true ? null : _discard,
    ),
    ...extra,
  ]);

  Widget _atlasFlowActions() {
    final draft = _draft!;
    final disabled = _atlasBusy || draft.queued;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (draft.reviewed)
          _saveActions(!disabled || _savePhase == _SavePhase.failed)
        else ...[
          AtlasPrimaryButton(
            onPressed: disabled || !draft.cupsComplete
                ? null
                : draft.isSet
                ? _continuePhotoSet
                : _atlasAnnotations,
            child: const Text(
              'Bu fotoğraflarla devam et',
              textAlign: TextAlign.center,
            ),
          ),
          _coffeeSecondaryActions(
            disabled || !draft.complete ? null : _saveWithoutShapes,
          ),
        ],
      ],
    );
  }

  Future<void> _saveWithoutShapes() async {
    if (_atlasBusy || _draft == null) return;
    _change(() => _sequenceRunning = true);
    try {
      for (final p in _draft!.photos.toList()) {
        if (p.decision == PhotoDecision.unreviewed) {
          await _save(
            _draft!.withPhoto(
              p.annotated(
                p.regions,
                p.regions.isEmpty
                    ? PhotoDecision.skipped
                    : PhotoDecision.marked,
              ),
            ),
          );
        }
      }
      await _send();
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Fotoğrafların korunuyor. Kaydetmeyi yeniden deneyebilirsin.',
        );
      }
    } finally {
      _change(() => _sequenceRunning = false);
    }
  }

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

  Future<void> _continueAtlasCapture({bool addRemaining = false}) async {
    if (_atlasBusy ||
        _draft == null ||
        _draft!.isGallery ||
        _draft!.queued ||
        (_draft!.cupsComplete && !addRemaining)) {
      return;
    }
    _change(() => _sequenceRunning = true);
    try {
      while (mounted && _draft != null && _draft!.cups.length < 3) {
        final before = _draft!.cups.length;
        await _capture(
          _draft!.captureRoles.firstWhere((r) => _draft!.photo(r) == null),
        );
        // Cancellation and failed durable writes both stop the sequence.
        if (_draft == null || _draft!.cups.length == before) break;
      }
      if (_draft?.isSet == true && _draft!.cupsComplete) {
        await _save(
          _draft!.copy(
            cupSelectionDone: true,
            captureSequenceFinished:
                _draft!.cups.length < 3 && _draft!.captureSequenceFinished,
          ),
        );
      }
    } finally {
      _change(() => _sequenceRunning = false);
    }
  }

  Future<void> _atlasGallery() async {
    await _pickGallery();
  }

  Future<void> _continuePhotoSet() async {
    final draft = _draft;
    if (_atlasBusy || draft == null || draft.queued || !draft.cupsComplete) {
      return;
    }
    _change(() => _sequenceRunning = true);
    try {
      if (!draft.cupSelectionDone || !draft.saucerDecided) {
        await _save(draft.copy(cupSelectionDone: true, saucerDecided: true));
      }
      if (mounted) await _atlasAnnotations(ownsSequence: true);
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Fotoğrafların korunuyor. Devam etmeyi yeniden deneyebilirsin.',
        );
      }
    } finally {
      _change(() => _sequenceRunning = false);
    }
  }

  Future<void> _atlasAnnotations({bool ownsSequence = false}) async {
    final draft = _draft;
    if (_busy ||
        _saucerChoiceOpen ||
        (_sequenceRunning && !ownsSequence) ||
        draft == null ||
        draft.queued) {
      return;
    }
    _change(() => _busy = true);
    String? initialFocus;
    try {
      try {
        initialFocus = await widget.loadReadingFocus?.call(draft.rootId);
      } catch (_) {
        if (mounted) {
          showNotice(
            context,
            'Konu seçimin okunamadı. Yeniden deneyebilirsin.',
          );
        }
        return;
      }
      for (final p in draft.photos) {
        if (!mounted) return;
        await _checkPhoto(p);
      }
    } finally {
      _change(() => _busy = false);
    }
    if (!mounted) return;
    final generate = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AnnotationSequence(
          photos: draft.photos,
          canGenerate: _fortunePhotosReady,
          initialFocus: initialFocus,
          onFocusChanged: widget.onReadingFocusChanged == null
              ? null
              : (focus) => widget.onReadingFocusChanged!(draft.rootId, focus),
          loadTraces: widget.loadAnnotationTraces == null
              ? null
              : () => widget.loadAnnotationTraces!(draft),
          onTraceShown: widget.onAnnotationTraceShown == null
              ? null
              : (photo) => widget.onAnnotationTraceShown!(draft, photo),
          imageFor: (p) => FileImage(widget.store.file(p.localName)),
          onSave: (p) async {
            await _save(_draft!.withPhoto(p));
          },
        ),
      ),
    );
    _change(() {});
    if (generate != null && mounted && _draft?.reviewed == true) {
      await _send(generate: generate);
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
        captureSequenceFinished: old.captureSequenceFinished,
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
      canPop: !inFlow && _tab == 0 && widget.preparation?.active != true,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && widget.preparation?.active == true) {
          widget.preparation!.cancel();
          return;
        }
        if (!didPop && !_atlasBusy) {
          _change(() {
            _flowOpen = false;
            _tab = 0;
          });
        }
      },
      child: Theme(
        data: (inFlow ? coffeeFlowTheme(Theme.of(context)) : Theme.of(context))
            .copyWith(
              snackBarTheme: inFlow
                  ? Theme.of(context).snackBarTheme.copyWith(
                      behavior: SnackBarBehavior.floating,
                      insetPadding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        MediaQuery.sizeOf(context).height * .4,
                      ),
                    )
                  : !inFlow && _tab == 0
                  ? Theme.of(context).snackBarTheme.copyWith(
                      behavior: SnackBarBehavior.floating,
                      insetPadding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        MediaQuery.textScalerOf(context).scale(16) > 22 ||
                                MediaQuery.sizeOf(context).height < 800
                            ? 184
                            : 224,
                      ),
                    )
                  : Theme.of(context).snackBarTheme,
            ),
        child: AtlasAtmosphereSurface(
          scene: inFlow ? AtlasAtmosphereScene.coffeePhoto : null,
          child: Scaffold(
            appBar: AppBar(
              automaticallyImplyLeading: false,
              toolbarHeight: inFlow
                  ? CoffeePhotoLayout.toolbarHeight
                  : _tab == 0 || (_hasTarot && _tab == 1)
                  ? 72
                  : null,
              flexibleSpace: inFlow ? _coffeeAngleHeader() : null,
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
                  ? const Text(
                      'Fotoğraflarına Bak',
                      style: TextStyle(fontFamily: 'Literata', fontSize: 18),
                    )
                  : _tab == 0 || (_hasTarot && _tab == 1)
                  ? Row(
                      children: [
                        const AtlasBrand(size: 32, showName: false),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Atlas',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                _tab == 0 ? 'Kahve Ritüeli' : 'Tarot',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      fontSize: 10,
                                      color: atlasCopperInk,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Text(
                      _hasTarot && _tab == 1
                          ? 'Tarot'
                          : _tab == _historyTab
                          ? 'Kayıtlarım'
                          : 'Ayarlar',
                    ),
              actions: !inFlow && (_tab == 0 || (_hasTarot && _tab == 1))
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: IconButton.filled(
                          tooltip: 'Bilgilerim',
                          onPressed: _atlasBusy
                              ? null
                              : () => Navigator.push<void>(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => UserProfilePage(
                                      store: UserProfileStore(
                                        Directory(
                                          '${widget.store.directory.parent.path}/user-profile',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            shape: const CircleBorder(),
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.transparent,
                            disabledForegroundColor: Colors.white,
                          ),
                          icon: Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: atlasCoffee,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 17,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ]
                  : null,
            ),
            bottomNavigationBar: inFlow
                ? null
                : SafeArea(
                    top: false,
                    child: MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      removeBottom: true,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          NavigationBar(
                            height: 76,
                            backgroundColor: atlasCream,
                            selectedIndex: _tab,
                            onDestinationSelected: _atlasBusy
                                ? null
                                : (index) => _change(() => _tab = index),
                            destinations: [
                              const NavigationDestination(
                                icon: Icon(Icons.home_outlined),
                                selectedIcon: Icon(Icons.home),
                                label: 'Kahve',
                              ),
                              if (_hasTarot)
                                const NavigationDestination(
                                  icon: Icon(Icons.style_outlined),
                                  selectedIcon: Icon(Icons.style),
                                  label: 'Tarot',
                                ),
                              const NavigationDestination(
                                icon: Icon(Icons.history),
                                label: 'Kayıtlarım',
                              ),
                              const NavigationDestination(
                                icon: Icon(Icons.settings_outlined),
                                label: 'Ayarlar',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : inFlow
                ? SafeArea(child: _atlasDraft())
                : _hasTarot && _tab == 1
                ? widget.tarotPage!
                : _tab == _historyTab
                ? _atlasRecords()
                : _tab == _settingsTab
                ? _atlasSettings()
                : _atlasLanding(),
          ),
        ),
      ),
    );
  }

  Widget _atlasRecords() {
    final coffee = ContributionHistory(
      key: ValueKey(_draft?.id),
      store: widget.store,
      service: widget.service,
      canStart: _draft == null,
      modern: true,
      embedded: true,
      currentDraft: _draft,
      recordState: widget.recordState,
      recordStarred: widget.recordStarred,
      loadRecordSummaries: widget.loadRecordSummaries,
      onContinue: _startAtlas,
      onReadFortune: widget.onReadFortune,
      onGenerateFortune: widget.onGenerateFortune,
      onEdit: _atlasEdit,
      onRepeat: (group) async {
        Navigator.popUntil(context, (route) => route.isFirst);
        await _new(groupId: group);
        if (mounted) _change(() => _tab = 0);
        await _startAtlas();
      },
    );
    if (widget.tarotHistoryPage == null) return coffee;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Kahve')),
              ButtonSegment(value: 1, label: Text('Tarot')),
            ],
            selected: {_recordsSection},
            onSelectionChanged: (value) =>
                _change(() => _recordsSection = value.single),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _recordsSection,
            children: [coffee, widget.tarotHistoryPage!],
          ),
        ),
      ],
    );
  }

  Widget _atlasLanding() => AtlasLandingLayout(
    hintsEnabled: !_atlasBusy && _error == null,
    frame: const CustomPaint(
      key: ValueKey('atlas-home-frame'),
      painter: AtlasHomeFramePainter(),
    ),
    content: Column(
      children: [
        if (_error != null) AtlasNotice(_error!),
        AtlasLandingContent(
          kicker: const Text(
            '3 AÇILI ÇEKİM',
            textAlign: TextAlign.center,
            style: AtlasLandingContent.kickerStyle,
          ),
          title: 'Fincanını Keşfet',
          description: 'Hikâyene bir fincanla başla',
        ),
      ],
    ),
    secondary: _atlasLandingGalleryButton(),
    primary: _atlasLandingScanButton(),
    resume: _draft != null && !_draft!.queued
        ? IconButton(
            key: const ValueKey('coffee-resume'),
            tooltip: 'Kaldığın Yerden Devam Et',
            onPressed: _atlasBusy ? null : _startAtlas,
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: atlasCoffee,
              minimumSize: const Size(48, 48),
            ),
            icon: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: atlasCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 22),
            ),
          )
        : null,
  );

  Future<void> _atlasPlaceholderInfo(String label) async {
    if (label == 'Gizlilik Politikası' || label == 'Destek') {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PrivacySupportPage(support: label == 'Destek'),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text(switch (label) {
          'Üye Girişi' => 'Üyelik bu test sürümünde henüz kullanılamıyor.',
          _ =>
            'Bir yorumu bildirmek için kayıtlı falını açıp “Bu yorumu bildir” düğmesini kullanabilirsin.',
        }),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Widget _atlasLandingGalleryButton() => AtlasLandingImageButton(
    key: const ValueKey('coffee-start-gallery'),
    asset: 'atlas_gallery_button.webp',
    label: 'Galeriden Seç',
    onPressed: _atlasBusy ? null : _atlasGallery,
  );

  Widget _atlasLandingScanButton() => AtlasLandingImageButton(
    key: const ValueKey('coffee-start-camera'),
    asset: 'atlas_camera_button.webp',
    label: 'Fincanını Tara',
    primary: true,
    onPressed: _atlasBusy || _error != null ? null : _startNewCamera,
  );

  Widget _atlasSettings() => PageBody(
    children: [
      const Text(
        'Sana ait, senin kontrolünde.',
        style: TextStyle(fontFamily: 'Literata', fontSize: 22, height: 1.4),
      ),
      const SizedBox(height: 20),
      const AtlasNotice(
        'Fotoğrafların ve gözlemlerin bu telefonda saklanır. Fal hizmetine yalnız metinsel özet gönderilir. Yıldızsız kayıtlar da otomatik silinmez.',
      ),
      const SizedBox(height: 20),
      AtlasHomeHintSettings(enabled: !_atlasBusy),
      const SizedBox(height: 8),
      if (widget.onOpenGuide != null) ...[
        _atlasSettingsItem(
          onPressed: _atlasBusy ? null : widget.onOpenGuide,
          icon: Icons.menu_book_outlined,
          label: 'Kullanım Rehberi',
        ),
        const SizedBox(height: 8),
      ],
      if (widget.onAiSettings != null) ...[
        _atlasSettingsItem(
          onPressed: _atlasBusy ? null : widget.onAiSettings,
          icon: Icons.science_outlined,
          label: playTestEnabled
              ? 'Atlas Test Bağlantısı'
              : 'AI Laboratuvarı · Test',
        ),
        const SizedBox(height: 8),
      ],
      if (widget.onReview != null) ...[
        _atlasSettingsItem(
          onPressed: _atlasBusy ? null : widget.onReview,
          icon: Icons.manage_search,
          label: 'İnceleme Araçları',
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 20),
      const Text(
        'Gizlilik ve Destek',
        style: TextStyle(fontFamily: 'Literata', fontSize: 18),
      ),
      const SizedBox(height: 8),
      for (final item in [
        (Icons.privacy_tip_outlined, 'Gizlilik Politikası'),
        (Icons.flag_outlined, 'İçerik Bildir'),
        (Icons.help_outline, 'Destek'),
      ])
        _atlasSettingsItem(
          icon: item.$1,
          label: item.$2,
          onPressed: () => _atlasPlaceholderInfo(item.$2),
        ),
      if (_busy) const LinearProgressIndicator(),
    ],
  );

  Widget _atlasSettingsItem({
    required IconData icon,
    required String label,
    String? description,
    required VoidCallback? onPressed,
  }) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      leading: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: atlasCard,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: atlasSageInk, size: 19),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1.5,
        ),
      ),
      subtitle: description == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                description,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: atlasMuted,
                ),
              ),
            ),
      trailing: const Icon(Icons.chevron_right, color: atlasMuted, size: 18),
      onTap: onPressed,
    ),
  );

  Widget _atlasDraft() {
    final draft = _draft!;
    if (draft.isSet) return _photoSetDraft();
    final index = _previewIndex.clamp(
      0,
      draft.photos.isEmpty ? 0 : draft.photos.length - 1,
    );
    final photo = draft.photos.isEmpty ? null : draft.photos[index];
    final disabled = _atlasBusy || draft.queued;
    return _coffeePreview(
      photo: photo,
      tools: [
        if (photo != null)
          SizedBox(
            width: double.infinity,
            child: CoffeeActionStrip([
              CoffeeAction(
                'Değiştir',
                disabled
                    ? null
                    : () async {
                        if (draft.isGallery) {
                          await _pickGallery(replace: true);
                        } else {
                          await _capture(photo.role!);
                        }
                      },
                icon: Icons.refresh,
                tooltip: '${photo.title} yeniden çek',
              ),
              if (draft.reviewed)
                CoffeeAction(
                  'İşaretler',
                  disabled ? null : _atlasAnnotations,
                  icon: Icons.draw_outlined,
                  tooltip: 'İşaretleri Gözden Geçir',
                ),
            ]),
          ),
      ],
      phase: [
        if (photo == null)
          CoffeeActions([
            CoffeeAction(
              draft.isGallery ? 'Galeriden fotoğraf seç' : 'Çekime Devam Et',
              disabled
                  ? null
                  : draft.isGallery
                  ? _startSetGallery
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
          ])
        else if (!draft.complete && !draft.isGallery)
          OutlinedButton.icon(
            onPressed: disabled ? null : _continueAtlasCapture,
            icon: const Icon(Icons.camera_alt, size: 20),
            label: const Text('Çekime Devam Et'),
          ),
      ],
    );
  }
}

extension _AtlasHistoryPresentation on _ContributionHistoryState {
  Widget _atlasHistory() => Column(
    children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
        child: Row(
          children: [
            for (var i = 0; i < 4; i++)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: TextButton(
                  style: TextButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    backgroundColor: _filter == i
                        ? atlasCoffee
                        : Colors.transparent,
                    foregroundColor: _filter == i ? atlasCream : atlasMuted,
                    textStyle: const TextStyle(
                      fontFamily: 'Plus Jakarta Sans',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  isSemanticButton: true,
                  onPressed: () => _changeFilter(i),
                  child: Semantics(
                    selected: _filter == i,
                    child: Text(
                      ['Tümü', 'Kayıtlı', 'Taslaklar', 'Yıldızlılar'][i],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              if (_busy) const LinearProgressIndicator(),
              if (_message != null) AtlasNotice(_message!),
              if ((_filter == 0 || _filter == 2) &&
                  widget.currentDraft != null) ...[
                Card(
                  color: atlasSageSurface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: atlasBorder),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(
                      Icons.timelapse_rounded,
                      color: atlasSageInk,
                      size: 24,
                    ),
                    title: const Text(
                      'Yarım kalan çalışman',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${widget.currentDraft!.photoSummary} · Taslak',
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.5,
                        color: atlasSageInk,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: atlasSageInk,
                      size: 20,
                    ),
                    onTap: widget.onContinue,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_filter != 2)
                for (final row in _rows.where(
                  (r) => _filter != 3 || _starredRoots.contains(r['root_id']),
                )) ...[_atlasRecordCard(row), const SizedBox(height: 12)],
              if (!_busy &&
                  (_filter == 2
                      ? widget.currentDraft == null
                      : _filter == 3
                      ? !_rows.any((r) => _starredRoots.contains(r['root_id']))
                      : _rows.isEmpty &&
                            (_filter == 1 || widget.currentDraft == null)))
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: MediaQuery.sizeOf(context).height < 700 ? 36 : 88,
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: atlasCard,
                        ),
                        alignment: Alignment.center,
                        child: const AtlasBrand(size: 64, showName: false),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        _filter == 2
                            ? 'Yarım kalan çalışman yok'
                            : _filter == 3
                            ? 'Henüz yıldızlı kaydın yok'
                            : 'İlk hikâyene yer var',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Literata',
                          fontSize: 21,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _filter == 2
                            ? 'Devam edebileceğin taslaklar burada görünür.'
                            : _filter == 3
                            ? 'Yıldızladığın kayıtlar burada görünür.'
                            : 'Kaydettiğin fincanlar burada görünür.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: atlasMuted,
                        ),
                      ),
                    ],
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
      color: atlasCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: atlasBorder, width: .8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
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
                      onGenerateFortune: widget.onGenerateFortune,
                      modern: true,
                      onlyRoot: row['root_id'] as String,
                      recordState: widget.recordState,
                      recordStarred: widget.recordStarred,
                      loadRecordSummaries: widget.loadRecordSummaries,
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
                      width: MediaQuery.textScalerOf(context).scale(16) > 22
                          ? 48
                          : 64,
                      child: AtlasPhoto(
                        photo: draft.photos.first,
                        image: FileImage(
                          widget.store.file(draft.photos.first.localName),
                        ),
                        height: MediaQuery.textScalerOf(context).scale(16) > 22
                            ? 48
                            : 64,
                      ),
                    ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          draft.isGallery
                              ? 'Galeri İncelemesi'
                              : 'Fincanın Hikâyesi',
                          style: const TextStyle(
                            fontFamily: 'Literata',
                            fontSize: 16,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${draft.photoSummary} · $count işaret',
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.5,
                            color: atlasMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, size: 18, color: atlasMuted),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 6,
                children: [
                  Text(
                    '${_starredRoots.contains(row['root_id']) ? '★ · ' : ''}$status',
                    style: const TextStyle(
                      color: atlasSageInk,
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                  if (date != null)
                    Text(
                      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.65,
                        color: atlasMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Static engraved border, clipped to a narrow band outside the reading area.
