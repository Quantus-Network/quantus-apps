# Shared helpers for Patrol E2E runner scripts under mobile-app/scripts/.
# Source from a script in that directory, e.g.:
#   source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/patrol_common.sh"

# Resolve SCRIPT_DIR / APP_ROOT from the calling script and cd to APP_ROOT.
patrol_resolve_app_root() {
  local caller_source="${1:?patrol_resolve_app_root requires the caller script path}"
  SCRIPT_DIR="$(cd "$(dirname "$caller_source")" && pwd)"
  APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
  cd "$APP_ROOT"
}

# Default BUILD_MODE and TEST_TARGETS before parsing CLI args.
patrol_init_runner_args() {
  BUILD_MODE="--debug"
  TEST_TARGETS=()
}

# Parse shared Patrol runner flags. Platform-specific options are delegated to
# the optional callback, which must set PLATFORM_CONSUMED to the number of args
# consumed and return 0 when it handles a flag (return 1 when unrecognized).
#
# Usage:
#   patrol_parse_runner_args <usage_fn> <supports_build_mode:true|false> \
#     [<platform_option_fn>] "$@"
patrol_parse_runner_args() {
  local usage_fn="$1"
  local supports_build_mode="$2"
  local platform_option_fn="${3:--}"
  shift 3

  patrol_init_runner_args

  while [[ $# -gt 0 ]]; do
    PLATFORM_CONSUMED=0
    if [[ "$platform_option_fn" != "-" ]] && "$platform_option_fn" "$@"; then
      shift "$PLATFORM_CONSUMED"
      continue
    fi

    case "$1" in
      --debug|--release)
        if [[ "$supports_build_mode" != "true" ]]; then
          echo "ERROR: unknown option: $1" >&2
          "$usage_fn"
          exit 1
        fi
        BUILD_MODE="$1"
        shift
        ;;
      -h|--help)
        "$usage_fn"
        exit 0
        ;;
      --)
        shift
        TEST_TARGETS+=("$@")
        break
        ;;
      -*)
        echo "ERROR: unknown option: $1" >&2
        "$usage_fn"
        exit 1
        ;;
      *)
        TEST_TARGETS+=("$1")
        shift
        ;;
    esac
  done
}

# Test secrets/fixtures (e.g. TEST_IMPORT_MNEMONIC) are injected at build time via
# --dart-define so they are never bundled into the app as an asset.
#   * Locally: read from a gitignored .env.test (key=value) via --dart-define-from-file.
#   * CI: export TEST_IMPORT_MNEMONIC (and any others) from the runner's secret store.
patrol_collect_dart_defines() {
  DART_DEFINES=()
  if [[ -f .env.test ]]; then
    echo "==> Injecting test secrets from .env.test"
    DART_DEFINES+=(--dart-define-from-file=.env.test)
  else
    echo "WARNING: no .env.test file and TEST_IMPORT_MNEMONIC is unset;" \
         "tests that need a seed phrase (e.g. import_wallet) will fail." >&2
  fi
}

# Build the `-t <target>` flags from TEST_TARGETS. With no targets, patrol bundles
# every `*_test.dart` under `patrol_test/`, i.e. the whole suite in one binary.
# Optional first argument is the verb in the "no targets" message (default: running).
patrol_build_target_args() {
  local action="${1:-running}"
  TARGET_ARGS=()
  if [[ ${#TEST_TARGETS[@]} -gt 0 ]]; then
    for target in "${TEST_TARGETS[@]}"; do
      TARGET_ARGS+=(-t "$target")
    done
    echo "==> Test targets: ${TEST_TARGETS[*]}"
  else
    echo "==> No targets given; ${action} the WHOLE patrol_test suite."
  fi
}
