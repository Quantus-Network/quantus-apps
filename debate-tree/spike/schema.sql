-- Debate Tree — spike schema.
-- Plain Postgres (runs on PGlite in the spike, ports verbatim to hosted PG).
-- Deliberately minimal: no gate_proof (spam gate lands with the captcha),
-- no ltree (PGlite has no ltree ext; we walk the adjacency list with a
-- recursive CTE, which is plenty at spike scale).

create table if not exists space (
  id          uuid primary key default gen_random_uuid(),
  slug        text unique not null,
  question    text not null,
  config      jsonb not null default '{}'::jsonb,
  created_at  timestamptz not null default now()
);

create table if not exists node (
  id             uuid primary key default gen_random_uuid(),
  space_id       uuid not null references space(id) on delete cascade,
  parent_id      uuid references node(id) on delete cascade,   -- null = direct answer to the space question
  kind           text not null check (kind in ('answer','pro','con')),
  author_account text not null default 'anon',
  published_text text not null,                                -- author-approved steelman = the node
  original_text  text not null,                                -- verbatim submission, always attached
  transcript     jsonb,                                        -- negotiation provenance
  content_hash   bytea,                                        -- for optional on-chain anchoring later
  embedding      EMBEDDING_COL,                                -- dedup search (populated later); see db.mjs
  created_at     timestamptz not null default now()
);

create index if not exists node_space_parent_idx on node (space_id, parent_id);

create table if not exists vote (
  node_id  uuid not null references node(id) on delete cascade,
  account  text not null,
  value    smallint not null check (value in (-1, 1)),
  primary key (node_id, account)
);
