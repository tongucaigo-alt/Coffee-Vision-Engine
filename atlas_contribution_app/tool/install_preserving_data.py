"""Verify identity, signer and increasing version before adb install -r. Never uninstall."""
import argparse
import hashlib
from pathlib import Path
import re
import subprocess
import tempfile


def run(command):
    return subprocess.run(command, check=True, capture_output=True, text=True,
                          encoding='utf-8', errors='replace').stdout


def identity(aapt, apk):
    output = run([aapt, 'dump', 'badging', str(apk)])
    match = re.search(r"package: name='([^']+)' versionCode='(\d+)'", output)
    if not match:
        raise RuntimeError('Cannot verify APK identity')
    return match[1], int(match[2])


def signer(apksigner, apk):
    result = run([apksigner, 'verify', '--print-certs', str(apk)])
    digests = re.findall(r'Signer #\d+ certificate SHA-256 digest: ([0-9a-f]+)', result)
    if not digests:
        raise RuntimeError('Cannot verify APK signer')
    return sorted(digests)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['adb', 'serial', 'aapt', 'apksigner', 'apk', 'package']:
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--install', action='store_true')
    args = parser.parse_args()
    allowed = 'com.coffeeplatform.atlas_contribution_app'
    if args.package not in [allowed, allowed + '.beta', allowed + '.diagnostic']:
        raise RuntimeError('Unexpected target package')
    apk = Path(args.apk).resolve(strict=True)
    digest = hashlib.sha256(apk.read_bytes()).hexdigest()
    package, version = identity(args.aapt, apk)
    if package != args.package:
        raise RuntimeError('Package mismatch; no installation')
    signature = signer(args.apksigner, apk)
    adb = [args.adb, '-s', args.serial]
    packages = run(adb + ['shell', 'pm', 'list', 'packages', package]).splitlines()
    installed = 'package:' + package in packages
    if installed:
        remote = run(adb + ['shell', 'pm', 'path', package])
        base = next((line.removeprefix('package:').strip() for line in remote.splitlines()
                     if line.strip().endswith('/base.apk')), None)
        if not base:
            raise RuntimeError('Cannot inspect installed APK')
        with tempfile.TemporaryDirectory(prefix='atlas-install-') as directory:
            previous = Path(directory) / 'base.apk'
            run(adb + ['pull', base, str(previous)])
            old_package, old_version = identity(args.aapt, previous)
            if old_package != package or version <= old_version:
                raise RuntimeError('A strictly higher version is required; no installation')
            if signer(args.apksigner, previous) != signature:
                raise RuntimeError('Signing mismatch; no installation')
    print(f'Verified {package} version {version}; SHA256 {digest}')
    if args.install:
        if hashlib.sha256(apk.read_bytes()).hexdigest() != digest:
            raise RuntimeError('APK changed after verification')
        result = run(adb + ['install', '-r', str(apk)])
        if 'Success' not in result:
            raise RuntimeError('Installation failed; no removal or retry performed')
        print('Installed without uninstall or data clear')


if __name__ == '__main__':
    main()
