"""Run only a prebuilt diagnostic APK, with verified normal-app data protection."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

NORMAL = "com.coffeeplatform.atlas_contribution_app"
DIAGNOSTIC = NORMAL + ".diagnostic"
APP = Path(__file__).resolve().parents[1]


def checked(command):
    return subprocess.run(command, check=True, capture_output=True, text=True,
                          encoding="utf-8", errors="replace").stdout


def inventory(adb, roots):
    if not roots or any(root not in ("files", "shared_prefs", "databases") for root in roots):
        raise RuntimeError("Unexpected backup roots")
    query = f"run-as {NORMAL} sh -c 'find {' '.join(roots)} -type f -exec sha256sum {{}} \\;'"
    lines = checked([*adb, "shell", query]).splitlines()
    result = {}
    for line in lines:
        match = re.fullmatch(r"([0-9a-f]{64})\s+(.+)", line.strip())
        if not match or match[2] in result:
            raise RuntimeError("Invalid device inventory")
        result[match[2]] = match[1]
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("flutter", "adb", "aapt", "apk", "sha256"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--serial")
    parser.add_argument("--backup-dir")
    parser.add_argument("--verify-only", action="store_true")
    parser.add_argument("--target", default="integration_test/multitouch_device_test.dart",
                        choices=["integration_test/multitouch_device_test.dart",
                                 "integration_test/mvp_device_test.dart"])
    args = parser.parse_args()
    apk = Path(args.apk).resolve(strict=True)
    with apk.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    if not re.fullmatch(r"[0-9a-f]{64}", args.sha256) or digest != args.sha256:
        raise RuntimeError("APK checksum mismatch; no device operation permitted")
    badging = checked([args.aapt, "dump", "badging", str(apk)])
    identity = re.search(r"^package: name='([^']+)'", badging, re.MULTILINE)
    if not identity or identity[1] != DIAGNOSTIC:
        raise RuntimeError("Diagnostic identity required; no device operation permitted")
    print(json.dumps({"apk": str(apk), "package": identity[1], "sha256": digest}))
    if args.verify_only:
        return
    if not args.serial or not args.backup_dir:
        raise RuntimeError("Serial and a new external backup directory are required")
    adb = [args.adb, "-s", args.serial]
    if checked([*adb, "get-state"]).strip() != "device":
        raise RuntimeError("Authorized device required")
    subprocess.run([sys.executable, str(APP / "tool/backup_device_data.py"),
                    "--adb", args.adb, "--serial", args.serial,
                    "--out", args.backup_dir], check=True)
    backup_dir = Path(args.backup_dir).resolve(strict=True)
    verification = json.loads((backup_dir / "verification.json").read_text(encoding="utf-8"))
    if verification["restoreRehearsal"] != "PASS" or verification["package"] != NORMAL:
        raise RuntimeError("Backup verification failed")
    if inventory(adb, verification["roots"]) != verification["files"]:
        raise RuntimeError("Normal app changed after backup; test blocked")
    with apk.open("rb") as stream:
        if hashlib.file_digest(stream, "sha256").hexdigest() != digest:
            raise RuntimeError("APK changed after inspection; test blocked")
    # The exact inspected binary is passed to drive; never invoke flutter test
    # or allow a build that could replace it with a generated listener APK.
    exit_code = None
    failure = None
    try:
        exit_code = subprocess.run([
            args.flutter, "drive", "--debug", "--no-pub",
            "--driver", "test_driver/diagnostic_driver.dart",
            "--target", args.target,
            "--use-application-binary", str(apk), "-d", args.serial,
            "--timeout", "240",
        ], cwd=APP).returncode
    except Exception as error:
        failure = type(error).__name__
    finally:
        after = inventory(adb, verification["roots"])
        data_unchanged = after == verification["files"]
        report = {"apkSha256": digest, "package": DIAGNOSTIC, "target": args.target,
                  "testExitCode": exit_code, "runnerFailure": failure,
                  "normalDataUnchanged": data_unchanged,
                  "normalFilesBefore": len(verification["files"]),
                  "normalFilesAfter": len(after)}
        with (backup_dir / "diagnostic-result.json").open("x", encoding="utf-8") as stream:
            json.dump(report, stream, indent=2)
        print(json.dumps(report))
    if failure or exit_code != 0 or not data_unchanged:
        raise RuntimeError("M0 diagnostic acceptance blocked; no repair or restore attempted")


if __name__ == "__main__":
    main()
