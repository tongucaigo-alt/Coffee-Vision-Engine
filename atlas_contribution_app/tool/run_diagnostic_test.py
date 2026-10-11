"""Run device tests only with a prebuilt diagnostic APK, and never uninstall.

Flutter 3.44.6 can retain the manifest namespace as the teardown package when
app-debug.apk did not exist before a test starts. Prebuild/inspect the APK first
and always pass --no-uninstall. Never use this runner for a production package.
"""
import argparse
import re
import subprocess
from pathlib import Path

DIAGNOSTIC = 'com.coffeeplatform.atlas_contribution_app.diagnostic'
NORMAL = 'com.coffeeplatform.atlas_contribution_app'


def capture(args):
    return subprocess.run(args, check=True, capture_output=True, text=True,
                          encoding='utf-8', errors='replace').stdout


def package_state(adb, serial):
    states = {}
    for package in [NORMAL, NORMAL + '.beta']:
        output = capture([adb, '-s', serial, 'shell', 'dumpsys', 'package', package])
        states[package] = '\n'.join(line.strip() for line in output.splitlines()
                                   if any(term in line for term in ['versionCode=', 'firstInstallTime=', 'lastUpdateTime=']))
    return states


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ['flutter', 'adb', 'serial', 'aapt', 'test']:
        parser.add_argument('--' + name, required=True)
    parser.add_argument('--defines-file')
    parser.add_argument('--real-kimi', action='store_true')
    args = parser.parse_args()
    test = Path(args.test).resolve(strict=True)
    root = Path(__file__).resolve().parent.parent
    if test.parent != root / 'integration_test' or test.suffix != '.dart':
        raise RuntimeError('Only this project integration tests are allowed')
    defines = ['--dart-define=ATLAS_DIAGNOSTIC=true', '--dart-define=ATLAS_IMAGE_SCREEN=true']
    if args.defines_file:
        defines += ['--dart-define-from-file=' + str(Path(args.defines_file).resolve(strict=True)),
                    '--dart-define=ATLAS_KIMI_LOCAL_TEST=true']
    if args.real_kimi:
        if not args.defines_file:
            raise RuntimeError('A private defines file is required for the explicit real-Kimi test')
        defines += ['--dart-define=ATLAS_REAL_KIMI_TEST=true']
    before = package_state(args.adb, args.serial)
    subprocess.run([args.flutter, 'build', 'apk', '--debug', '--target', str(test),
                    *defines], check=True, cwd=root)
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    badging = capture([args.aapt, 'dump', 'badging', str(apk)])
    identity = re.search(r"package: name='([^']+)'", badging)
    if not identity or identity[1] != DIAGNOSTIC:
        raise RuntimeError('Prebuilt APK is not diagnostic; no device test will run')
    result = subprocess.run([args.flutter, 'test', str(test), '-d', args.serial,
                             '--no-uninstall', *defines], cwd=root)
    if package_state(args.adb, args.serial) != before:
        raise RuntimeError('Normal application identity changed during testing; stop device work')
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
