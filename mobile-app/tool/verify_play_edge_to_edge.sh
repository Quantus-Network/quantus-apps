#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "Checking source for deprecated edge-to-edge APIs..."

if command -v rg >/dev/null 2>&1; then
  SEARCH_CMD='rg -n'
else
  SEARCH_CMD='grep -R -nE'
fi

if eval "$SEARCH_CMD \"setStatusBarColor|setNavigationBarColor|setNavigationBarDividerColor\" android lib"; then
  echo
  echo "Fail: deprecated Android edge-to-edge APIs found."
  exit 1
fi

if eval "$SEARCH_CMD \"SystemUiOverlayStyle\\([^)]*(statusBarColor|systemNavigationBarColor|systemNavigationBarDividerColor)\" lib"; then
  echo
  echo "Fail: deprecated system bar color parameters found in Flutter overlay style."
  exit 1
fi

echo "Pass: no deprecated edge-to-edge API usage found in source."
