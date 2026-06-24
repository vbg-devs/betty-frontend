#!/usr/bin/env python3
"""Resolve the MARKETING_VERSION to upload to TestFlight.

App Store Connect closes a pre-release "train" (CFBundleShortVersionString)
once that version ships to the App Store, so error 90186 ("Invalid Pre-Release
Train ... is closed for new build submissions") fires if a new build reuses a
released version. This asks ASC which trains exist and in what state, then
prints the lowest version that is >= the floor (ios/project.yml's
MARKETING_VERSION) AND still accepts builds, patch-bumping past any closed
train.

project.yml is the floor, not the answer: bump it for a deliberate minor/major
release; routine patch releases resolve automatically and never need an edit.

Inputs (env): ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (path to the .p8),
FLOOR_VERSION, APP_ID. Prints the resolved version to stdout.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt  # PyJWT (with the `cryptography` backend for ES256)

ASC_AUDIENCE = "appstoreconnect-v1"

# States in which a version's train is shipped/locked and rejects new builds.
# Anything not listed here (PREPARE_FOR_SUBMISSION, WAITING_FOR_REVIEW,
# IN_REVIEW, REJECTED, PENDING_DEVELOPER_RELEASE, PROCESSING_FOR_APP_STORE, a
# version that doesn't exist yet, ...) still accepts a TestFlight build.
CLOSED_STATES = {
    "READY_FOR_SALE",
    "REPLACED_WITH_NEW_VERSION",
    "REMOVED_FROM_SALE",
    "DEVELOPER_REMOVED_FROM_SALE",
    "PREORDER_READY_FOR_SALE",
}


def parse(version):
    """'1.2' / '1.2.3' -> (1, 2, 3) so versions sort and compare numerically."""
    parts = [int(p) for p in version.strip().split(".")]
    while len(parts) < 3:
        parts.append(0)
    return tuple(parts[:3])


def fmt(parts):
    return ".".join(str(p) for p in parts)


def mint_token(key_id, issuer_id, key_path):
    with open(key_path, "rb") as f:
        private_key = f.read()
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": ASC_AUDIENCE},
        private_key,
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def fetch_states(token, app_id):
    """Return {version_tuple: appStoreState} for the app's iOS versions."""
    url = (
        f"https://api.appstoreconnect.apple.com/v1/apps/{app_id}/appStoreVersions"
        "?filter[platform]=IOS&limit=200"
        "&fields[appStoreVersions]=versionString,appStoreState"
    )
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        body = json.load(resp)
    states = {}
    for item in body.get("data", []):
        attrs = item.get("attributes", {})
        version = attrs.get("versionString")
        state = attrs.get("appStoreState")
        if version:
            states[parse(version)] = state
    return states


def resolve(floor, states):
    """Lowest version >= floor whose train is open (or doesn't exist yet)."""
    target = parse(floor)
    # Bound the walk so a misconfiguration can never spin forever.
    for _ in range(1000):
        if states.get(target) not in CLOSED_STATES:
            return fmt(target)
        target = (target[0], target[1], target[2] + 1)
    raise SystemExit("could not find an open train within 1000 patch bumps")


def main():
    floor = os.environ["FLOOR_VERSION"]
    token = mint_token(
        os.environ["ASC_KEY_ID"],
        os.environ["ASC_ISSUER_ID"],
        os.environ["ASC_KEY_PATH"],
    )
    try:
        states = fetch_states(token, os.environ["APP_ID"])
    except urllib.error.HTTPError as e:
        sys.exit(f"App Store Connect API error {e.code}: {e.read().decode(errors='replace')}")
    resolved = resolve(floor, states)
    known = ", ".join(f"{fmt(v)}={states[v]}" for v in sorted(states)) or "(none)"
    print(f"floor={floor} trains: {known}", file=sys.stderr)
    print(f"resolved MARKETING_VERSION={resolved}", file=sys.stderr)
    print(resolved)


if __name__ == "__main__":
    main()
