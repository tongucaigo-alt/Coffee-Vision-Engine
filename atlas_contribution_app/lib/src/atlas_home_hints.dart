import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

/// Only the user's switch persists. Completed visits belong to this app session.
class AtlasHomeHintPreferences extends ChangeNotifier {
  AtlasHomeHintPreferences([Directory? directory])
    : directory = directory?.isAbsolute == true ? directory : null;
  final Directory? directory;
  final _completed = <String>{};
  bool automaticEnabled = true, loaded = false, _closed = false;
  int generation = 0;
  Future<void>? _loading;
  Future<void> _writes = Future<void>.value();

  Future<void> load() => _loading ??= _load();
  Future<void> _load() async {
    try {
      if (directory != null) {
        final value = jsonDecode(
          await File('${directory!.path}/options.json').readAsString(),
        );
        if (value is Map &&
            value['version'] == 1 &&
            value['automaticHintsEnabled'] is bool) {
          automaticEnabled = value['automaticHintsEnabled'] as bool;
        }
      }
    } catch (_) {
      // Old coffee/tarot seen flags are deliberately not read or migrated.
    }
    if (_closed) return;
    loaded = true;
    notifyListeners();
  }

  bool completed(String page) => _completed.contains(page);
  void complete(String page) => _completed.add(page);

  Future<bool> setAutomaticEnabled(bool enabled) async {
    await load();
    if (_closed) return false;
    if (automaticEnabled != enabled) {
      automaticEnabled = enabled;
      if (enabled) {
        generation++;
        _completed.clear();
      }
      notifyListeners();
    }
    var saved = true;
    final write = _writes.then((_) async {
      try {
        if (directory == null) return;
        await directory!.create(recursive: true);
        final pending = File('${directory!.path}/options.pending');
        await pending.writeAsString(
          jsonEncode({'version': 1, 'automaticHintsEnabled': enabled}),
          flush: true,
        );
        await pending.rename('${directory!.path}/options.json');
      } catch (_) {
        saved = false;
      }
    });
    _writes = write;
    await write;
    return saved;
  }

  @override
  void dispose() {
    _closed = true;
    super.dispose();
  }
}

class AtlasHomeHintScope extends StatefulWidget {
  const AtlasHomeHintScope({
    required this.child,
    this.directory,
    this.preferences,
    super.key,
  });
  final Widget child;
  final Directory? directory;
  final AtlasHomeHintPreferences? preferences;
  static AtlasHomeHintPreferences? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<_HintPreferences>()
      ?.preferences;
  @override
  State<AtlasHomeHintScope> createState() => _AtlasHomeHintScopeState();
}

class _AtlasHomeHintScopeState extends State<AtlasHomeHintScope> {
  late final preferences =
      widget.preferences ?? AtlasHomeHintPreferences(widget.directory);
  @override
  void initState() {
    super.initState();
    unawaited(preferences.load());
  }

  @override
  void dispose() {
    if (widget.preferences == null) preferences.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _HintPreferences(preferences: preferences, child: widget.child);
}

class _HintPreferences extends InheritedWidget {
  const _HintPreferences({required this.preferences, required super.child});
  final AtlasHomeHintPreferences preferences;
  @override
  bool updateShouldNotify(_HintPreferences oldWidget) =>
      preferences != oldWidget.preferences;
}

class AtlasHomeHintSettings extends StatelessWidget {
  const AtlasHomeHintSettings({this.enabled = true, super.key});
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final preferences = AtlasHomeHintScope.maybeOf(context);
    if (preferences == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: preferences,
      builder: (context, _) => Card(
        child: SwitchListTile(
          title: const Text('Tuş açıklamalarını göster'),
          subtitle: const Text(
            'Her açılışta 6 saniye. İsimleri uzun basarak da görebilirsin.',
          ),
          value: preferences.automaticEnabled,
          onChanged: !enabled || !preferences.loaded
              ? null
              : (value) async {
                  final saved = await preferences.setAutomaticEnabled(value);
                  if (!saved && context.mounted) {
                    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Tercih bu kez kaydedilemedi. Seçimin bu açılış için geçerli.',
                        ),
                      ),
                    );
                  }
                },
        ),
      ),
    );
  }
}

class AtlasHomeHintController extends ChangeNotifier {
  AtlasHomeHintController(this.preferences, this.page) {
    _generation = preferences.generation;
    preferences.addListener(_preferencesChanged);
  }
  final AtlasHomeHintPreferences preferences;
  final String page;
  static const showDuration = Duration(seconds: 6);
  static const fadeDuration = Duration(milliseconds: 400);
  bool _loaded = false, _active = false, _attempted = false;
  bool _automatic = false, _disposed = false;
  late int _generation;
  bool? _manual;
  Timer? _automaticTimer, _manualTimer;
  bool visible(bool primary) => _active && (_automatic || _manual == primary);

  Future<void> initialize() async {
    await preferences.load();
    if (_disposed) return;
    _loaded = true;
    _startAutomatic();
  }

  void _preferencesChanged() {
    if (_disposed) return;
    if (_generation != preferences.generation) {
      _generation = preferences.generation;
      _attempted = false;
    }
    if (!preferences.automaticEnabled) {
      _automaticTimer?.cancel();
      _automatic = false;
      _attempted = false;
      notifyListeners();
    } else {
      _startAutomatic();
    }
  }

  void setActive(bool value) {
    if (_disposed || value == _active) return;
    _active = value;
    if (value) {
      _startAutomatic();
    } else {
      _automaticTimer?.cancel();
      _manualTimer?.cancel();
      _automatic = false;
      _manual = null;
      _attempted = false;
      notifyListeners();
    }
  }

  void _startAutomatic() {
    if (!_loaded ||
        !_active ||
        !preferences.automaticEnabled ||
        preferences.completed(page) ||
        _attempted ||
        _disposed) {
      return;
    }
    _attempted = true;
    _automatic = true;
    notifyListeners();
    _automaticTimer = Timer(showDuration, () {
      if (_disposed || !_active) return;
      _automatic = false;
      preferences.complete(page);
      notifyListeners();
    });
  }

  void show(bool primary) {
    if (!_active || _disposed) return;
    _automaticTimer?.cancel();
    _manualTimer?.cancel();
    _automatic = false;
    _attempted = true;
    _manual = primary;
    notifyListeners();
    _manualTimer = Timer(showDuration, () {
      if (_disposed) return;
      _manual = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    preferences.removeListener(_preferencesChanged);
    _automaticTimer?.cancel();
    _manualTimer?.cancel();
    super.dispose();
  }
}

class AtlasHomeHintBinding extends InheritedNotifier<AtlasHomeHintController> {
  const AtlasHomeHintBinding({
    required AtlasHomeHintController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);
  static AtlasHomeHintController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AtlasHomeHintBinding>()
      ?.notifier;
}
