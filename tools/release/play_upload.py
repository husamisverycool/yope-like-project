#!/usr/bin/env python3
"""Upload a signed Android App Bundle to a Google Play testing track ("send Jolt to Google Play").

    play_upload.py --package com.yourname.jolt --aab jolt-42.aab [--track internal] [--release-name "0.1.0 (42)"]

Google Play Developer API v3 edits (https://developers.google.com/android-publisher/edits): edits.insert →
edits.bundles.upload → edits.tracks.update (status "completed"; when Play answers that the app is still a draft, the
whole edit is redone with status "draft") → edits.commit. Credentials: the service account key in the environment
variable PLAY_SERVICE_ACCOUNT_JSON (the .json file's text, or base64 of it); the account needs release permissions for
the app in Play Console → Users and permissions.

Exit codes: 0 uploaded; 1 failed; 2 Google wants this app's first bundle uploaded by hand in Play Console (a new app,
or the package is not in Play yet). Every outcome is explained in plain words on the run's summary page.
Requirements (tools/release/requirements-play.txt) are imported only when the script talks to Google, so the request
sequence can be tested with the standard library alone (test_release_tools.py).
"""
import argparse
import sys
import time
from pathlib import Path

from release_common import annotate, json_secret, write_summary

API = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
UPLOAD_API = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
DRAFT_APP = "only releases with status draft may be created on draft app"
TRANSIENT = {429, 500, 502, 503, 504}


class PlayError(Exception):
    def __init__(self, step: str, status: int, message: str, reason: str = ""):
        super().__init__(f"{step}: HTTP {status}: {message}")
        self.step, self.status, self.message, self.reason = step, status, message, reason

    @property
    def draft_app(self) -> bool:
        return DRAFT_APP in self.message.lower()


class Play:
    """The edits calls, over any requests-style session (google.auth's AuthorizedSession in production)."""

    def __init__(self, session, package: str, api: str = API, upload_api: str = UPLOAD_API, sleep=time.sleep):
        self.session, self.package, self.sleep = session, package, sleep
        self.base = f"{api}/{package}"
        self.upload_base = f"{upload_api}/{package}"

    def _call(self, step: str, method: str, url: str, timeout: float = 120, **kwargs) -> dict:
        for attempt in range(3):
            try:
                response = self.session.request(method, url, timeout=timeout, **kwargs)
            except OSError as err:  # requests' connection errors are OSErrors
                if attempt == 2:
                    raise PlayError(step, 0, f"could not reach Google Play ({type(err).__name__})") from None
                self.sleep(5 * 2**attempt)
                continue
            if response.status_code in TRANSIENT and attempt < 2:
                self.sleep(5 * 2**attempt)
                continue
            if response.status_code >= 300:
                message, reason = response.text[:500], ""
                try:
                    error = response.json().get("error") or {}
                    message = error.get("message") or message
                    reason = ((error.get("errors") or [{}])[0] or {}).get("reason", "") or error.get("status", "")
                except ValueError:
                    pass
                raise PlayError(step, response.status_code, message, reason)
            return response.json() if response.content else {}
        raise AssertionError("unreachable")

    def insert_edit(self) -> str:
        return self._call("edits.insert", "POST", f"{self.base}/edits", json={})["id"]

    def upload_bundle(self, edit: str, bundle: bytes) -> int:
        result = self._call("edits.bundles.upload", "POST", f"{self.upload_base}/edits/{edit}/bundles", timeout=900,
                            params={"uploadType": "media"}, data=bundle,
                            headers={"Content-Type": "application/octet-stream"})
        return int(result["versionCode"])

    def update_track(self, edit: str, track: str, version_code: int, status: str, name: str) -> None:
        release = {"versionCodes": [str(version_code)], "status": status}
        if name:
            release["name"] = name
        self._call("edits.tracks.update", "PUT", f"{self.base}/edits/{edit}/tracks/{track}",
                   json={"track": track, "releases": [release]})

    def commit(self, edit: str) -> None:
        self._call("edits.commit", "POST", f"{self.base}/edits/{edit}:commit")

    def delete_edit(self, edit: str) -> None:
        try:
            self._call("edits.delete", "DELETE", f"{self.base}/edits/{edit}")
        except PlayError:
            pass  # an edit that failed to commit may already be gone; it expires on its own anyway


def publish(play: Play, bundle: bytes, track: str, name: str, log=print) -> tuple[str, int]:
    """Returns (release status, version code)."""
    for status in ("completed", "draft"):
        edit = play.insert_edit()
        try:
            version_code = play.upload_bundle(edit, bundle)
            log(f"uploaded bundle, version code {version_code}")
            play.update_track(edit, track, version_code, status, name)
            play.commit(edit)
            return status, version_code
        except PlayError as err:
            play.delete_edit(edit)
            if status == "completed" and err.draft_app:
                log("Play says the app is still a draft in Play Console: saving the release as a draft instead")
                continue
            raise
    raise AssertionError("unreachable")


def console_steps(package: str, track: str) -> list[str]:
    return [
        f"In [Play Console](https://play.google.com/console) open the app **{package}** → **Test and release** → "
        f"**Testing** → **{track.capitalize()} testing**.",
    ]


def first_upload_note(package: str, track: str, artifact: str) -> list[str]:
    return [
        "## Google wants the first upload by hand",
        "",
        f"Google Play only lets this workflow upload once the app **{package}** exists in Play Console and has received "
        "one app bundle there by hand. The signed bundle from this run is ready; upload it once, then run this workflow "
        "again for every later version.",
        "",
        "1. If you have not yet: [Play Console](https://play.google.com/console) → **Create app** (app name, language, "
        "app or game, free or paid, accept the declarations) → **Create app**.",
        f"2. Here on GitHub, at the bottom of this run's page under **Artifacts**, click **{artifact}**. A .zip downloads; "
        "double-click it in Downloads to get the `.aab` file.",
        f"3. In Play Console open the app → **Test and release** → **Testing** → **{track.capitalize()} testing** → "
        "**Create new release**.",
        "4. If Play Console asks how the app is signed, keep **Use Google-generated key** (Play App Signing) and continue.",
        "5. Under **App bundles** click **Upload** and choose the `.aab` file. Wait until it shows the version.",
        "6. Click **Next**, then **Save and publish** (or **Save** — Play Console says which details it still needs "
        "before the release can go out).",
        "7. Make sure the service account may release: Play Console → **Users and permissions** → its email → app "
        f"**{package}** with **Release apps to testing tracks**.",
        "",
        "After this one upload, run **send Jolt to Google Play** again: from then on it uploads by itself.",
    ]


def explain(err: PlayError, package: str, client_email: str, track: str, artifact: str) -> tuple[int, list[str], str]:
    """(exit code, summary lines, one-line error) for the owner."""
    text = err.message.lower()
    if err.step == "edits.insert" and (err.status == 404 or "package not found" in text or "not found" in text):
        return 2, first_upload_note(package, track, artifact), (
            f"Google Play has no app {package} that this workflow may upload to yet — see this run's summary: upload the "
            f"bundle from the artifact {artifact} once by hand in Play Console")
    if "has not been used in project" in text or "is disabled" in text or err.reason in ("accessNotConfigured", "SERVICE_DISABLED"):
        line = ("The Google Play Android Developer API is switched off for the service account's Google Cloud project — open "
                "https://console.cloud.google.com/apis/library/androidpublisher.googleapis.com (that project selected) → "
                "Enable, wait a few minutes and run this again")
        return 1, ["## Google Play refused the upload", "", line], line
    if err.status in (401, 403):
        line = (f"The service account {client_email} may not release {package} — Play Console → Users and permissions → "
                f"Invite new users → {client_email} → App permissions: add {package} with \"Release apps to testing "
                "tracks\" → Invite user, then run this again (it can take a few minutes to apply)")
        return 1, ["## Google Play refused the upload", "", line, "", f"Google said: {err.message}"], line
    if "version code" in text and ("already" in text or "used" in text):
        line = ("Google Play already has this build number (or a higher one) — run the workflow again: each run gets the "
                "next number")
        return 1, ["## Google Play refused the upload", "", line, "", f"Google said: {err.message}"], line
    if "certificate" in text or "signed with" in text or "upload key" in text or "fingerprint" in text:
        line = ("The bundle is signed with a different upload key than the one Google Play knows for this app. If the key "
                "was made again after the first upload, ask Google to accept the new one: Play Console → Test and release → "
                "App integrity → Play app signing → Request upload key reset (the summary of \"create the Android "
                "signing key\" shows the new key's fingerprint)")
        return 1, ["## Google Play refused the upload", "", line, "", f"Google said: {err.message}"], line
    line = f"Google Play refused the upload at {err.step} (HTTP {err.status}): {err.message}"
    return 1, ["## Google Play refused the upload", "", line], line


def google_session(info: dict):
    from google.auth.transport.requests import AuthorizedSession
    from google.oauth2 import service_account

    credentials = service_account.Credentials.from_service_account_info(info, scopes=[SCOPE])
    return AuthorizedSession(credentials)


def main(argv: list[str] | None = None, session_factory=google_session, sleep=time.sleep) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--package", required=True)
    parser.add_argument("--aab", required=True)
    parser.add_argument("--track", default="internal")
    parser.add_argument("--release-name", default="")
    parser.add_argument("--artifact", default="the app bundle", help="name of the run's artifact holding the .aab")
    args = parser.parse_args(argv)

    try:
        info = json_secret("PLAY_SERVICE_ACCOUNT_JSON")
    except ValueError as err:
        annotate("error", str(err))
        return 1
    if not info:
        annotate("error", "GitHub secret PLAY_SERVICE_ACCOUNT_JSON is not set")
        return 1
    client_email = info.get("client_email", "the service account")
    bundle = Path(args.aab).read_bytes()
    play = Play(session_factory(info), args.package, sleep=sleep)
    try:
        status, version_code = publish(play, bundle, args.track, args.release_name)
    except PlayError as err:
        code, lines, line = explain(err, args.package, client_email, args.track, args.artifact)
        annotate("error", line)
        write_summary("\n".join(lines))
        return code
    except Exception as err:  # google.auth's RefreshError: the key itself was refused
        if type(err).__name__ != "RefreshError":
            raise
        line = ("Google did not accept the key in PLAY_SERVICE_ACCOUNT_JSON (deleted or disabled?) — Google Cloud → IAM & "
                f"Admin → Service accounts → {client_email} → Keys → Add key → JSON, and paste the new file's text into the secret")
        annotate("error", line)
        write_summary("## Google Play refused the upload\n\n" + line)
        return 1

    where = console_steps(args.package, args.track)[0]
    if status == "completed":
        annotate("notice", f"Build {version_code} is on Google Play's {args.track} testing track")
        write_summary("\n".join([
            f"## Build {version_code} is on Google Play ({args.track} testing)",
            "",
            "Testers who accepted the invitation get it from the Play Store within minutes to an hour.",
            "",
            f"- Testers: {where} → **Testers** → an email list with their Google accounts → **Copy link** and send it to them.",
        ]))
    else:
        annotate("warning", f"Build {version_code} is saved in Google Play as a draft release: the app is still a draft "
                 "in Play Console, so Google only accepts drafts — see this run's summary")
        write_summary("\n".join([
            f"## Build {version_code} is in Google Play as a draft",
            "",
            "The app is still a draft in Play Console (its setup is not finished), so Google only accepts draft releases.",
            "",
            f"1. {where}",
            "2. The release with this build says **Draft** → **Edit release** → **Next** → **Save and publish**. Play Console "
            "lists anything the app still needs (Dashboard → **Set up your app**).",
            "3. Once the app's first release is out, later runs publish to testers directly.",
        ]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
