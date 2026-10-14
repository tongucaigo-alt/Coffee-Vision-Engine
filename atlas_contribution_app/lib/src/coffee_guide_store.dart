import 'dart:convert';
import 'dart:io';

/// Guide preferences are deliberately outside contribution/AI/permission stores.
class CoffeeGuideState {
  const CoffeeGuideState({this.shownCount = 0, this.dontShowAgain = false});
  final int shownCount;
  final bool dontShowAgain;

  CoffeeGuideState presented() => CoffeeGuideState(
    shownCount: (shownCount + 1).clamp(0, 2),
    dontShowAgain: dontShowAgain,
  );
}

class CoffeeGuideStore {
  CoffeeGuideStore(this.directory);
  final Directory directory;
  Future<void> _tail = Future<void>.value();
  File get _state => File('${directory.path}/state.json');
  File get _backup => File('${directory.path}/state.bak');

  Future<CoffeeGuideState> read() async {
    for (final file in [_state, _backup]) {
      try {
        if (!await file.exists()) continue;
        final data = jsonDecode(await file.readAsString());
        if (data is! Map ||
            data['version'] != 1 ||
            data['shownCount'] is! int ||
            (data['shownCount'] as int) < 0 ||
            data['dontShowAgain'] is! bool) {
          continue;
        }
        final count = (data['shownCount'] as int).clamp(0, 2);
        return CoffeeGuideState(
          shownCount: count,
          // A malformed first-launch state must never suppress the guide.
          dontShowAgain: count >= 2 && data['dontShowAgain'] == true,
        );
      } on FormatException {
        continue;
      } on FileSystemException {
        continue;
      }
    }
    return const CoffeeGuideState();
  }

  Future<void> save(CoffeeGuideState state) {
    final write = _tail.then((_) async {
      await directory.create(recursive: true);
      final pending = File('${directory.path}/state.pending');
      await pending.writeAsString(
        jsonEncode({
          'version': 1,
          'shownCount': state.shownCount.clamp(0, 2),
          'dontShowAgain': state.shownCount >= 2 && state.dontShowAgain,
        }),
        flush: true,
      );
      if (await _state.exists()) await _state.copy(_backup.path);
      await pending.rename(_state.path);
    });
    _tail = write.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return write;
  }
}
