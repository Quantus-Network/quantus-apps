# Debate Tree spike

Throwaway prototype: steelman negotiation loop + PGlite-backed debate tree.
The prompts (`prompts.mjs`) are the main artifact; everything else is
hackathon scaffolding.

## Quick start (seeded demo tree)

```sh
cd quantus-apps/debate-tree/spike
npm install

OPENROUTER_API_KEY=sk-or-v1-... \
  PORT=8789 \
  PGDATA_DIR=pgdata-demo \
  node server.mjs
```

Open http://127.0.0.1:8789/

Startup should log `model provider: openrouter (anthropic/claude-sonnet-4)`.
The yellow stub warning in the composer disappears once a real provider is active.

## Model providers

Priority order (first key wins):

| Env var | Provider |
|---------|----------|
| `ANTHROPIC_API_KEY` | Anthropic direct |
| `OPENAI_API_KEY` | OpenAI direct |
| `OPENROUTER_API_KEY` | OpenRouter (any model slug) |
| *(none)* | **stub** — echoes your text back; UI flow only |

Optional: `OPENROUTER_MODEL` (default `anthropic/claude-sonnet-4`),
`ANTHROPIC_MODEL`, `OPENAI_MODEL`.

Without an API key the server still runs, but the moderator does not
steelman — it splits sentences and softens insults. Fine for UI testing;
not fine for demos.

## Database directories

PGlite stores data under `spike/pgdata*/` (gitignored). Pick one per instance:

| Directory | Contents |
|-----------|----------|
| `pgdata-demo` | **Seeded** 42-node djb hybrid-vs-solo-PQ tree — use for demos |
| `pgdata` | Default when `PGDATA_DIR` is unset; empty on first run, then your test posts |

Set `PGDATA_DIR=pgdata-demo` explicitly so you don't accidentally run against
an old test database. Only one `node server.mjs` process can open a given
directory at a time.

**Reset a database:** stop the server, then `rm -rf pgdata-demo` (or `pgdata`).
The seeded tree is recreated automatically on next start if the space is empty.

## What works

- Read: nested answer / pro / con tree, votes, collapsible branches
- Write: steelman loop (disentangle → relevance check → duplicate check →
  succinct steelman), publish to tree
- Click any argument to dock the composer and reply; negotiation state clears
  when you retarget
- Off-target claims cannot be published; near-duplicates offer upvote-existing
- Seeded content: verbatim quotes from the public record (`seed.mjs`), no AI
  rewrite of imports

## Not wired yet

- Captcha / share-token gate on writes
- Wallet auth + QTC balance gate for new questions
- Embedding-based dedup (pgvector optional; currently disabled)
- Shareable per-node links, QIP space, on-chain anchoring

See `../PLAN.md` for the full roadmap.
