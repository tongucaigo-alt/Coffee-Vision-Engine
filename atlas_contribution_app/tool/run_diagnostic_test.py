"""Run device tests only with a prebuilt diagnostic APK, and never uninstall.

Flutter 3.44.6 can retain the manifest namespace as the teardown package when
app-debug.apk did not exist before a test starts. Prebuild/inspect the APK first
then install explicitly with adb -r and attach to its existing VM service.
Never let Flutter own installation/failure fallback or use this for production.
"""
import argparse
import re
import subprocess
import time
from urllib.parse import urlparse
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
    parser.add_argument('--isolated-preview', action='store_true',
                        help='Use the auxiliary ui_preview test package; protect diagnostic user data')
    args = parser.parse_args()
    test = Path(args.test).resolve(strict=True)
    root = Path(__file__).resolve().parent.parent
    if test.parent != root / 'integration_test' or test.suffix != '.dart':
        raise RuntimeError('Only this project integration tests are allowed')
    defines = ['--dart-define=ATLAS_DIAGNOSTIC=true', '--dart-define=ATLAS_IMAGE_SCREEN=true']
    target_package = NORMAL + '.ui_preview' if args.isolated_preview else DIAGNOSTIC
    if args.isolated_preview:
        defines += ['--dart-define=ATLAS_UI_PREVIEW=true']
    if args.defines_file:
        defines += ['--dart-define-from-file=' + str(Path(args.defines_file).resolve(strict=True)),
                    '--dart-define=ATLAS_KIMI_LOCAL_TEST=true']
    if args.real_kimi:
        if not args.defines_file:
            raise RuntimeError('A private defines file is required for the explicit real-Kimi test')
        defines += ['--dart-define=ATLAS_REAL_KIMI_TEST=true']
    before = package_state(args.adb, args.serial)
    protected_diagnostic = capture([args.adb, '-s', args.serial, 'shell', 'dumpsys', 'package', DIAGNOSTIC]) if args.isolated_preview else None
    installed = capture([args.adb, '-s', args.serial, 'shell', 'dumpsys', 'package', target_package])
    if not args.isolated_preview and 'versionCode=' in installed:
        user_files = subprocess.run([args.adb, '-s', args.serial, 'shell', 'run-as',
                                    target_package, 'test', '-d', 'files/offline-contributions'],
                                   capture_output=True)
        if user_files.returncode == 0:
            raise RuntimeError('Diagnostic contains application records; use --isolated-preview instead')
    old_version = re.search(r'versionCode=(\d+)', installed)
    old_install = re.search(r'firstInstallTime=(.*)', installed)
    version = max(66, int(old_version[1]) + 1 if old_version else 66)
    subprocess.run([args.flutter, 'build', 'apk', '--debug', '--target', str(test),
                    '--build-number=' + str(version),
                    *defines], check=True, cwd=root)
    apk = root / 'build/app/outputs/flutter-apk/app-debug.apk'
    badging = capture([args.aapt, 'dump', 'badging', str(apk)])
    identity = re.search(r"package: name='([^']+)'", badging)
    if not identity or identity[1] != target_package:
        raise RuntimeError('Prebuilt APK is not diagnostic; no device test will run')
    # --no-uninstall protects Flutter's teardown only, NOT failed-install fallback.
    # Own installation explicitly; never let Flutter install or uninstall anything.
    forwarded = None
    try:
        subprocess.run([args.adb, '-s', args.serial, 'install', '-r', str(apk)], check=True)
        subprocess.run([args.adb, '-s', args.serial, 'shell', 'am', 'force-stop', target_package], check=True)
        subprocess.run([args.adb, '-s', args.serial, 'shell', 'am', 'start', '-n',
                        target_package + '/com.coffeeplatform.atlas_contribution_app.MainActivity'], check=True)
        uri = None
        for _ in range(60):
            try:
                pid = capture([args.adb, '-s', args.serial, 'shell', 'pidof', target_package]).strip()
            except subprocess.CalledProcessError:
                # A newly launched process may not exist during the first poll.
                time.sleep(1)
                continue
            if pid:
                log = capture([args.adb, '-s', args.serial, 'logcat', '-d', '--pid=' + pid, '-s', 'flutter:I'])
                match = re.search(r'Dart VM service is listening on (http://\S+)', log, re.IGNORECASE)
                if not match:
                    match = re.search(r'Dart VM Service is available at (http://\S+)', log)
                if match:
                    uri = match[1].rstrip('.'); break
            time.sleep(1)
        if not uri:
            raise RuntimeError('Diagnostic VM service unavailable; no reinstall/uninstall attempted')
        parsed = urlparse(uri)
        forwarded = capture([args.adb, '-s', args.serial, 'forward', 'tcp:0', 'tcp:' + str(parsed.port)]).strip()
        local_uri = 'http://127.0.0.1:' + forwarded + parsed.path
        result = subprocess.run([args.flutter, 'drive', '--use-existing-app=' + local_uri,
                                 '--driver=tool/diagnostic_driver.dart', '--target=' + str(test),
                                 '--keep-app-running', '-d', args.serial], cwd=root)
    finally:
        if forwarded:
            subprocess.run([args.adb, '-s', args.serial, 'forward', '--remove', 'tcp:' + forwarded], check=True)
        if package_state(args.adb, args.serial) != before:
            raise RuntimeError('Normal application identity changed during testing; stop device work')
        if old_install:
            after = capture([args.adb, '-s', args.serial, 'shell', 'dumpsys', 'package', target_package])
            if old_install[0] not in after:
                raise RuntimeError('Diagnostic first-install identity changed; stop device work')
        if protected_diagnostic is not None:
            after = capture([args.adb, '-s', args.serial, 'shell', 'dumpsys', 'package', DIAGNOSTIC])
            # Compare identity metadata, not runtime activity/process state.
            fields = ['versionCode=', 'firstInstallTime=', 'lastUpdateTime=']
            snapshot = lambda s: [l.strip() for l in s.splitlines() if any(f in l for f in fields)]
            if snapshot(after) != snapshot(protected_diagnostic):
                raise RuntimeError('User diagnostic application changed; stop device work')
    raise SystemExit(result.returncode)


if __name__ == '__main__':
    main()
