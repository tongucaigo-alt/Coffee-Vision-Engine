// A process-local revision, shared by every store instance. It contains no data.
// Account/runtime owners keep their own bounded snapshots; resume and explicit
// refresh invalidate them as well. Failures never become cached successes.
int _localRevision = 0;
int get localDataRevision => _localRevision;
void markLocalDataChanged() => _localRevision++;

class LocalRevisionCache<T> {
  LocalRevisionCache({required this.canRetain});
  final bool Function(T) canRetain;
  int _generation = 0;
  int? _storedRevision, _storedGeneration;
  T? _value;
  Future<T>? _flight;
  int? _flightRevision, _flightGeneration;

  T? get value =>
      _storedRevision == localDataRevision && _storedGeneration == _generation
      ? _value
      : null;

  void invalidate() {
    _generation++;
    _value = null;
  }

  Future<T> load(Future<T> Function() loader) {
    final cached = value;
    if (cached != null) return Future.value(cached);
    final revision = localDataRevision;
    final generation = _generation;
    if (_flight != null &&
        _flightRevision == revision &&
        _flightGeneration == generation) {
      return _flight!;
    }
    late final Future<T> work;
    work =
        (() async {
          final result = await loader();
          if (revision != localDataRevision || generation != _generation) {
            // A delete, recovery, star or source edit raced the read. Never publish
            // the older snapshot, and join any newer read already in progress.
            return load(loader);
          }
          if (canRetain(result)) {
            _value = result;
            _storedRevision = revision;
            _storedGeneration = generation;
          }
          return result;
        })().whenComplete(() {
          if (identical(_flight, work)) _flight = null;
        });
    _flight = work;
    _flightRevision = revision;
    _flightGeneration = generation;
    return work;
  }
}
