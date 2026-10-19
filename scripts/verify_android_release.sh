#!/bin/sh
# Verifies a published Android wallet release: the tag's commit, release immutability,
# checksums, build provenance for that commit, and the APK's signer, package and
# version against the sources at that commit.
# Usage: verify_android_release.sh <tag>   e.g. wallet-v1.7.4+158
# Needs gh (signed in), git, openssl, and apksigner, aapt2 and zipalign (build-tools 35+) on PATH.
set -eu

[ $# -eq 1 ] || { echo "usage: $0 <tag>" >&2; exit 2; }
TAG=$1
REPO=Quantus-Network/quantus-apps
REPO_URL="https://github.com/$REPO"

fail() { echo "error: $*" >&2; exit 1; }

case "$TAG" in
  wallet-v*) APP_DIR=mobile-app ;;
  cold-wallet-v*) APP_DIR=cold-wallet-app ;;
  *) fail "unknown tag prefix in $TAG (expected wallet-v or cold-wallet-v)" ;;
esac

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

REF=$(git ls-remote --exit-code "$REPO_URL" "refs/tags/$TAG") || fail "tag $TAG not found"
COMMIT=$(echo "$REF" | cut -f1)
echo "tag $TAG is commit $COMMIT"

[ "$(gh release view "$TAG" --repo "$REPO" --json isImmutable --jq .isImmutable)" = true ] ||
  fail "release $TAG is not immutable, so its tag and assets can still change"

gh release download "$TAG" --repo "$REPO" --dir "$WORK/dist"
while read -r SUM NAME; do
  [ "$(openssl dgst -sha256 -r "$WORK/dist/$NAME" | cut -d' ' -f1)" = "$SUM" ] || fail "checksum mismatch for $NAME"
done < "$WORK/dist/SHA256SUMS"
echo "checksums match SHA256SUMS"

set -- "$WORK"/dist/*.apk
[ $# -eq 1 ] && [ -f "$1" ] || fail "expected exactly one APK in release $TAG"
APK=$1

gh attestation verify "$APK" --repo "$REPO" \
  --signer-workflow "$REPO/.github/workflows/build_wallet_apk.yml" \
  --source-ref refs/heads/main --source-digest "$COMMIT" --deny-self-hosted-runners
gh release verify-asset "$TAG" "$APK" --repo "$REPO"

git -C "$ROOT" cat-file -e "$COMMIT^{commit}" 2>/dev/null || git -C "$ROOT" fetch --quiet "$REPO_URL" "$COMMIT"
mkdir "$WORK/src"
git -C "$ROOT" archive "$COMMIT" "$APP_DIR/pubspec.yaml" "$APP_DIR/android" | tar -x -C "$WORK/src"
"$ROOT/scripts/verify_android_apk.sh" "$APK" "$WORK/src/$APP_DIR"

echo "OK: $(basename "$APK") was built from $COMMIT by $REPO's release workflow and signed with the pinned key"
