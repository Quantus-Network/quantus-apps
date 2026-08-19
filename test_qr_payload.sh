#!/usr/bin/env bash
# Prints a signing-request QR for an offline wallet to scan.
#
# The QR carries the payload wrapped in the JSON envelope both wallets read,
# which names the account that must sign it — so it has to be an account the
# device actually holds, or the signer will say it does not hold that key.
#
#   ./test_qr_payload.sh <signer-address> [amount] [recipient-address]
#
# Point the cold wallet at Sign Transaction, or the mobile wallet at its
# Keystone scanner, and scan what this prints.
set -euo pipefail

# The live Planck node, so the request carries a genesis hash the wallets know.
# A local dev chain has its own genesis and every wallet refuses it.
NODE_URL="${NODE_URL:-wss://a1-planck.quantus.cat}"

# A wallet whose bundled metadata came from a different runtime than the node
# runs says so on its review screen. That warning is the wallet working, not a
# fault in the request: the versions here are whatever the node reports.

if [ $# -lt 1 ]; then
	echo "usage: $(basename "$0") <signer-address> [amount] [recipient-address]" >&2
	echo "" >&2
	echo "  signer-address     the account that must sign, as shown on the wallet's" >&2
	echo "                     Show Key screen" >&2
	echo "  amount             tokens to send, default 1.5" >&2
	echo "  recipient-address  who receives them, default the signer itself" >&2
	echo "" >&2
	echo "  NODE_URL and QUANTUS override the node and the CLI binary." >&2
	exit 64
fi

SIGNER="$1"
AMOUNT="${2:-1.5}"
RECIPIENT="${3:-}"

# A sibling quantus-cli checkout is the usual place; PATH is checked first, and
# QUANTUS overrides both. `quantus` is often a shell alias, which a script
# cannot see, hence the explicit look.
CLI_BUILD="$(cd "$(dirname "$0")/.." && pwd)/quantus-cli/target/release/quantus"
QUANTUS="${QUANTUS:-$(command -v quantus || true)}"
if [ -z "$QUANTUS" ] && [ -x "$CLI_BUILD" ]; then
	QUANTUS="$CLI_BUILD"
fi
if [ -z "$QUANTUS" ]; then
	echo "quantus CLI not found. Build it, or set QUANTUS to the binary:" >&2
	echo "  cargo build --release   # in the quantus-cli checkout" >&2
	echo "  QUANTUS=/path/to/quantus $(basename "$0") $SIGNER" >&2
	exit 69
fi

args=(signing-qr --from "$SIGNER" --amount "$AMOUNT" --node-url "$NODE_URL")
[ -n "$RECIPIENT" ] && args+=(--to "$RECIPIENT")

exec "$QUANTUS" "${args[@]}"
