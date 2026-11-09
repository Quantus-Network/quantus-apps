# Sourced by the upload scripts. Fails instead of rewriting pubspec.lock when it doesn't fit pubspec.yaml or the SDK.
flutter pub get --enforce-lockfile
[ $# -eq 0 ] || { echo "Unknown option: $*" >&2; exit 1; }
