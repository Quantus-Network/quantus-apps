# Debate Tree — Project Plan

AI-moderated structured debate for the Quantus ecosystem, spam-protected by
Quantus-native primitives (mining-share proof-of-work and QUAN balance gates).

**Runnable prototype:** `spike/` — see [`spike/README.md`](spike/README.md).

This plan covers three deliverables across two repos:

| # | Component | Location | What it is |
|---|-----------|----------|------------|
| 1 | **Share Pool** (pool middleman) | `quantus-miner/pool-service` | A pool-like service that turns captcha solves into real mining shares and pays hosts |
| 2 | **Captcha Gadget** | `quantus-apps/captcha` | Embeddable widget + verify API — a drop-in Turnstile/reCAPTCHA replacement |
| 3 | **Debate Tree** | `quantus-apps/debate-tree` | The debate webapp: tree UI, AI steelman moderator, chain-gated writes |

Dependency direction: `debate-tree` → `captcha` → `pool-service` → `quantus-node`.
Each layer is independently useful; the captcha is a product in its own right.

---

## 1. Product vision

**Debate Tree** is a structured-debate platform: a question at the root,
candidate answers below it, pros/cons under each answer, and responses to
those, recursively. (Prior art: Kialo — the tree format is proven. Our
differentiators are the AI moderator and the chain-native spam economics.)

**The AI is a moderator on the write path, not a participant:**

- **Deduplication** — before a new node is accepted, check whether the point
  already exists in the tree; near-duplicates are redirected to the existing
  node ("upvote / extend this instead?"). The spike does this in the steelman
  prompt (sibling list + LLM judgment); production will add embedding similarity
  for borderline cases.
- **Relevance** — each claim must engage its reply target (parent claim or the
  debate question). Off-target drafts are steelmanned but blocked from publish;
  the author can negotiate to re-aim.
- **Disentangle + steelman loop** — a contributor drafts a post; the AI first
  splits bundled points into separate claims (one tree node = one claim), then
  offers a succinct steelman of each. The contributor picks a claim, revises or
  accepts (capped at ~3 rounds per claim). Only AI-generated versions are
  publishable — there is no "publish my raw original" path; the contributor's
  control is exercised through accept/revise, not through bypassing the
  moderator. The original text stays attached (visible on click) so the
  author's own words are never lost, but the tree node itself is always a
  steelman the author approved.
- **The AI never rewrites imported/seeded content.** Seeded arguments cite
  their sources verbatim.

**Spam / cost protection** (also bounds our LLM spend):

- **Reading**: free, no account, indexable. The tree is the growth asset.
- **Creating a question**: requires a signed challenge from a wallet holding
  ≥ N QUAN (threshold configurable per space). Capital-at-stake, nothing
  locked or slashed.
- **Posting answers/pros/cons + starting a steelman session**: requires a
  proof-of-work share via the captcha gadget. Rate limiter, not identity.
- App-layer rate limits and per-user/global LLM spend caps on top.

**Governance tie-in**: Quantus currently has no community governance lane
(the runtime's referenda are tech-collective-only) and QIPs have no
discussion venue. Debate Tree is the deliberation layer; on-chain referenda
remain the decision layer. Tree conclusions link to referenda; content
itself stays off-chain (optionally hash-anchored per published node).

---

## 2. Component 1 — Share Pool (`quantus-miner/pool-service`)

A new crate alongside `miner-service`, reusing `pow-core` hashing and the
`quantus-miner-api` types.

**Concept**: the node's external-miner protocol already broadcasts
`NewJob { header_hash, difficulty }` and accepts `JobResult`. The pool
service sits between a node and thousands of weak browser solvers:

```
quantus-node ──NewJob──► pool-service ──job + nonce-range + share-target──► browser solvers
quantus-node ◄──block──  pool-service ◄──────────share (nonce)────────────  browser solvers
```

- Holds the current job from an upstream node (QUIC, existing protocol).
- Issues **captcha sessions**: `{ header_hash, disjoint nonce range, share
  target (≪ network difficulty), expiry }`. The nonce range is the session
  binding — a returned nonce identifies which session earned it. Freshness
  is free: shares are only valid against the current block template.
- Verifies submitted shares (one hash) and issues a single-use
  **share token** consumed by the captcha verify API.
- If a share also meets full network difficulty → submit as a real block;
  reward accrues to the pool operator's account.
- Tracks per-host share counts for **pro-rata (PPLNS-style) payouts** to
  registered captcha hosts. Self-hosters can point their share stream at a
  community pool or run solo.

**Economics honesty** (goes in the README, not just here): expected revenue
per captcha is (client work ÷ network hashrate) × emission rate — dust once
the chain has real hashrate. Early-chain revenue is real; long-term the
honest pitch is *non-wasteful* PoW (work secures the network instead of
being burned, unlike Friendly Captcha / Anubis) plus dust. **Pay the host,
never the solver** — paying solvers pays people to spam.

**Deliverables**:
- [x] `pool-service` crate: upstream QUIC client, session issuance API,
      share verification, share-token store, block submission
- [x] `siteverify` endpoint (see Component 2 — same service, site-facing)
- [ ] Host registration + payout ledger (payouts can be manual at first)
- [ ] Metrics (reuse `metrics` crate patterns), Docker image
- [x] Integration test against `quantus-node --dev` (manual e2e: browser
      solved real shares against a dev node's block headers, 2026-07-04)

## 3. Component 2 — Captcha Gadget (`quantus-apps/captcha`)

A drop-in, privacy-first captcha. Positioning: Turnstile's UX without
Cloudflare, Friendly Captcha / Anubis mechanics but the work is real mining.
No puzzles, no tracking, no data labeling. Coinhive's captcha proved the UX;
Coinhive's death defines our guardrails:

- Work only on explicit user action (form submit), never ambient page-load.
- Bounded and disclosed: "~1s of computation supports this site."
- Open source, first-party-servable loader (no single CDN domain to blocklist).

**Pieces**:
- `solver/` — Rust → WASM build of `pow-core` hashing (lives here or under
  `quantus-miner/web-miner`, which already has a Vite+WebGPU scaffold;
  decide when wiring the build). WebGPU fast path, WASM fallback.
- `widget/` — TS embed: `<div class="quan-captcha" data-sitekey=…>` +
  ~3 kB loader. Renders checkbox → fetches session from pool-service →
  solves → posts share → emits share token into the form.
- Server-side verify: site backend calls `POST /siteverify {token, secret}`
  on pool-service (mirrors reCAPTCHA/Turnstile API shape for trivial migration).
- `demo/` — demo page + abuse-cost calculator.

**Deliverables**:
- [x] WASM solver package (`quantus-miner/crates/solver-wasm`, raw C ABI,
      ~40 kB; measured ≈120 kH/s in-browser on an M-series laptop)
      — WebGPU fast path still open
- [x] Embed widget + loader, Turnstile-compatible verify API
- [x] Docs: integration guide, threat model (rate-limiter not sybil-proof;
      native-GPU attacker pays less per share than a phone — tune share
      target accordingly), Coinhive-lessons disclosure
- [x] Demo site (`demo/`, served by pool-service `--serve-dir`)

## 4. Component 3 — Debate Tree webapp (`quantus-apps/debate-tree`)

**Stack** (spike): vanilla HTML/JS frontend + Node `server.mjs`, PGlite
(in-process Postgres), LLM via Anthropic / OpenAI / OpenRouter (stub offline
fallback). Production framework TBD; Postgres + pgvector for embeddings.
Wallet auth via ML-DSA signature verification —
`quantus_sdk`'s Rust bridge is a reference;
server-side verification can link the same Rust crates.

**Data model** (implemented in `spike/schema.sql` — pure adjacency tree,
plain Postgres so it ports from the spike's PGlite to hosted PG verbatim):
- `space` — a debate context (e.g. "QIPs", "PQ-migration"), holds `config`
  jsonb: question threshold N QUAN, share target, model tier.
- `node` — id, space, `parent_id` (null = direct answer to the question),
  kind (`answer | pro | con`), `published_text` (author-approved steelman =
  the node), `original_text` (verbatim, always attached), `transcript` jsonb
  (negotiation provenance, inlined — no separate session table needed for
  durable state), `content_hash` (optional on-chain anchoring), `embedding`
  (dedup search). Walked with a recursive CTE / adjacency list; no `ltree`,
  no `status`/redirect, no `node_edge` — dupes are simply not inserted.
- `vote` — (node, account, value ±1), one row per account per node.
- **Dropped for now**: `gate_proof` (consumed share-token / balance-attestation
  ledger + replay guard) lands with the captcha write-path integration.
  Ephemeral steelman-negotiation state lives in server memory, not the DB.

Spike DB is **PGlite** (Postgres compiled to WASM, in-process, persisted to
`spike/pgdata*/`): zero external server, same SQL as prod. Use
`PGDATA_DIR=pgdata-demo` for the seeded djb tree; default `pgdata/` is for
local experiments. `pgvector` is an optional add-on; when absent, `embedding`
falls back to jsonb and embedding dedup is disabled. Reset by deleting the
directory while the server is stopped. Run instructions: `spike/README.md`.

**Write path**:
1. Client requests action → backend issues nonce challenge.
2. Question: wallet signs `{nonce, action, timestamp}`; backend verifies
   signature + balance ≥ N via node RPC / `quantus_subsquid`.
   Answer/pro/con: captcha share token required to open a steelman session.
3. Dedup check (embedding similarity → LLM confirm on borderline).
4. Steelman loop (≤ 3 rounds) → contributor approves → publish.

**Seed content — the djb hybrid-vs-pure-PQ debate**:
- Question: *"How should TLS 1.3 handle post-quantum key agreement?"* —
  framed open (not either/or) so the tree admits more than two positions;
  "standardize solo ML-KEM" and "require hybrid ECC+PQ" are seeded as the
  first two answer nodes.
- Curated from the public record with per-node citations: IETF TLS WG
  mailing list, djb's IESG appeals (Oct/Dec 2025), blog.cr.yp.to, LWN
  coverage. **No AI paraphrasing of imported arguments** — verbatim quotes
  + neutral summaries with links.
- Map the *technical* debate only; keep the process/consensus-legitimacy
  fight (appeals drama) out of the seed tree.
- **Neutrality disclosure, prominent**: Quantus is a pure-PQ chain and
  therefore a party to this debate. "We have a stake; here's the map;
  correct us." Invite corrections before promoting it anywhere.
- Second space: QIP discussions (own community, real decisions, zero
  current venue).

**Deliverables**:
- [x] Steelman-loop spike (see §5) — disentangle, relevance check, duplicate
      check, succinct steelman loop; OpenRouter/Anthropic/OpenAI + stub fallback
- [x] DB-backed tree: PGlite schema, publish/tree/vote endpoints, seeded space
- [x] Tree UI (read + write): nested pro/con/answer nodes, collapsible branches,
      per-answer pro/con tallies, inline composer (click node to reply),
      votes, original/source text on click — served from the DB
- [x] Seeded djb tree: 36 nodes curated from the debate-structure chart
      (blog.cr.yp.to/20260221-structure.html), technical branches only —
      process/consensus-legitimacy arguments omitted; verbatim wording +
      citation behind each node's "Source" toggle (`spike/seed.mjs`)
- [ ] Node detail: shareable per-node links
- [ ] Wallet auth + balance gate; captcha gate integration
- [ ] Embedding dedup (pgvector) + production write-path spend caps
- [ ] QIP space (second seeded space)
- [ ] Optional: per-node hash anchoring via `system.remark` (defer)

---

## 5. Build order

**Track A (start now): pool-service + captcha as ONE vertical slice.**
Neither is testable end-to-end without the other — a pool with no solver
client proves nothing, a widget with no verifier is a mock. Milestone:
demo page on a laptop solves a share against `quantus-node --dev`, verify
endpoint accepts the token, dashboard shows accrued shares.

**Track B (done): steelman-loop spike + DB-backed tree UI.**
Validated the negotiation UX (disentangle, relevance, duplicates, succinct
steelman) and the read/write tree against PGlite. Prompts live in
`spike/prompts.mjs`; run guide in `spike/README.md`.

**Next: production write path** — captcha share-token gate, wallet balance
gate for new questions, embedding dedup, spend caps. The captcha is also
independently shippable regardless of how Debate Tree evolves.

**Sequencing summary**:
1. ~~Track A slice (pool + widget + demo)~~ — done
2. ~~Debate Tree spike (steelman + read/write tree + seeded djb content)~~ — done
3. **Now:** gates on the write path (captcha + wallet) + embedding dedup
4. QIP space, shareable node links, payouts polish, on-chain anchoring

## 6. Risks

| Risk | Mitigation |
|------|------------|
| Cryptojacking stigma / AV & adblock flagging | Consent + bounded work + first-party loader + open source; never ambient mining |
| Share revenue ≈ dust as hashrate grows | Market as non-wasteful + host-paid, not get-rich; pool aggregation for variance |
| Native-GPU spammers vs. phone users (PoW asymmetry) | Share target tuned low (rate limiter framing); balance gate for high-value actions |
| AI steelman feels condescending / voice laundering | Spike first; contributor approval required (accept/revise, no raw-publish bypass); original text always attached |
| Moderator bias becomes tree bias | Publish steelman prompts; show diff original→published |
| Quantus not neutral on the seed debate | Prominent disclosure; verbatim citations; invite corrections |
| djb reacts badly to AI paraphrase | Never AI-rewrite imported content |
| LLM spend abuse | Share token required per steelman session; round caps; per-user/global spend caps |
| Balance gate = plutocratic speech | Gate only question creation; answers need only PoW; bonds-not-balances revisit later |

## 7. Open questions

- Pool payout cadence/mechanism (manual → automated on-chain batch?).
- Where the WASM solver crate lives (`quantus-apps/captcha/solver` vs
  `quantus-miner/web-miner`) — decide when wiring the build.
- Webapp framework + hosting; whether backend verifies ML-DSA sigs via
  linked Rust crate or a small verifier sidecar.
- Per-space QUAN thresholds — governance-adjustable? fiat-pegged?
- Whether/when to anchor node hashes on-chain.
