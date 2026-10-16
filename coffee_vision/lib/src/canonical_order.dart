/// Copy caller-owned input; sort only when it is not already canonical.
List<T> canonicalCopy<T>(Iterable<T> input, int Function(T, T) compare) {
  final result = input.toList();
  for (var i = 1; i < result.length; i++) {
    if (compare(result[i - 1], result[i]) > 0) {
      result.sort(compare);
      break;
    }
  }
  return result;
}
