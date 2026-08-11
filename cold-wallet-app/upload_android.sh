#!/bin/sh
## Build a release AAB and optionally upload it to Google Play internal testing.
##
## First-time Play Console setup (one-time, browser):
##   1. https://play.google.com/console → Create app
##        name: Quantus Cold Wallet
##        package: com.quantus.coldwallet
##        free, app (not game)
##   2. Setup → App integrity → App signing: enroll (recommended: Play App Signing)
##   3. Setup → API access → link a Google Cloud project → create a service account
##        with "Release apps to testing tracks" permission, download JSON key
##   4. Save the JSON as android/play-service-account.json (gitignored) OR set
##        PLAY_SERVICE_ACCOUNT_JSON=/path/to/key.json
##   5. Internal testing → create release → (this script can upload thereafter)
##
## Usage:
##   ./upload_android.sh              # build AAB only, open output folder
##   ./upload_android.sh --upload     # build + upload to internal track

set -eu

cd "$(dirname "$0")"

PACKAGE_NAME="com.quantus.coldwallet"
TRACK="internal"
AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
DEFAULT_SA="android/play-service-account.json"

DO_UPLOAD=0
for arg in "$@"; do
  case "$arg" in
    --upload) DO_UPLOAD=1 ;;
    -h|--help)
      sed -n '2,20p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"

echo "Building release app bundle..."
flutter build appbundle --release

if [ ! -f "$AAB_PATH" ]; then
  echo "error: AAB not found at $AAB_PATH" >&2
  exit 1
fi

echo "AAB: $AAB_PATH ($(du -h "$AAB_PATH" | awk '{print $1}'))"

if [ "$DO_UPLOAD" -eq 0 ]; then
  echo "Skipping upload (pass --upload once Play Console + service account are ready)."
  open "$(dirname "$AAB_PATH")"
  exit 0
fi

SA_JSON="${PLAY_SERVICE_ACCOUNT_JSON:-$DEFAULT_SA}"
if [ ! -f "$SA_JSON" ]; then
  echo "error: service account JSON not found at $SA_JSON" >&2
  echo "Set PLAY_SERVICE_ACCOUNT_JSON or place key at $DEFAULT_SA" >&2
  exit 1
fi

VENV="${PLAY_API_VENV:-$HOME/play/quantus-network/.agent-tmp/grok/play-api-venv}"
if [ ! -x "$VENV/bin/python" ]; then
  echo "Creating Play API venv at $VENV..."
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install -q google-api-python-client google-auth
fi

export PACKAGE_NAME TRACK AAB_PATH SA_JSON
"$VENV/bin/python" - <<'PY'
import os
import sys
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

package = os.environ["PACKAGE_NAME"]
track = os.environ["TRACK"]
aab = os.environ["AAB_PATH"]
sa = os.environ["SA_JSON"]

scopes = ["https://www.googleapis.com/auth/androidpublisher"]
creds = service_account.Credentials.from_service_account_file(sa, scopes=scopes)
svc = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)

print(f"Creating edit for {package}...")
edit = svc.edits().insert(body={}, packageName=package).execute()
edit_id = edit["id"]
print(f"Edit {edit_id}: uploading AAB...")

media = MediaFileUpload(aab, mimetype="application/octet-stream", resumable=True)
bundle = (
    svc.edits()
    .bundles()
    .upload(editId=edit_id, packageName=package, media_body=media)
    .execute()
)
version_code = bundle["versionCode"]
print(f"Uploaded versionCode={version_code}")

print(f"Assigning to track '{track}'...")
svc.edits().tracks().update(
    editId=edit_id,
    packageName=package,
    track=track,
    body={
        "track": track,
        "releases": [
            {
                "name": f"{version_code}",
                "versionCodes": [str(version_code)],
                "status": "completed",
            }
        ],
    },
).execute()

print("Committing edit...")
svc.edits().commit(editId=edit_id, packageName=package).execute()
print(f"Done. {package} versionCode {version_code} on track '{track}'.")
PY
