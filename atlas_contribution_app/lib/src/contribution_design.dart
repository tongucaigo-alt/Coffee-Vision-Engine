part of 'contribution_home.dart';

extension _AtlasHomePresentation on _ContributionHomeState {
  bool get _hasTarot => widget.tarotPage != null;
  int get _historyTab => _hasTarot ? 2 : 1;
  int get _settingsTab => _hasTarot ? 3 : 2;
  bool get _atlasBusy => _busy || _sequenceRunning;
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

  Widget _coffeeSecondaryActions(VoidCallback? save) => CoffeeActions([
    CoffeeAction(
      _savePhase == _SavePhase.idle ? 'Yalnız Kaydet' : _saveLabel,
      save,
    ),
    CoffeeAction(
      'Taslağı sil',
      _atlasBusy || _draft?.queued == true ? null : _discard,
    ),
  ]);

  Widget _atlasFlowActions() {
    final draft = _draft!;
    final disabled = _atlasBusy || draft.queued;
    final selecting = draft.isSet && !draft.cupSelectionDone;
    final saucer =
        draft.isSet && draft.cupSelectionDone && !draft.saucerDecided;
    final same = draft.photos.length == 1 || _sameSample;
    final hint = draft.queued
        ? 'Çalışman gönderim kuyruğunda.'
        : _atlasBusy
        ? 'İşlem tamamlanıyor…'
        : !draft.cupsComplete
        ? draft.isGallery
              ? 'Devam etmek için bir fincan fotoğrafı seç.'
              : 'Üç açıdan çekimi tamamla (${draft.cups.length}/3).'
        : !selecting && !saucer && !same
        ? 'Aynı fincanı onayla.'
        : null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              liveRegion: true,
              child: Text(
                hint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ),
        if (selecting || saucer) ...[
          AtlasPrimaryButton(
            onPressed: disabled || !draft.cupsComplete
                ? null
                : () => _save(
                    selecting
                        ? draft.copy(cupSelectionDone: true)
                        : draft.copy(saucerDecided: true),
                  ),
            child: Text(
              selecting ? 'Bu fotoğraflarla devam et' : 'Tabaksız devam et',
              textAlign: TextAlign.center,
            ),
          ),
          _coffeeSecondaryActions(null),
        ] else ...[
          AtlasPrimaryButton.icon(
            onPressed: disabled || !draft.complete || !same
                ? null
                : _atlasAnnotations,
            icon: const Icon(Icons.draw_outlined, size: 20),
            label: Text(
              draft.reviewed ? 'İşaretleri Gözden Geçir' : 'Şekilleri Seç',
            ),
          ),
          if (draft.reviewed) ...[
            if (widget.onGenerateFortune != null) const SizedBox(height: 8),
            _saveActions(
              !_atlasBusy &&
                  same &&
                  (!draft.queued || _savePhase == _SavePhase.failed),
            ),
          ] else
            _coffeeSecondaryActions(
              disabled || !draft.complete || !same ? null : _saveWithoutShapes,
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
  }

  Future<void> _atlasAnnotations() async {
    final draft = _draft;
    if (_atlasBusy || draft == null || draft.queued) return;
    _change(() => _busy = true);
    try {
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
        child: Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: inFlow
                ? 56 +
                      24 *
                          (MediaQuery.textScalerOf(context).scale(16) / 16 - 1)
                              .clamp(0, 1)
                : _tab == 0
                ? 72
                : null,
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
                : _tab == 0
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
                              'Kahve Ritüeli',
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
            actions: !inFlow && _tab == 0
                ? [
                    Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: IconButton.filled(
                        tooltip: 'Üye Girişi',
                        onPressed: () => _atlasPlaceholderInfo('Üye Girişi'),
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
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _atlasFlowActions(),
                  ),
                )
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
                              label: 'Ana Sayfa',
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
                        if (_tab == 0) _atlasLandingFooter(),
                      ],
                    ),
                  ),
                ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : inFlow
              ? _atlasDraft()
              : _hasTarot && _tab == 1
              ? widget.tarotPage!
              : _tab == _historyTab
              ? ContributionHistory(
                  key: ValueKey(_draft?.id),
                  store: widget.store,
                  service: widget.service,
                  canStart: _draft == null,
                  modern: true,
                  embedded: true,
                  currentDraft: _draft,
                  recordState: widget.recordState,
                  recordStarred: widget.recordStarred,
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
              : _tab == _settingsTab
              ? _atlasSettings()
              : _atlasLanding(),
        ),
      ),
    );
  }

  Widget _atlasLanding() => SafeArea(
    bottom: false,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxHeight < 390;
        final compact =
            short || MediaQuery.textScalerOf(context).scale(16) > 22;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const IgnorePointer(
                    child: CustomPaint(
                      key: ValueKey('atlas-home-frame'),
                      painter: _AtlasOrnamentalFramePainter(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                      children: [
                        if (_error != null) AtlasNotice(_error!),
                        const Spacer(),
                        if (short)
                          const AtlasBrand(size: 40, showName: false)
                        else
                          _atlasLandingHero(compact),
                        const SizedBox(height: 8),
                        const Text(
                          'Fincanını Keşfet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Literata',
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (!short)
                          Text(
                            widget.onReadFortune == null
                                ? 'Fincanının fotoğrafını çek, gözlemlerini keşfet.'
                                : constraints.maxHeight < 500
                                ? 'Fotoğrafını çek, birlikte okuyalım.'
                                : 'Fincanının fotoğrafını çek, kahvenin hikâyesini birlikte okuyalım.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: atlasMuted,
                            ),
                          ),
                        const Spacer(),
                        if (short)
                          Row(
                            children: [
                              Expanded(child: _atlasLandingGalleryButton()),
                              const SizedBox(width: 8),
                              Expanded(child: _atlasLandingScanButton(true)),
                            ],
                          )
                        else ...[
                          _atlasLandingGalleryButton(),
                          const SizedBox(height: 8),
                          _atlasLandingScanButton(compact),
                        ],
                      ],
                    ),
                  ),
                  if (_draft != null && !_draft!.queued)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
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
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  Future<void> _atlasPlaceholderInfo(String label) => showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(label),
      content: Text(switch (label) {
        'Üye Girişi' => 'Üyelik bu test sürümünde henüz kullanılamıyor.',
        'Gizlilik Politikası' =>
          'Gizlilik politikası sayfası henüz hazırlanıyor. Bu bağlantı şu an taslak.',
        'Destek' =>
          'Destek sayfası henüz hazırlanıyor. Bu bağlantı şu an taslak.',
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

  Widget _atlasLandingFooter() => SafeArea(
    top: false,
    bottom: false,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      // Explain unavailable destinations without inventing pages or services.
      child: Row(
        key: const ValueKey('atlas-home-footer'),
        children: [
          Expanded(child: _atlasLandingPlaceholder('Gizlilik Politikası')),
          Expanded(child: _atlasLandingPlaceholder('İçerik Bildir')),
          Expanded(child: _atlasLandingPlaceholder('Destek')),
        ],
      ),
    ),
  );
  Widget _atlasLandingHero(bool compact) {
    final emblem = SizedBox(
      width: compact ? 56 : 136,
      height: compact ? 56 : 136,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color(0xffeee1d2), atlasCream]),
        ),
        child: Center(
          child: AtlasBrand(size: compact ? 52 : 128, showName: false),
        ),
      ),
    );
    final caption = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.camera_alt_outlined, size: 13, color: atlasSageInk),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            '3 Açılı Çekim',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: atlasSageInk,
              letterSpacing: .2,
            ),
          ),
        ),
      ],
    );
    return Column(children: [emblem, const SizedBox(height: 12), caption]);
  }

  Widget _atlasLandingGalleryButton() => SizedBox(
    width: double.infinity,
    child: TextButton(
      onPressed: _atlasBusy ? null : _atlasGallery,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        foregroundColor: atlasCopperInk,
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          decoration: TextDecoration.underline,
        ),
      ),
      child: const Text('Galeriden Seç', textAlign: TextAlign.center),
    ),
  );

  Widget _atlasLandingScanButton(bool compact) => SizedBox(
    width: double.infinity,
    child: AtlasPrimaryButton.icon(
      onPressed: _atlasBusy || _error != null ? null : _startNewCamera,
      style: FilledButton.styleFrom(
        textStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
        minimumSize: Size(48, compact ? 48 : 56),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        backgroundColor: atlasCoffee,
        foregroundColor: atlasCard,
        elevation: 2,
        shadowColor: atlasCoffee.withValues(alpha: .2),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: const Icon(Icons.camera_alt, size: 20, color: atlasCard),
      label: const Text('Fincanını Tara', textAlign: TextAlign.center),
    ),
  );

  Widget _atlasLandingPlaceholder(String label) => TextButton(
    onPressed: () => _atlasPlaceholderInfo(label),
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      foregroundColor: atlasMuted,
      disabledForegroundColor: atlasMuted,
      shape: const StadiumBorder(),
      textStyle: const TextStyle(
        fontFamily: 'Plus Jakarta Sans',
        fontSize: 10.5,
      ),
    ),
    child: Text(label, textAlign: TextAlign.center),
  );
  Widget _atlasSettings() => PageBody(
    children: [
      const Text(
        'Sana ait, senin kontrolünde.',
        style: TextStyle(fontFamily: 'Literata', fontSize: 22, height: 1.4),
      ),
      const SizedBox(height: 20),
      const AtlasNotice(
        'Fotoğrafların ve gözlemlerin bu telefonda saklanır. Fal hizmetine yalnız metinsel özet gönderilir. Araştırma paylaşımını kayıt bazında sen yönetirsin. Yıldızsız kayıtlar da otomatik silinmez.',
      ),
      const SizedBox(height: 20),
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
      if (widget.onExport != null) ...[
        _atlasSettingsItem(
          onPressed: _atlasBusy ? null : _atlasExport,
          icon: Icons.file_download_outlined,
          label: 'Araştırma Paketini Dışa Aktar',
          description:
              'Çekim ve galeri kayıtlarının izinli fotoğrafları ile işaretlerini ZIP olarak kaydeder.',
        ),
      ],
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
            child: CoffeeActions([
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
        if (draft.complete && !draft.isGallery)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _sameSample,
            title: const Text(
              'Üç fotoğraf aynı fincan / telve grubuna ait.',
              style: TextStyle(fontSize: 12),
            ),
            onChanged: disabled
                ? null
                : (v) => _change(() => _sameSample = v == true),
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
                      modern: true,
                      onlyRoot: row['root_id'] as String,
                      recordState: widget.recordState,
                      recordStarred: widget.recordStarred,
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
class _AtlasOrnamentalFramePainter extends CustomPainter {
  const _AtlasOrnamentalFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 100 || size.height < 100) return;
    final bounds = Offset.zero & size;
    final readingArea = Rect.fromLTRB(
      20,
      16,
      size.width - 20,
      size.height - 16,
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(bounds),
        Path()..addRect(readingArea),
      ),
    );
    final copper = Paint()
      ..color = const Color(0x46b0714f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..strokeCap = StrokeCap.round;
    final sage = Paint()
      ..color = const Color(0x507ba294)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..strokeCap = StrokeCap.round;
    final leafFill = Paint()
      ..color = const Color(0x287ba294)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(6), const Radius.circular(26)),
      copper,
    );
    // Short inner corner lines echo the concentric rings of the Atlas emblem.
    for (final right in [false, true]) {
      for (final bottom in [false, true]) {
        canvas.save();
        canvas.translate(right ? size.width : 0, bottom ? size.height : 0);
        canvas.scale(right ? -1 : 1, bottom ? -1 : 1);
        canvas.drawPath(
          Path()
            ..moveTo(10, 46)
            ..lineTo(10, 32)
            ..quadraticBezierTo(10, 10, 32, 10)
            ..lineTo(46, 10),
          copper,
        );
        canvas.restore();
      }
    }
    for (final bottom in [false, true]) {
      canvas.save();
      if (bottom) {
        canvas.translate(0, size.height);
        canvas.scale(1, -1);
      }
      final center = size.width / 2;
      canvas.drawRect(
        Rect.fromLTWH(center - 47, 0, 94, 14),
        Paint()..color = atlasCream,
      );
      for (final right in [false, true]) {
        canvas.save();
        canvas.translate(center, 8);
        canvas.scale(right ? 1 : -1, 1);
        canvas.drawPath(
          Path()
            ..moveTo(9, 0)
            ..quadraticBezierTo(27, 3, 43, -1),
          sage,
        );
        for (var i = 0; i < 3; i++) {
          final x = 15.0 + i * 9;
          _leaf(canvas, Offset(x, 1), false, leafFill, sage);
          _leaf(canvas, Offset(x + 4, 1), true, leafFill, sage);
        }
        canvas.restore();
      }
      canvas.drawPath(
        Path()
          ..moveTo(center, 4)
          ..lineTo(center + 3, 8)
          ..lineTo(center, 12)
          ..lineTo(center - 3, 8)
          ..close(),
        copper,
      );
      canvas.restore();
    }
    canvas.restore();
  }

  void _leaf(Canvas canvas, Offset root, bool down, Paint fill, Paint vein) {
    canvas.save();
    canvas.translate(root.dx, root.dy);
    canvas.scale(1, down ? -1 : 1);
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(-1, -4, 2, -6, 6, -6)
      ..cubicTo(6, -2, 3, 0, 0, 0)
      ..close();
    canvas.drawPath(leaf, fill);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(4.5, -4.5),
      vein,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AtlasOrnamentalFramePainter oldDelegate) =>
      false;
}
