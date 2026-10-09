# Sourced by the upload scripts. --swap-test: internal test build that offers swap regardless of flags and location;
# never ship it to a store's production track.
DEFINES=""
[ $# -le 1 ] || { echo "Too many options: $* (only --swap-test is supported)" >&2; exit 1; }
case "${1:-}" in
  "") ;;
  --swap-test)
    DEFINES="--dart-define=SWAP_ALLOW_OVERRIDE=true"
    echo "*** SWAP TEST BUILD: swap is on regardless of remote flags and location. Internal testing only. ***"
    ;;
  *) echo "Unknown option: $1 (only --swap-test is supported)" >&2; exit 1 ;;
esac
