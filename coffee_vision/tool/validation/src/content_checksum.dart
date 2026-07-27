import 'package:crypto/crypto.dart';

const _sha256Prefix = 'sha256:';

String computeContentChecksum(List<int> bytes) {
  return '$_sha256Prefix${sha256.convert(bytes)}';
}

bool contentChecksumMatches(List<int> bytes, String expected) {
  return computeContentChecksum(bytes) == expected;
}
