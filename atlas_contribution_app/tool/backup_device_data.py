"""Read-only Android data capture and verified local restore rehearsal.

Does not stop, install, uninstall, clear, or write to the Android application.
The output directory must be new and outside the repository.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import tarfile
import tempfile

PACKAGE = "com.coffeeplatform.atlas_contribution_app"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()
    command = [args.adb, "-s", args.serial]

    def run(*parts):
        return subprocess.run(command + list(parts), check=True, capture_output=True).stdout.decode("utf-8").strip()

    available = run("shell", "run-as", PACKAGE, "ls").split()
    roots = [name for name in ("files", "shared_prefs", "databases") if name in available]
    if "files" not in roots:
        raise RuntimeError("Application files directory missing; device operations blocked")

    def inventory():
        query = f"run-as {PACKAGE} sh -c 'find {' '.join(roots)} -type f -exec sha256sum {{}} \u005c;'"
        text = run("shell", query)
        return dict((line.split(None, 1)[1].strip(), line.split(None, 1)[0])
                    for line in text.splitlines() if line)

    before = inventory()
    output = Path(args.out).resolve()
    repo = Path(__file__).resolve().parents[2]
    if output == repo or repo in output.parents:
        raise RuntimeError("Private backup must be outside the repository")
    output.mkdir(parents=True, exist_ok=False)
    archive = output / "application-data.tar"
    with archive.open("xb") as stream:
        subprocess.run(command + ["exec-out", "run-as", PACKAGE, "tar", "-cf", "-", *roots],
                       stdout=stream, stderr=subprocess.PIPE, check=True)
    if before != inventory():
        raise RuntimeError("Device data changed during capture; backup not accepted")

    restored = {}
    with tempfile.TemporaryDirectory(prefix="atlas-backup-verify-") as scratch:
        scratch_root = Path(scratch).resolve()
        with tarfile.open(archive, "r:") as tar:
            seen = set()
            for member in tar:
                relative = PurePosixPath(member.name)
                if relative.is_absolute() or ".." in relative.parts or not relative.parts or relative.parts[0] not in roots:
                    raise RuntimeError("Unsafe backup entry")
                if member.isdir():
                    continue
                if not member.isfile() or member.name in seen:
                    raise RuntimeError("Unsupported or duplicate backup entry")
                seen.add(member.name)
                target = scratch_root.joinpath(*relative.parts)
                target.parent.mkdir(parents=True, exist_ok=True)
                content = tar.extractfile(member).read()
                target.write_bytes(content)
                restored[member.name] = hashlib.sha256(target.read_bytes()).hexdigest()
        if restored != before:
            raise RuntimeError("Restored file inventory differs from the device")
    digest = hashlib.file_digest(archive.open("rb"), "sha256").hexdigest()
    manifest = {"package": PACKAGE, "serial": args.serial, "roots": roots,
                "archiveSha256": digest, "files": before, "restoreRehearsal": "PASS"}
    (output / "verification.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print(json.dumps({"backup": str(archive), "sha256": digest, "files": len(before),
                      "restoreRehearsal": "PASS"}))


if __name__ == "__main__":
    main()
