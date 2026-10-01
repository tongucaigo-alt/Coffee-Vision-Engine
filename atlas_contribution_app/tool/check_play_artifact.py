"""Inspect release archive ELF alignment and absence of known private test keys."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('artifact')
    parser.add_argument('--private-defines')
    parser.add_argument('--out', required=True)
    args = parser.parse_args()
    artifact = Path(args.artifact)
    secrets = []
    if args.private_defines:
        values = json.loads(Path(args.private_defines).read_text(encoding='utf-8-sig'))
        secrets = [value.encode() for key, value in values.items()
                   if ('KEY' in key or 'TOKEN' in key) and isinstance(value, str) and value]
    libraries = []
    exposed = False
    with zipfile.ZipFile(artifact) as archive:
        for name in archive.namelist():
            data = archive.read(name)
            exposed = exposed or any(secret in data for secret in secrets)
            if name.endswith('.so') and ('arm64-v8a/' in name or 'x86_64/' in name):
                if data[:4] != b'\x7fELF' or data[4] != 2:
                    raise RuntimeError('Unexpected native binary')
                endian = '<' if data[5] == 1 else '>'
                offset = struct.unpack_from(endian + 'Q', data, 32)[0]
                size, count = struct.unpack_from(endian + 'HH', data, 54)
                alignments = [struct.unpack_from(endian + 'Q', data, offset + i * size + 48)[0]
                              for i in range(count)
                              if struct.unpack_from(endian + 'I', data, offset + i * size)[0] == 1]
                libraries.append({'library': name, 'aligned16k': bool(alignments) and all(a >= 16384 for a in alignments)})
    passed = bool(libraries) and all(row['aligned16k'] for row in libraries) and not exposed
    report = {'sha256': hashlib.sha256(artifact.read_bytes()).hexdigest(),
              'knownSecretsChecked': len(secrets), 'knownSecretFound': exposed,
              'libraries': libraries, 'passed': passed,
              'limitations': 'ELF and exact known-key scan only; not a device test, ZIP alignment test or complete security audit.'}
    Path(args.out).write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({'passed': passed, 'nativeLibraries': len(libraries), 'knownSecretFound': exposed}))
    if not passed:
        raise SystemExit(1)


if __name__ == '__main__':
    main()
