import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'atlas_intro_transition.dart';
import 'umay_home_tour.dart';

/// Preferences have their own file; no photo, reading or consent data is touched.
class UmayGuideController extends ChangeNotifier {
  UmayGuideController([this.directory]);
  final Directory? directory;
  final Set<String> shown = {};
  bool loaded = false, automatic = true, writeFailed = false, _disposed = false;
  Future<void>? _loading;
  Future<void> _writes = Future.value();
  Object? _owner;
  String? _replay;

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      if (directory != null) {
        final data = jsonDecode(
          await File('${directory!.path}/preferences.json').readAsString(),
        );
        if (data is Map && data['version'] == 1) {
          if (data['automatic'] is bool) automatic = data['automatic'] as bool;
          if (data['shown'] is List) {
            shown.addAll((data['shown'] as List).whereType<String>());
          }
        }
      }
    } catch (_) {
      // Missing or damaged guide preferences must never prevent app entry.
    }
    if (_disposed) return;
    loaded = true;
    notifyListeners();
  }

  bool shouldShow(String id) =>
      loaded && (_replay == id || automatic && !shown.contains(id));
  bool owns(Object owner) => identical(_owner, owner);
  bool claim(Object owner) {
    if (_owner != null && !owns(owner)) return false;
    _owner = owner;
    return true;
  }

  void release(Object owner) {
    if (!owns(owner)) return;
    _owner = null;
    if (!_disposed) notifyListeners();
  }

  void requestReplay(String id) {
    _replay = id; // One explicit user request; never a notification queue.
    notifyListeners();
  }

  Future<void> presented(String id) async {
    if (_replay == id) _replay = null;
    shown.add(id);
    notifyListeners();
    await _save();
  }

  Future<bool> setAutomatic(bool value) async {
    automatic = value;
    notifyListeners();
    return _save();
  }

  Future<bool> restartAll() async {
    shown.clear();
    _replay = null;
    automatic = true;
    notifyListeners();
    return _save();
  }

  Future<bool> _save() async {
    final data = jsonEncode({
      'version': 1,
      'automatic': automatic,
      'shown': shown.toList()..sort(),
    });
    var success = true;
    _writes = _writes.then((_) async {
      try {
        if (directory == null) return;
        await directory!.create(recursive: true);
        final pending = File('${directory!.path}/preferences.pending');
        await pending.writeAsString(data, flush: true);
        await pending.rename('${directory!.path}/preferences.json');
      } catch (_) {
        success = false;
      }
    });
    await _writes;
    writeFailed = !success;
    if (!_disposed) notifyListeners();
    return success;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class UmayGuideScope extends StatefulWidget {
  const UmayGuideScope({
    required this.child,
    this.directory,
    this.controller,
    this.enabled = true,
    super.key,
  });
  final Widget child;
  final Directory? directory;
  final UmayGuideController? controller;
  final bool enabled;
  static UmayGuideController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_GuideScope>()?.notifier;
  @override
  State<UmayGuideScope> createState() => _UmayGuideScopeState();
}

class _UmayGuideScopeState extends State<UmayGuideScope> {
  late final controller =
      widget.controller ?? UmayGuideController(widget.directory);
  @override
  void initState() {
    super.initState();
    if (widget.enabled) unawaited(controller.load());
  }

  @override
  void dispose() {
    if (widget.controller == null) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => !widget.enabled
      ? widget.child
      : _GuideScope(notifier: controller, child: widget.child);
}

class _GuideScope extends InheritedNotifier<UmayGuideController> {
  const _GuideScope({required super.notifier, required super.child});
}

typedef UmayLessonBuilder =
    Widget Function(VoidCallback presented, ValueChanged<bool> finish);

/// Explicit page ownership prevents overlapping tours and hidden-page seen flags.
class UmayGuideOnce extends StatefulWidget {
  const UmayGuideOnce({
    required this.id,
    required this.steps,
    required this.child,
    this.ready = true,
    this.lessonBuilder,
    this.onFinished,
    super.key,
  });
  final String id;
  final List<UmayTourStep> steps;
  final Widget child;
  final bool ready;
  final UmayLessonBuilder? lessonBuilder;
  final ValueChanged<bool>? onFinished;
  @override
  State<UmayGuideOnce> createState() => _UmayGuideOnceState();
}

class _UmayGuideOnceState extends State<UmayGuideOnce>
    with WidgetsBindingObserver {
  UmayGuideController? _controller;
  ModalRoute<dynamic>? _route;
  bool _show = false,
      _finished = false,
      _scheduled = false,
      _resetLease = false;
  bool get _foreground =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  bool get _visible =>
      _foreground &&
      widget.ready &&
      (ModalRoute.isCurrentOf(context) ?? true) &&
      TickerMode.valuesOf(context).enabled &&
      AtlasIntroArrival.isRevealedOf(context) &&
      (_route?.animation == null ||
          _route!.animation!.status == AnimationStatus.completed);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller = UmayGuideScope.maybeOf(context);
    final route = ModalRoute.of(context);
    if (_route != route) {
      _route?.animation?.removeStatusListener(_animation);
      _route = route;
      _route?.animation?.addStatusListener(_animation);
    }
    _schedule();
  }

  void _animation(AnimationStatus _) => _schedule();
  @override
  void didUpdateWidget(UmayGuideOnce old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      _show = false;
      _finished = false;
      _resetLease = true;
    }
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted) setState(() {});
    _schedule();
  }

  void _schedule() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _controller == null) return;
      final c = _controller!;
      if (_resetLease) {
        _resetLease = false;
        c.release(this);
      }
      if (!_visible) {
        c.release(this);
        return;
      }
      if (_show && !_finished) {
        if (c.claim(this)) setState(() {});
      } else if (c.shouldShow(widget.id) && c.claim(this)) {
        setState(() {
          _show = true;
          _finished = false;
        });
      }
    });
  }

  void _presented() {
    if (!mounted || !_visible || !_show || !_controller!.owns(this)) return;
    unawaited(_controller!.presented(widget.id));
  }

  void _finish(bool completed) {
    setState(() {
      _show = false;
      _finished = true;
    });
    _controller?.release(this);
    widget.onFinished?.call(completed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _route?.animation?.removeStatusListener(_animation);
    final controller = _controller;
    // Disposal can occur during a parent build; notify other owners afterwards.
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => controller.release(this),
      );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    if (c == null) return widget.child;
    final active = _show && !_finished;
    if (widget.lessonBuilder != null) {
      if (!c.loaded || !active && !_finished && c.shouldShow(widget.id)) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (active) {
        return TickerMode(
          enabled: _visible,
          child: widget.lessonBuilder!(_presented, _finish),
        );
      }
      return widget.child;
    }
    return UmayHomeTour(
      enabled: active,
      suspended: !_visible || !c.owns(this),
      steps: widget.steps,
      onPresented: _presented,
      onFinish: _finish,
      child: widget.child,
    );
  }
}

Future<void> showUmayLesson(
  BuildContext context, {
  required String id,
  required List<UmayTourStep> steps,
  required UmayLessonBuilder builder,
  bool force = false,
}) async {
  final controller = UmayGuideScope.maybeOf(context);
  if (controller == null) return;
  await controller.load();
  if (!context.mounted) return;
  if (force) controller.requestReplay(id);
  if (!controller.shouldShow(id)) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (routeContext) => UmayGuideOnce(
        id: id,
        steps: steps,
        lessonBuilder: builder,
        onFinished: (_) => Navigator.of(routeContext).pop(),
        child: const Scaffold(body: SizedBox.shrink()),
      ),
    ),
  );
}
