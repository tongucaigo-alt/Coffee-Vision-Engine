part of 'contribution_home.dart';

extension _AtlasHomePresentation on _ContributionHomeState {
  bool get _atlasBusy => _busy || _sequenceRunning;
  String _photoIdentity(ContributionPhoto p) => '${p.localName}|${p.checksum}';

  Future<void> _startNewCamera() async {
    if (_atlasBusy || _startChoiceOpen) return;
    _startChoiceOpen = true;
    try {
      final draft = _draft;
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
                child: const Text('Taslağı sil ve yeni çekim başlat'),
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
      if (_draft != null) {
        await widget.store.clear();
        if (!mounted) return;
        _change(() {
          _draft = null;
          _usable.clear();
          _sameSample = false;
          _savePhase = _SavePhase.idle;
          _error = null;
        });
      }
      await _startAtlas();
    } catch (_) {
      if (mounted) {
        showNotice(
          context,
          'Yeni çekim başlatılamadı. Mevcut kayıtların korunuyor; tekrar dene.',
        );
      }
    } finally {
      _startChoiceOpen = false;
    }
  }

  Widget _atlasFlowActions() => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .4,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_draft!.reviewed) ...[
            OutlinedButton.icon(
              onPressed: _atlasBusy ? null : _atlasAnnotations,
              icon: const Icon(Icons.draw_outlined),
              label: const Text('İşaretleri Gözden Geçir'),
            ),
            const SizedBox(height: 8),
            _saveActions(
              !_atlasBusy && (_draft!.photos.length == 1 || _sameSample),
            ),
          ] else
            FilledButton.icon(
              onPressed:
                  _atlasBusy ||
                      !_draft!.complete ||
                      !(_draft!.photos.length == 1 || _sameSample)
                  ? null
                  : _atlasAnnotations,
              icon: const Icon(Icons.draw_outlined),
              label: const Text('Şekilleri İncele'),
            ),
        ],
      ),
    ),
  );

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
        data: Theme.of(context).copyWith(
          snackBarTheme: !inFlow && _tab == 0
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
            toolbarHeight: !inFlow && _tab == 0 ? 72 : null,
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
                                  ?.copyWith(fontSize: 10, color: atlasSage),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Text(_tab == 1 ? 'Kayıtlarım' : 'Ayarlar'),
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
                        if (_tab == 0) _atlasLandingFooter(),
                      ],
                    ),
                  ),
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
              : _tab == 2
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
        final compact =
            constraints.maxHeight < 500 ||
            _draft != null ||
            MediaQuery.textScalerOf(context).scale(16) > 22;
        return SingleChildScrollView(
          key: const ValueKey('atlas-home-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints.tightFor(
                width: (constraints.maxWidth - 40).clamp(0, 460),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 12).clamp(
                    0,
                    double.infinity,
                  ),
                ),
                child: IntrinsicHeight(
                  child: Stack(
                    fit: StackFit.passthrough,
                    children: [
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: ValueKey('atlas-home-frame'),
                            painter: _AtlasOrnamentalFramePainter(),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          compact ? 20 : 28,
                          16,
                          compact ? 20 : 28,
                          12,
                        ),
                        child: Column(
                          children: [
                            if (_draft != null) ...[
                              Text(
                                _draft!.photos.isEmpty
                                    ? 'Çekime hazır taslak'
                                    : '${_draft!.photoSummary} kayıtlı',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              FilledButton.icon(
                                onPressed: _atlasBusy ? null : _startAtlas,
                                icon: const Icon(Icons.play_arrow),
                                label: const Text('Kaldığın Yerden Devam Et'),
                              ),
                              const SizedBox(height: 12),
                            ],
                            if (_error != null) AtlasNotice(_error!),
                            if (!compact) const Spacer(),
                            _atlasLandingHero(compact),
                            SizedBox(height: compact ? 10 : 22),
                            Text(
                              'Fincanını Keşfet',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Literata',
                                fontSize: compact ? 20 : 26,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.onReadFortune == null
                                  ? 'Gözlemlerini keşfet.'
                                  : 'Kahvende bir hikâye.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: Color(0xff7c6b5e),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(height: compact ? 20 : 12),
                            SizedBox(
                              width: compact ? double.infinity : 192,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(48, 48),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xffcfbba9),
                                    width: .7,
                                  ),
                                ),
                                onPressed: _atlasBusy ? null : _atlasGallery,
                                icon: const Icon(
                                  Icons.photo_library_outlined,
                                  color: atlasSage,
                                ),
                                label: const Text('Galeriden Seç'),
                              ),
                            ),
                            SizedBox(height: compact ? 12 : 14),
                            _atlasLandingScanButton(compact),
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
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
      width: compact ? 76 : 136,
      height: compact ? 76 : 136,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [Color(0xffead9bf), atlasCream]),
        ),
        child: Center(
          child: AtlasBrand(size: compact ? 72 : 128, showName: false),
        ),
      ),
    );
    final caption = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.camera_alt_outlined, size: 13, color: atlasSage),
        const SizedBox(width: 5),
        Text(
          '3 Açılı Çekim',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: atlasSage,
            letterSpacing: .2,
          ),
        ),
      ],
    );
    return Column(children: [emblem, const SizedBox(height: 12), caption]);
  }

  Widget _atlasLandingScanButton(bool compact) => FilledButton(
    onPressed: _atlasBusy || _error != null ? null : _startNewCamera,
    style: FilledButton.styleFrom(
      textStyle: Theme.of(context).textTheme.labelLarge,
      minimumSize: const Size(96, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      backgroundColor: Colors.transparent,
      foregroundColor: atlasCoffee,
      disabledBackgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: const StadiumBorder(),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 60 : 66,
          height: compact ? 60 : 66,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xffdbcbb3), width: .8),
          ),
          child: Container(
            width: compact ? 52 : 58,
            height: compact ? 52 : 58,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xff4b3023), atlasCoffee],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x182c1810),
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.camera_alt,
              size: 23,
              color: Color(0xff71b285),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Fincanını Tara',
          style: TextStyle(
            fontFamily: 'Plus Jakarta Sans',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _atlasLandingPlaceholder(String label) => TextButton(
    onPressed: () => _atlasPlaceholderInfo(label),
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      foregroundColor: const Color(0xff887c70),
      disabledForegroundColor: const Color(0xff887c70),
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
          color: Color(0xfff0e9dd),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: atlasSage, size: 19),
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
                  color: Color(0xff887c70),
                ),
              ),
            ),
      trailing: const Icon(
        Icons.chevron_right,
        color: Color(0xffa99b8b),
        size: 18,
      ),
      onTap: onPressed,
    ),
  );

  Widget _atlasDraft() {
    final draft = _draft!;
    if (draft.isSet) return _photoSetDraft();
    return PageBody(
      children: [
        Text(
          '${draft.photos.length} / ${draft.requiredPhotos} fotoğraf',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        if (!draft.isGallery)
          const AtlasHint(
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
                  _photoCheckNotice(p),
                  Text(
                    _decisionText(p),
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xff887c70),
                    ),
                  ),
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
                    foregroundColor: _filter == i
                        ? atlasCream
                        : const Color(0xff817366),
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
                  color: const Color(0xffedf2eb),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: const BorderSide(color: Color(0xffdce5d9)),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: const Icon(
                      Icons.timelapse_rounded,
                      color: atlasSage,
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
                        color: Color(0xff6c7d68),
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: atlasSage,
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
                          color: Color(0xfff0e9dd),
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
                          color: Color(0xff887c70),
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
      color: const Color(0xfffffdf9),
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
                            color: Color(0xff887c70),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Color(0xffa99b8b),
                  ),
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
                      color: atlasSage,
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
                        color: Color(0xff887c70),
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
      ..color = const Color(0x46a67845)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..strokeCap = StrokeCap.round;
    final sage = Paint()
      ..color = const Color(0x504a7c59)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..strokeCap = StrokeCap.round;
    final leafFill = Paint()
      ..color = const Color(0x284a7c59)
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
