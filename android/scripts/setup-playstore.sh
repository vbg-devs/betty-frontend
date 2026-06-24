#!/usr/bin/env bash
#
# Bootstraps Play Store publishing for the Betty Android app. Gathers / generates
# everything `.github/workflows/android-playstore.yml` needs and (optionally) sets the
# GitHub Actions secrets in the `release` environment.
#
# Usage:
#   android/scripts/setup-playstore.sh check      # report what exists / is missing (default)
#   android/scripts/setup-playstore.sh setup      # generate keystore + set the GitHub secrets
#
# Inputs (env vars, optional — prompted if absent during `setup`):
#   SA_JSON            path to the Play Developer API service-account JSON
#   KEYSTORE_PASSWORD  upload keystore password   (auto-generated if empty)
#   KEY_PASSWORD       upload key password        (defaults to KEYSTORE_PASSWORD)
#   KEY_ALIAS          upload key alias           (default: betty-upload)
#   REPO               owner/repo                 (default: detected from gh / git)
#
# Safe by design: secrets are written only under android/.playstore-secrets/ (gitignored),
# never echoed, and pushed to GitHub only after an explicit confirmation.
set -euo pipefail

# --- locate repo root (this script lives in android/scripts/) -----------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$ANDROID_DIR/.." && pwd)"

ENVIRONMENT="release"
SECRETS_DIR="$ANDROID_DIR/.playstore-secrets"
KEYSTORE="$SECRETS_DIR/upload.jks"
RECORD="$SECRETS_DIR/credentials.env"
KEY_ALIAS="${KEY_ALIAS:-betty-upload}"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
miss() { printf '  \033[31m✗\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }

require() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: '$1' is required but not installed." >&2; exit 1; }; }

detect_repo() {
  if [ -n "${REPO:-}" ]; then echo "$REPO"; return; fi
  gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null \
    || git -C "$REPO_ROOT" remote get-url origin 2>/dev/null | sed -E 's#.*github.com[:/]([^/]+/[^/.]+)(\.git)?#\1#' \
    || echo ""
}

b64() { openssl base64 -A < "$1"; }  # portable (macOS base64 lacks -w0)

keystore_sha1() {
  keytool -list -v -keystore "$KEYSTORE" -alias "$KEY_ALIAS" \
    -storepass "$1" 2>/dev/null | grep -i 'SHA1:' | head -1 | sed -E 's/.*SHA1:[[:space:]]*//'
}

debug_sha1() {
  local dks="$HOME/.android/debug.keystore"
  [ -f "$dks" ] || { echo "(no ~/.android/debug.keystore yet — build once)"; return; }
  keytool -list -v -keystore "$dks" -alias androiddebugkey \
    -storepass android -keypass android 2>/dev/null | grep -i 'SHA1:' | head -1 | sed -E 's/.*SHA1:[[:space:]]*//'
}

# ---------------------------------------------------------------------------
cmd_check() {
  require gh
  local repo; repo="$(detect_repo)"
  bold "Betty Android — Play Store readiness"
  echo "  repo: ${repo:-<unknown>}   env: $ENVIRONMENT"
  echo

  bold "Local"
  command -v keytool >/dev/null 2>&1 && ok "keytool present" || miss "keytool missing (install a JDK)"
  [ -f "$KEYSTORE" ] && ok "upload keystore: $KEYSTORE" || miss "upload keystore not generated yet"
  echo

  bold "GitHub secrets ($ENVIRONMENT environment)"
  if [ -z "$repo" ]; then warn "repo not detected — pass REPO=owner/name"; return; fi
  local existing; existing="$(gh secret list --env "$ENVIRONMENT" --repo "$repo" 2>/dev/null | awk '{print $1}')" || existing=""
  for s in PLAY_SERVICE_ACCOUNT_JSON ANDROID_KEYSTORE_BASE64 ANDROID_KEYSTORE_PASSWORD ANDROID_KEY_ALIAS ANDROID_KEY_PASSWORD; do
    grep -qx "$s" <<<"$existing" && ok "$s set" || miss "$s missing"
  done
  echo
  bold "Manual (one-time, not scriptable)"
  echo "  • Play Console app for 'social.betty.android' (first upload is manual; enroll in Play App Signing)"
  echo "  • Google sign-in: register an Android OAuth client (package social.betty.android) with these SHA-1s:"
  echo "      debug:  $(debug_sha1)"
  [ -f "$KEYSTORE" ] && echo "      upload: $(keystore_sha1 "${KEYSTORE_PASSWORD:-}" 2>/dev/null || echo '(run: setup, then re-check with KEYSTORE_PASSWORD set)')"
  echo "    then set AppConfig.GOOGLE_OAUTH_CLIENT_ID."
  echo
  echo "Run '$0 setup' to generate the keystore and push the secrets."
}

# ---------------------------------------------------------------------------
cmd_setup() {
  require gh; require keytool; require openssl
  local repo; repo="$(detect_repo)"
  [ -n "$repo" ] || { echo "ERROR: could not detect repo; pass REPO=owner/name" >&2; exit 1; }
  gh auth status >/dev/null 2>&1 || { echo "ERROR: run 'gh auth login' first." >&2; exit 1; }

  umask 077
  mkdir -p "$SECRETS_DIR"

  # 1. Service-account JSON ---------------------------------------------------
  local sa="${SA_JSON:-}"
  if [ -z "$sa" ]; then read -r -p "Path to Play service-account JSON: " sa; fi
  [ -f "$sa" ] || { echo "ERROR: service-account JSON not found at: $sa" >&2; exit 1; }
  python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$sa" \
    || { echo "ERROR: $sa is not valid JSON." >&2; exit 1; }
  ok "service-account JSON validated"

  # 2. Upload keystore --------------------------------------------------------
  local store_pw="${KEYSTORE_PASSWORD:-}"
  if [ -z "$store_pw" ]; then
    read -r -s -p "Keystore password (blank = auto-generate): " store_pw; echo
    [ -n "$store_pw" ] || { store_pw="$(openssl rand -base64 24 | tr -d '/+=' | head -c 28)"; warn "generated a keystore password (saved to $RECORD)"; }
  fi
  local key_pw="${KEY_PASSWORD:-$store_pw}"

  if [ -f "$KEYSTORE" ]; then
    warn "keystore already exists — reusing $KEYSTORE (delete it to regenerate)"
  else
    keytool -genkeypair -v \
      -keystore "$KEYSTORE" -alias "$KEY_ALIAS" \
      -keyalg RSA -keysize 2048 -validity 9125 \
      -storepass "$store_pw" -keypass "$key_pw" \
      -dname "CN=Betty, O=Betty, C=SE"
    ok "generated upload keystore: $KEYSTORE"
  fi

  # 3. Record locally (gitignored) so the key + passwords are never lost -------
  {
    echo "# Betty Android upload signing — KEEP SAFE, BACK UP OFFLINE."
    echo "# Losing the upload key means you must contact Play support to reset it."
    echo "ANDROID_KEY_ALIAS=$KEY_ALIAS"
    echo "ANDROID_KEYSTORE_PASSWORD=$store_pw"
    echo "ANDROID_KEY_PASSWORD=$key_pw"
    echo "KEYSTORE_FILE=$KEYSTORE"
    echo "UPLOAD_SHA1=$(keystore_sha1 "$store_pw")"
  } > "$RECORD"
  chmod 600 "$RECORD"
  ok "credentials recorded at $RECORD (gitignored)"

  # 4. Confirm before pushing to GitHub ---------------------------------------
  echo
  bold "About to set these secrets in '$repo' → $ENVIRONMENT environment:"
  echo "  PLAY_SERVICE_ACCOUNT_JSON, ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS, ANDROID_KEY_PASSWORD"
  read -r -p "Proceed? [y/N] " yn
  [[ "$yn" =~ ^[Yy]$ ]] || { echo "Skipped pushing secrets. Local files are ready under $SECRETS_DIR."; exit 0; }

  # Ensure the environment exists, then set each secret.
  gh api -X PUT "repos/$repo/environments/$ENVIRONMENT" >/dev/null 2>&1 || true
  b64 "$KEYSTORE"   | gh secret set ANDROID_KEYSTORE_BASE64  --env "$ENVIRONMENT" --repo "$repo"
  printf '%s' "$store_pw" | gh secret set ANDROID_KEYSTORE_PASSWORD --env "$ENVIRONMENT" --repo "$repo"
  printf '%s' "$key_pw"   | gh secret set ANDROID_KEY_PASSWORD      --env "$ENVIRONMENT" --repo "$repo"
  printf '%s' "$KEY_ALIAS"| gh secret set ANDROID_KEY_ALIAS         --env "$ENVIRONMENT" --repo "$repo"
  gh secret set PLAY_SERVICE_ACCOUNT_JSON --env "$ENVIRONMENT" --repo "$repo" < "$sa"
  ok "all 5 secrets set in $repo ($ENVIRONMENT)"

  echo
  bold "Remaining manual steps"
  echo "  1. Create the Play Console app for 'social.betty.android' and upload one AAB by hand (accept the"
  echo "     developer agreement, enroll in Play App Signing). After that the workflow publishes."
  echo "  2. Register an Android OAuth client (package social.betty.android) with SHA-1:"
  echo "       upload: $(keystore_sha1 "$store_pw")"
  echo "       debug:  $(debug_sha1)"
  echo "     then set AppConfig.GOOGLE_OAUTH_CLIENT_ID (only needed for Google sign-in)."
}

case "${1:-check}" in
  check) cmd_check ;;
  setup) cmd_setup ;;
  *) echo "Usage: $0 {check|setup}" >&2; exit 1 ;;
esac
