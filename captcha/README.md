# Quantus Captcha

A proof-of-work captcha whose work is a **real Quantus mining share**.
No tracking, no image puzzles, no data labeling — the visitor's device does
~1 second of Poseidon2 hashing over the current block header, and the site
host earns any block the aggregate share stream happens to find.

Components:

- **Pool service** (`quantus-miner/crates/pool-service`) — connects to a
  `quantus-node` as an external miner, hands out low-difficulty share
  challenges with disjoint nonce ranges, verifies solves, mints single-use
  tokens, submits network-difficulty shares as blocks.
- **WASM solver** (`quantus-miner/crates/solver-wasm`) — raw C-ABI WASM
  module (no wasm-bindgen), built with plain `cargo build`.
- **Widget** (`widget/`) — drop-in JS: checkbox UI, Web Worker solver,
  hidden token input, `quan-captcha-solved` event.
- **Demo** (`demo/`) — a spam-protected form.

## Quick start (standalone demo, no node needed)

```sh
# 1. Build the WASM solver into dist/
./scripts/build-solver.sh

# 2. Run the pool in standalone mode, serving this directory
cd ../../quantus-miner
cargo run -p pool-service -- --serve-dir ../quantus-apps/captcha

# 3. Open the demo
open http://127.0.0.1:8787/demo/
```

## Against a real node

```sh
quantus-node --dev            # external-miner QUIC endpoint on :9833
cargo run -p pool-service -- \
  --node-addr 127.0.0.1:9833 \
  --share-difficulty 2000 \
  --site-secret "$(openssl rand -hex 16)" \
  --serve-dir ../quantus-apps/captcha
```

## Integrating on a website

```html
<form action="/comment" method="post">
  <textarea name="text"></textarea>
  <div class="quan-captcha" data-endpoint="https://pool.example.com"></div>
  <button>Post</button>
</form>
<script src="https://pool.example.com/widget/quan-captcha.js" defer></script>
```

Server-side, redeem the submitted `quan-captcha-token` exactly once
(mirrors the reCAPTCHA/Turnstile siteverify shape):

```sh
curl -X POST https://pool.example.com/siteverify \
  -H 'content-type: application/json' \
  -d '{"secret": "<your site secret>", "response": "<token>"}'
# -> {"success": true, "challenge_ts": 1751600000}
```

## API

| Endpoint | Caller | Purpose |
|---|---|---|
| `POST /api/session` | widget | issue challenge: header, disjoint nonce range, share target |
| `POST /api/share` | widget | verify solved nonce, mint single-use token |
| `POST /siteverify` | site backend | redeem token (secret + response) |
| `GET /api/stats` | anyone | pool counters |

## Threat model, honestly

- This is a **rate limiter, not sybil resistance**: it prices requests in
  compute, it does not identify humans. A GPU farm pays less per share than
  a phone; keep the share difficulty in "annoying to bots, invisible to
  humans" territory and layer account/balance gates for high-value actions.
- Sessions are single-use, expire in 120 s, and shares are only valid inside
  the session's assigned nonce range over the session's header snapshot —
  no precomputation, no replay, no share theft.
- Tokens are single-use and expire in 300 s.
- Work runs only on explicit user action (Coinhive's fatal mistake was
  ambient page-load mining without consent — see the plan doc in
  `../debate-tree/PLAN.md`).
