#!/usr/bin/env python3
"""Before a release job builds: put the store identity this run uses into config/app.json, in the job's own copy of
the repository only (never committed), so the build and the invite page's link files name the same app as the stores.

    IOS_BUNDLE_ID=…          → ios.bundleId           (the App Store app; "send Jolt to TestFlight" uses the same value)
    ANDROID_APPLICATION_ID=… → android.applicationId  (the Google Play app)
    APP_DOMAIN=…             → domain.value           (the invite-link host; owner decision 33 sets the default in the file)
    APPLE_TEAM_ID=…          → ios.teamId, only while config/app.json has none

Each variable is optional; an empty one leaves the file's value. Secret values are never printed. The repository variable
APP_DOMAIN is the one change that moves every build (iPhone, Android, invite page) to a new domain: the workflows pass it
here, and "send Jolt to TestFlight" also hands the resulting domain to xcodebuild (APP_DOMAIN, the associated domains).
"""
import sys

from release_common import ANDROID_PACKAGE_RE, BUNDLE_RE, DOMAIN_RE, TEAM_RE, annotate, env, load_config, save_config

config = load_config()
problems: list[str] = []
changed: list[str] = []

ios_id = env("IOS_BUNDLE_ID")
if ios_id:
    if not BUNDLE_RE.fullmatch(ios_id):
        problems.append(f"The iPhone bundle ID {ios_id!r} is not a bundle ID (like com.yourname.jolt) — fix the repository variable IOS_BUNDLE_ID")
    elif config["ios"].get("bundleId") != ios_id:
        config["ios"]["bundleId"] = ios_id
        changed.append(f"ios.bundleId = {ios_id}")

android_id = env("ANDROID_APPLICATION_ID")
if android_id:
    if not ANDROID_PACKAGE_RE.fullmatch(android_id):
        problems.append(f"The Android package name {android_id!r} is not a package name (like com.yourname.jolt: letters, digits and _, "
                        "dots between parts, each part starting with a letter) — fix the workflow's input or the repository variable ANDROID_APPLICATION_ID")
    elif config["android"].get("applicationId") != android_id:
        config["android"]["applicationId"] = android_id
        changed.append(f"android.applicationId = {android_id}")

domain = env("APP_DOMAIN").lower()
if domain:
    if not DOMAIN_RE.fullmatch(domain):
        problems.append(f"The domain {domain!r} is not a host name (like jolt-yourname.fly.dev or yourapp.com: no https:// and no /) "
                        "— fix the repository variable APP_DOMAIN")
    elif (config.get("domain") or {}).get("value") != domain:
        config.setdefault("domain", {})["value"] = domain
        changed.append(f"domain = {domain}")

team = env("APPLE_TEAM_ID")
if team and not config["ios"].get("teamId"):
    if TEAM_RE.fullmatch(team):
        config["ios"]["teamId"] = team
        changed.append("ios.teamId = the APPLE_TEAM_ID secret")
    else:
        problems.append("GitHub secret APPLE_TEAM_ID is not a Team ID (10 capital letters and digits, developer.apple.com → Account → Membership details)")

if problems:
    for line in problems:
        annotate("error", line)
    sys.exit(1)
if changed:
    save_config(config)
    print("this run's app identity (config/app.json in this job only, not committed): " + "; ".join(changed))
else:
    print("app identity: as in config/app.json")
