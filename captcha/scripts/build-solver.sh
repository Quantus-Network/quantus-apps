#!/usr/bin/env bash
# Builds the WASM solver from quantus-miner and copies it into dist/.
set -euo pipefail

CAPTCHA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MINER_DIR="${QUANTUS_MINER_DIR:-$CAPTCHA_DIR/../../quantus-miner}"

echo "Building solver-wasm from $MINER_DIR"
(cd "$MINER_DIR" && CARGO_TARGET_DIR=target cargo build -p solver-wasm --target wasm32-unknown-unknown --release)

mkdir -p "$CAPTCHA_DIR/dist"
cp "$MINER_DIR/target/wasm32-unknown-unknown/release/solver_wasm.wasm" "$CAPTCHA_DIR/dist/"
echo "Wrote $CAPTCHA_DIR/dist/solver_wasm.wasm ($(wc -c < "$CAPTCHA_DIR/dist/solver_wasm.wasm") bytes)"
