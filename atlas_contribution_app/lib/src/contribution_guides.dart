part of 'contribution_home.dart';

extension _UmayHomeGuides on _ContributionHomeState {
  Widget _buildAtlas() {
    final inFlow = _flowOpen && _draft != null;
    final id = inFlow
        ? 'photos'
        : _hasTarot && _tab == 1
        ? 'tarot'
        : _tab == _historyTab
        ? (_recordsSection == 1 ? 'tarot-records' : 'records')
        : _tab == _settingsTab
        ? 'settings'
        : 'home';
    final definition = umayAppGuides.where((g) => g.id == id).first;
    return UmayGuideOnce(
      id: id,
      steps: definition.steps,
      ready:
          !_loading &&
          !_atlasBusy &&
          _error == null &&
          (!inFlow ||
              _draft!.photos.isNotEmpty &&
                  _checkingPhotos.isEmpty &&
                  _galleryError == null),
      child: _buildAtlasContent(),
    );
  }

  Future<void> _openUmayGuides() async {
    final controller = UmayGuideScope.maybeOf(context);
    if (controller == null) {
      await widget.onOpenGuide?.call();
      return;
    }
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => UmayGuidesHub(controller: controller)),
    );
    if (!mounted || id == null) return;
    if (id == 'legacy') {
      await widget.onOpenGuide?.call();
      return;
    }
    if (id == 'annotation') {
      await showUmayLesson(
        context,
        id: id,
        steps: umayAnnotationSteps,
        force: true,
        builder: (presented, finish) =>
            UmayAnnotationGuide(onPresented: presented, onFinish: finish),
      );
      return;
    }
    if (id == 'camera') {
      await showUmayLesson(
        context,
        id: id,
        steps: umayCameraSteps,
        force: true,
        builder: (presented, finish) =>
            UmayCameraGuide(onPresented: presented, onFinish: finish),
      );
      return;
    }
    controller.requestReplay(id);
    if (id == 'profile') {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => UserProfilePage(
            store: UserProfileStore(
              Directory('${widget.store.directory.parent.path}/user-profile'),
            ),
          ),
        ),
      );
      return;
    }
    if (id == 'connection') {
      await widget.onAiSettings?.call();
      return;
    }
    if (id == 'privacy' || id == 'support') {
      await _atlasPlaceholderInfo(
        id == 'privacy' ? 'Gizlilik Politikası' : 'Destek',
      );
      return;
    }
    _change(() {
      _flowOpen = id == 'photos' && _draft != null;
      _tab = id == 'settings'
          ? _settingsTab
          : id == 'records' ||
                id == 'record-detail' ||
                id == 'coffee-reading' ||
                id == 'report'
          ? _historyTab
          : id.startsWith('tarot') && _hasTarot
          ? 1
          : 0;
      if (id == 'tarot-records') {
        _tab = _historyTab;
        _recordsSection = 1;
      }
    });
    if ([
      'tarot-selection',
      'tarot-ready',
      'tarot-reading',
      'record-detail',
      'coffee-reading',
      'photos',
      'report',
    ].contains(id)) {
      final guide = umayAppGuides.where((g) => g.id == id).first;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${guide.entry} Umay yeniden anlatacak.')),
      );
    }
  }
}
