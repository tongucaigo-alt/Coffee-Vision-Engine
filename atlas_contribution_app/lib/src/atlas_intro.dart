import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class AtlasIntroPreferences {
  AtlasIntroPreferences(this.directory);
  final Directory directory;
  Future<bool> readSeen() async {
    try {
      final data = jsonDecode(
        await File('${directory.path}/state.json').readAsString(),
      );
      return data is Map && data['version'] == 1 && data['seen'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<void> markSeen() async {
    await directory.create(recursive: true);
    final pending = File('${directory.path}/state.pending');
    await pending.writeAsString(
      jsonEncode({'version': 1, 'seen': true}),
      flush: true,
    );
    await pending.rename('${directory.path}/state.json');
  }
}

/// No application audio policy is changed. An unavailable platform stays muted.
class AtlasIntroAudio extends ValueNotifier<bool> {
  AtlasIntroAudio() : super(false);
  StreamSubscription<dynamic>? _subscription;
  bool _closed = false;
  void open() {
    _subscription = const EventChannel('atlas.app/intro_audio')
        .receiveBroadcastStream()
        .listen(
          (event) {
            if (!_closed) value = event == true;
          },
          onError: (Object _) {
            if (!_closed) value = false;
          },
        );
  }

  @override
  void dispose() {
    _closed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}

abstract class AtlasIntroMedia extends ChangeNotifier {
  Duration get position;
  Duration get duration;
  bool get initialized;
  bool get failed;
  Widget get view;
  Future<void> initialize();
  Future<void> seek(Duration position);
  Future<void> play();
  Future<void> pause();
  Future<void> volume(double value);
}

class _VideoIntroMedia extends AtlasIntroMedia {
  final _player = VideoPlayerController.asset(
    'assets/intro/atlas-welcome.mp4',
    videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
  );
  _VideoIntroMedia() {
    _player.addListener(notifyListeners);
  }
  @override
  Duration get position => _player.value.position;
  @override
  Duration get duration => _player.value.duration;
  @override
  bool get initialized => _player.value.isInitialized;
  @override
  bool get failed => _player.value.hasError;
  @override
  Widget get view => VideoPlayer(_player);
  @override
  Future<void> initialize() async {
    await _player.setVolume(0);
    await _player.initialize();
    await _player.setLooping(false);
  }

  @override
  Future<void> seek(Duration position) => _player.seekTo(position);
  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> volume(double value) => _player.setVolume(value);
  @override
  void dispose() {
    _player.removeListener(notifyListeners);
    unawaited(_player.dispose());
    super.dispose();
  }
}

/// One owner for one process launch, independent of bootstrap result/rebuilds.
class AtlasIntroController extends ChangeNotifier with WidgetsBindingObserver {
  AtlasIntroController({
    required this.preferences,
    AtlasIntroMedia? media,
    AtlasIntroAudio? audio,
  }) : media = media ?? _VideoIntroMedia(),
       audio = audio ?? AtlasIntroAudio() {
    this.media.addListener(_mediaChanged);
    this.audio.addListener(_audioChanged);
    WidgetsBinding.instance.addObserver(this);
  }
  final AtlasIntroPreferences preferences;
  final AtlasIntroMedia media;
  final AtlasIntroAudio audio;
  bool visible = true,
      closing = false,
      ready = false,
      staticFrame = false,
      playbackFrame = false,
      showAtlas = false;
  bool _started = false, _disposed = false, _released = false;
  Timer? _timeout, _gainTimer, _exitTimer;
  Duration _start = Duration.zero;
  double _gain = 0, _exitGain = 0;
  int _exitTicks = 0;
  void start({required bool reducedMotion}) {
    if (_started || _disposed || !visible) return;
    _started = true;
    if (reducedMotion) {
      staticFrame = true;
      showAtlas = true;
      notifyListeners();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => finish(immediate: true),
      );
      return;
    }
    _timeout = Timer(const Duration(seconds: 2), () => finish(markSeen: false));
    audio.open();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    try {
      if (_disposed || closing || !visible) return;
      await media.initialize();
      if (_disposed || closing || !visible) return;
      _start = Duration.zero;
      await media.seek(_start);
      if (_disposed || closing || !visible) return;
      _timeout?.cancel();
      ready = true;
      notifyListeners();
      _gainTimer = Timer.periodic(
        const Duration(milliseconds: 25),
        (_) => _updateGain(),
      );
      // Attach the texture and first-frame poster before starting the timeline.
      await WidgetsBinding.instance.endOfFrame;
      if (_disposed || closing || !visible) return;
      await media.play();
    } catch (_) {
      if (!_disposed) finish(markSeen: false);
    }
  }

  void _mediaChanged() {
    if (_disposed || closing || !visible) return;
    if (media.failed) {
      finish(markSeen: false);
      return;
    }
    if (ready && !playbackFrame && media.position > Duration.zero) {
      playbackFrame = true;
      notifyListeners();
    }
    final label = media.position >= const Duration(milliseconds: 6500);
    if (label != showAtlas) {
      showAtlas = label;
      notifyListeners();
    }
    if (ready &&
        media.duration > Duration.zero &&
        media.position >= media.duration) {
      finish();
    }
  }

  void _audioChanged() {
    if (!audio.value) _setGain(0);
  }

  void _setGain(double gain) {
    if (_disposed || gain == _gain) return;
    _gain = gain;
    unawaited(media.volume(gain).catchError((Object _) {}));
  }

  void _updateGain() {
    if (_disposed || !visible) return;
    if (!audio.value) {
      _setGain(0);
      return;
    }
    if (closing) {
      _exitTicks++;
      _setGain(_exitGain * (1 - _exitTicks / 10).clamp(0.0, 1.0));
    } else {
      final elapsed = (media.position - _start).inMilliseconds;
      final remaining = (media.duration - media.position).inMilliseconds;
      _setGain(.2 * math.min(elapsed / 250, remaining / 250).clamp(0.0, 1.0));
    }
  }

  void finish({bool markSeen = true, bool immediate = false}) {
    if (_disposed || closing || !visible) return;
    closing = true;
    _timeout?.cancel();
    _exitGain = _gain;
    _exitTicks = 0;
    if (markSeen) unawaited(preferences.markSeen().catchError((Object _) {}));
    notifyListeners();
    void end() {
      if (_disposed) return;
      _gainTimer?.cancel();
      _setGain(0);
      unawaited(media.pause().catchError((Object _) {}));
      visible = false;
      notifyListeners();
      WidgetsBinding.instance.addPostFrameCallback((_) => _releaseMedia());
    }

    if (immediate) {
      end();
    } else {
      _exitTimer = Timer(const Duration(milliseconds: 250), end);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && visible) {
      _setGain(0);
      unawaited(media.pause().catchError((Object _) {}));
      finish(immediate: true);
    }
  }

  void _releaseMedia() {
    if (_released) return;
    _released = true;
    media.removeListener(_mediaChanged);
    audio.removeListener(_audioChanged);
    audio.dispose();
    media.dispose();
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _timeout?.cancel();
    _gainTimer?.cancel();
    _exitTimer?.cancel();
    _releaseMedia();
    super.dispose();
  }
}

class AtlasIntroView extends StatefulWidget {
  const AtlasIntroView({required this.controller, super.key});
  final AtlasIntroController controller;
  @override
  State<AtlasIntroView> createState() => _AtlasIntroViewState();
}

class _AtlasIntroViewState extends State<AtlasIntroView> {
  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.start(reducedMotion: reduced);
    });
  }

  @override
  void dispose() {
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
    super.dispose();
  }

  // Both renderings share one player/clock; only the edge extension is blurred.
  Widget _frame(AtlasIntroController flow, {Key? posterKey}) =>
      ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (flow.ready && !flow.staticFrame) flow.media.view,
            IgnorePointer(
              child: AnimatedOpacity(
                key: posterKey,
                opacity: flow.playbackFrame ? 0 : 1,
                duration: const Duration(milliseconds: 180),
                child: Image.asset(
                  flow.staticFrame
                      ? 'assets/intro/atlas-welcome-still.jpg'
                      : 'assets/intro/atlas-welcome-first.jpg',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final flow = widget.controller;
      void dismiss() => flow.finish(immediate: true);
      return AnimatedOpacity(
        opacity: flow.closing && !flow.staticFrame ? 0 : 1,
        duration: const Duration(milliseconds: 250),
        child: Semantics(
          button: true,
          label: 'Açılışı geç',
          onTap: dismiss,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: dismiss,
            child: ColoredBox(
              color: const Color(0xFFEEDDBB),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                builder: (context, opacity, child) => Opacity(
                  key: const ValueKey('atlas-intro-reveal'),
                  opacity: opacity,
                  child: child,
                ),
                child: ClipRect(
                  key: const ValueKey('atlas-intro-viewport'),
                  child: SizedBox.expand(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ExcludeSemantics(
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 24,
                              sigmaY: 24,
                              tileMode: TileMode.clamp,
                            ),
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: 720,
                                height: 1280,
                                child: _frame(flow),
                              ),
                            ),
                          ),
                        ),
                        FittedBox(
                          key: const ValueKey('atlas-intro-content'),
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 720,
                            height: 1280,
                            child: ShaderMask(
                              blendMode: BlendMode.dstIn,
                              shaderCallback: (bounds) => const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.white,
                                  Colors.white,
                                  Colors.transparent,
                                ],
                                stops: [0, .035, .965, 1],
                              ).createShader(bounds),
                              child: _frame(
                                flow,
                                posterKey: const ValueKey('atlas-intro-poster'),
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
        ),
      );
    },
  );
}
