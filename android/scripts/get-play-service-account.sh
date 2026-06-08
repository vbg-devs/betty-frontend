#!/usr/bin/env bash
#
# Creates a Google Cloud service account + JSON key for the Play Developer API — i.e. the
# `PLAY_SERVICE_ACCOUNT_JSON` secret used by android-playstore.yml.
#
# Scriptable here: enabling the API, creating the service account, downloading the key.
# NOT scriptable (Google exposes no API): linking the GCP project to Play Console and
# granting the service account release permissions — printed as manual steps at the end.
#
# Usage:
#   PROJECT=<gcp-project-id> android/scripts/get-play-service-account.sh
#
# Env (optional):
#   PROJECT   GCP project id that is (or will be) linked to Play Console — prompted if absent
#   SA_NAME   service-account id  (default: play-publisher)
#   OUTPUT    JSON key output path (default: android/.playstore-secrets/play-service-account.json)
#
# Requires: gcloud (authenticated), with permission to create service accounts + keys in PROJECT.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANDROID_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
SECRETS_DIR="$ANDROID_DIR/.playstore-secrets"

SA_NAME="${SA_NAME:-play-publisher}"
OUTPUT="${OUTPUT:-$SECRETS_DIR/play-service-account.json}"
API="androidpublisher.googleapis.com"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }

command -v gcloud >/dev/null 2>&1 || {
  echo "ERROR: gcloud is required. Install: https://cloud.google.com/sdk/docs/install" >&2; exit 1; }

# 1. Auth -------------------------------------------------------------------
if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' 2>/dev/null | grep -q .; then
  echo "No active gcloud account. Run:  gcloud auth login" >&2; exit 1
fi
ok "gcloud authenticated as $(gcloud auth list --filter=status:ACTIVE --format='value(account)' | head -1)"

# 2. Project ----------------------------------------------------------------
PROJECT="${PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}"
if [ -z "$PROJECT" ] || [ "$PROJECT" = "(unset)" ]; then
  read -r -p "GCP project id (the one linked to Play Console): " PROJECT
fi
[ -n "$PROJECT" ] || { echo "ERROR: no project id." >&2; exit 1; }
bold "Project: $PROJECT   ·   service account: $SA_NAME   ·   key → $OUTPUT"
read -r -p "Proceed? [y/N] " yn; [[ "$yn" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

# 3. Enable the Play Developer API -----------------------------------------
gcloud services enable "$API" --project "$PROJECT"
ok "enabled $API"

# 4. Create the service account (idempotent) --------------------------------
SA_EMAIL="$SA_NAME@$PROJECT.iam.gserviceaccount.com"
if gcloud iam service-accounts describe "$SA_EMAIL" --project "$PROJECT" >/dev/null 2>&1; then
  ok "service account already exists: $SA_EMAIL"
else
  gcloud iam service-accounts create "$SA_NAME" \
    --project "$PROJECT" \
    --display-name "Betty Play publisher (CI)"
  ok "created service account: $SA_EMAIL"
fi

# 5. Download a JSON key (gitignored) ---------------------------------------
umask 077
mkdir -p "$SECRETS_DIR"
gcloud iam service-accounts keys create "$OUTPUT" \
  --iam-account "$SA_EMAIL" --project "$PROJECT"
chmod 600 "$OUTPUT"
ok "key written to $OUTPUT (gitignored)"

# 6. Hand-off ---------------------------------------------------------------
echo
bold "MANUAL — finish in Play Console (Google exposes no API for this):"
echo "  1. Play Console → Setup → API access."
echo "  2. Link the Google Cloud project '$PROJECT' if it isn't already linked."
echo "  3. Under 'Service accounts', find $SA_EMAIL → Manage Play Console permissions →"
echo "     grant at least 'Release to testing tracks' (or Admin), then save/accept."
echo "  4. Permissions can take a few minutes to propagate."
echo
bold "Then set the secret:"
echo "  SA_JSON=$OUTPUT android/scripts/setup-playstore.sh setup"
echo "  # or directly:"
echo "  gh secret set PLAY_SERVICE_ACCOUNT_JSON --env release --repo vbg-devs/betty-frontend < $OUTPUT"
