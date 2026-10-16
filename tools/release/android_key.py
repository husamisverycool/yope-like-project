#!/usr/bin/env python3
"""The Android upload key, without a terminal (docs/OWNER_SETUP.md §2).

    android_key.py create          # "create the Android signing key": a new key, locked with the password, saved as
                                   # android/keystore/upload.p12.enc; its fingerprint is added to config/app.json
    android_key.py prepare         # "send Jolt to Google Play": unlock the key for Gradle (writes GITHUB_ENV)
    android_key.py check-aab FILE  # the app bundle is signed with that key

The password is the GitHub secret ANDROID_KEYSTORE_PASSWORD, read from the environment and handed to keytool and openssl
through the environment too (never on a command line). The unlocked key only ever exists in the runner's temporary
directory. `prepare` also accepts the older secrets ANDROID_UPLOAD_KEYSTORE_B64 (+ ANDROID_KEY_ALIAS,
ANDROID_KEY_PASSWORD) when the repository has no locked key.

The file is PKCS12 (keytool's default format) encrypted with `openssl enc -aes-256-cbc -pbkdf2` (SHA-256, the iteration
count below). The PKCS12 file is itself protected by the same password: two locks, one password.
"""
import argparse
import base64
import binascii
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

from release_common import ROOT, annotate, env, load_config, save_config, set_env, write_summary

ENCRYPTED = ROOT / "android" / "keystore" / "upload.p12.enc"
PASSWORD_ENV = "ANDROID_KEYSTORE_PASSWORD"
ALIAS = "upload"
DNAME = "CN=Android upload key"
# About 27 years. Google Play wants upload keys valid for at least 25 years.
VALIDITY_DAYS = 10000
# Never change: the committed file was encrypted with this count and decrypts only with it.
PBKDF2_ITERATIONS = 1_000_000
OPENSSL = ["openssl", "enc", "-aes-256-cbc", "-md", "sha256", "-pbkdf2", "-iter", str(PBKDF2_ITERATIONS), "-pass", f"env:{PASSWORD_ENV}"]


class Problem(Exception):
    """A plain-language problem for the owner."""


def password_env(password: str) -> dict:
    return {**os.environ, PASSWORD_ENV: password}


def keytool_fingerprint(store: Path, alias: str | None, password: str) -> str:
    """SHA-256 of the key's certificate, as AA:BB:… (the form assetlinks.json and config/app.json use)."""
    args = ["keytool", "-list", "-v", "-keystore", str(store), "-storepass:env", PASSWORD_ENV]
    if alias:
        args += ["-alias", alias]
    result = subprocess.run(args, capture_output=True, text=True, env=password_env(password))
    if result.returncode != 0:
        raise Problem("The keystore does not open with the password in ANDROID_KEYSTORE_PASSWORD (or has no key "
                        f"{alias!r}) — check the secret")
    match = re.search(r"SHA256:\s*((?:[0-9A-F]{2}:){31}[0-9A-F]{2})", result.stdout)
    if not match:
        raise Problem("keytool did not print the key's SHA-256 fingerprint")
    return match.group(1)


def aliases(store: Path, password: str) -> list[str]:
    result = subprocess.run(["keytool", "-list", "-keystore", str(store), "-storepass:env", PASSWORD_ENV],
                            capture_output=True, text=True, env=password_env(password))
    if result.returncode != 0:
        raise Problem("The keystore in ANDROID_UPLOAD_KEYSTORE_B64 does not open with the password in ANDROID_KEYSTORE_PASSWORD")
    return [line.split(",")[0].strip() for line in result.stdout.splitlines() if "PrivateKeyEntry" in line]


def encrypt(plain: Path, out: Path, password: str) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    result = subprocess.run(OPENSSL + ["-salt", "-in", str(plain), "-out", str(out)], capture_output=True, text=True,
                            env=password_env(password))
    if result.returncode != 0:
        raise Problem(f"openssl could not lock the key: {result.stderr.strip()}")


def decrypt(locked: Path, out: Path, password: str) -> None:
    result = subprocess.run(OPENSSL + ["-d", "-in", str(locked), "-out", str(out)], capture_output=True, text=True,
                            env=password_env(password))
    if result.returncode != 0:
        out.unlink(missing_ok=True)
        raise Problem(f"The password in ANDROID_KEYSTORE_PASSWORD does not unlock {shown(locked)} — it must be "
                        "exactly the password used when \"create the Android signing key\" ran")
    out.chmod(0o600)


def shown(path: Path) -> str:
    return str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path)


def temp_dir() -> Path:
    base = os.environ.get("RUNNER_TEMP") or None
    return Path(tempfile.mkdtemp(prefix="android-key-", dir=base))


def add_fingerprint(fingerprint: str) -> bool:
    """Adds the fingerprint to config/app.json android.sha256CertFingerprints (assetlinks.json). True when added."""
    config = load_config()
    prints = config["android"].setdefault("sha256CertFingerprints", [])
    if fingerprint in (p.upper() for p in prints):
        return False
    prints.append(fingerprint)
    save_config(config)
    return True


def create(args: argparse.Namespace) -> None:
    out = Path(args.out).resolve()
    if out.exists():
        raise Problem(f"{shown(out)} already exists — this never replaces a key")
    password = os.environ.get(PASSWORD_ENV, "")
    if not password.strip():
        raise Problem("GitHub secret ANDROID_KEYSTORE_PASSWORD is not set")
    work = temp_dir()
    try:
        plain = work / "upload.p12"
        run_env = password_env(password)
        result = subprocess.run(
            ["keytool", "-genkeypair", "-storetype", "PKCS12", "-keystore", str(plain), "-storepass:env", PASSWORD_ENV,
             "-alias", ALIAS, "-keyalg", "RSA", "-keysize", "4096", "-sigalg", "SHA256withRSA",
             "-validity", str(VALIDITY_DAYS), "-dname", DNAME, "-noprompt"],
            capture_output=True, text=True, env=run_env)
        if result.returncode != 0:
            raise Problem(f"keytool could not make the key: {result.stderr.strip()}")
        fingerprint = keytool_fingerprint(plain, ALIAS, password)
        encrypt(plain, out, password)
        # Prove the saved file opens again with the same password before anything is committed.
        check = work / "check.p12"
        decrypt(out, check, password)
        if keytool_fingerprint(check, ALIAS, password) != fingerprint:
            out.unlink()
            raise Problem("the locked key did not unlock to the same key; nothing was saved")
    except BaseException:
        out.unlink(missing_ok=True)
        raise
    finally:
        for f in work.iterdir():
            f.unlink()
        work.rmdir()
    added = add_fingerprint(fingerprint) if not args.no_config else False
    print(f"upload key created: {shown(out)} (alias {ALIAS}), SHA-256 {fingerprint}")
    write_summary("\n".join([
        "## The Android signing key is ready",
        "",
        f"- Saved, locked with your ANDROID_KEYSTORE_PASSWORD, as `{shown(out)}`. Keep that password safe "
        "(a password manager): without it no new Android version can be uploaded.",
        f"- Its fingerprint (SHA-256): `{fingerprint}`"
        + (" — added to config/app.json `android.sha256CertFingerprints`." if added else "."),
        "- Next: Actions → **send Jolt to Google Play** → Run workflow.",
        "- After the first upload, also add Google's own key fingerprint: Play Console → Test and release → App integrity → "
        "Play app signing → **App signing key certificate** → SHA-256, into config/app.json `android.sha256CertFingerprints` "
        "(docs/OWNER_SETUP.md §2).",
    ]))


def prepare(args: argparse.Namespace) -> None:
    password = os.environ.get(PASSWORD_ENV, "")
    if not password:
        raise Problem("GitHub secret ANDROID_KEYSTORE_PASSWORD is not set")
    work = temp_dir()
    locked = Path(args.locked).resolve()
    if locked.exists():
        store = work / "upload.p12"
        decrypt(locked, store, password)
        alias, key_password = ALIAS, password
        source = f"{shown(locked)} (made by \"create the Android signing key\")"
    elif env("ANDROID_UPLOAD_KEYSTORE_B64"):
        store = work / "upload.keystore"
        try:
            store.write_bytes(base64.b64decode("".join(env("ANDROID_UPLOAD_KEYSTORE_B64").split()), validate=True))
        except binascii.Error:
            raise Problem("GitHub secret ANDROID_UPLOAD_KEYSTORE_B64 is not base64 text of a keystore file") from None
        store.chmod(0o600)
        alias = env("ANDROID_KEY_ALIAS")
        if not alias:
            found = aliases(store, password)
            if len(found) != 1:
                raise Problem("Set the GitHub secret ANDROID_KEY_ALIAS: the keystore holds "
                                f"{len(found)} keys and the alias says which one signs")
            alias = found[0]
        key_password = os.environ.get("ANDROID_KEY_PASSWORD") or password
        source = "the GitHub secret ANDROID_UPLOAD_KEYSTORE_B64"
    else:
        raise Problem("There is no Android signing key yet — run Actions → \"create the Android signing key\" once")
    fingerprint = keytool_fingerprint(store, alias, password)
    set_env("ANDROID_UPLOAD_STORE_FILE", str(store))
    set_env("ANDROID_UPLOAD_KEY_ALIAS", alias)
    if key_password != password:
        set_env("ANDROID_UPLOAD_KEY_PASSWORD", key_password)
    set_env("ANDROID_UPLOAD_SHA256", fingerprint)
    print(f"signing with {source}: alias {alias}, SHA-256 {fingerprint}")
    prints = [p.upper() for p in (load_config().get("android") or {}).get("sha256CertFingerprints") or []]
    if fingerprint not in prints:
        annotate("warning", f"config/app.json android.sha256CertFingerprints does not list this upload key ({fingerprint}). "
                 "Add it there, with Play Console's App signing key SHA-256, so app links open the app (OWNER_SETUP.md §2)")


def check_aab(args: argparse.Namespace) -> None:
    expected = env("ANDROID_UPLOAD_SHA256")
    result = subprocess.run(["keytool", "-printcert", "-jarfile", args.file], capture_output=True, text=True)
    found = re.findall(r"SHA256:\s*((?:[0-9A-F]{2}:){31}[0-9A-F]{2})", result.stdout)
    if not found:
        raise Problem("The app bundle is not signed — the build did not pick up the signing key")
    if expected and expected not in found:
        raise Problem("The app bundle is signed with a different key than the upload key")
    print(f"signed with SHA-256 {found[0]}")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)
    p = sub.add_parser("create")
    p.add_argument("--out", default=str(ENCRYPTED))
    p.add_argument("--no-config", action="store_true", help="do not add the fingerprint to config/app.json")
    p.set_defaults(func=create)
    p = sub.add_parser("prepare")
    p.add_argument("--locked", default=str(ENCRYPTED))
    p.set_defaults(func=prepare)
    p = sub.add_parser("check-aab")
    p.add_argument("file")
    p.set_defaults(func=check_aab)
    args = parser.parse_args(argv)
    try:
        args.func(args)
    except Problem as err:
        annotate("error", str(err))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
