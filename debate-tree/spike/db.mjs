// Debate Tree spike DB — PGlite (Postgres in-process, persisted to ./pgdata).
// Same SQL runs on a hosted Postgres later; only the connection line changes.

import { PGlite } from "@electric-sql/pglite";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const DIR = dirname(fileURLToPath(import.meta.url));

let db;
let hasVector = false;

function slugify(s) {
  return (
    s
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/^-+|-+$/g, "")
      .slice(0, 60) || "space"
  );
}

// Default seed: djb's hybrid-vs-pure-PQ TLS question, so the tree isn't empty.
const DEFAULT_SPACE = {
  slug: "tls-pq-hybrid",
  question:
    "Should TLS 1.3 standardize pure ML-KEM key agreement, or require hybrid (ECC+PQ)?",
};

export async function initDb() {
  // pgvector is an optional add-on for PGlite (not bundled in 0.5.x). If it's
  // present we enable it and give `embedding` a real vector type for dedup;
  // otherwise we fall back to jsonb so the tree still works. Dedup is deferred,
  // so the fallback is expected for now — on hosted Postgres you just
  // `create extension vector;` and the same schema gets vector(1024).
  let extensions = {};
  try {
    const { vector } = await import("@electric-sql/pglite/vector");
    extensions = { vector };
    hasVector = true;
  } catch {
    hasVector = false;
  }

  const dataDir = process.env.PGDATA_DIR
    ? join(DIR, process.env.PGDATA_DIR)
    : join(DIR, "pgdata");
  db = new PGlite(dataDir, { extensions });
  await db.waitReady;

  if (hasVector) {
    await db.exec("create extension if not exists vector;");
  }

  let schema = await readFile(join(DIR, "schema.sql"), "utf8");
  schema = schema.replace(
    /EMBEDDING_COL/,
    hasVector ? "vector(1024)" : "jsonb"
  );
  await db.exec(schema);

  await getOrCreateSpace(DEFAULT_SPACE.question, DEFAULT_SPACE.slug);
  console.log(
    `db ready (pgvector: ${hasVector ? "on" : "off — dedup disabled"})`
  );
  return db;
}

export async function getOrCreateSpace(question, slug) {
  const s = slug || slugify(question);
  const existing = await db.query(
    "select * from space where slug = $1 or question = $2 limit 1",
    [s, question]
  );
  if (existing.rows[0]) return existing.rows[0];
  const inserted = await db.query(
    "insert into space (slug, question) values ($1, $2) returning *",
    [s, question]
  );
  return inserted.rows[0];
}

export async function listSpaces() {
  const r = await db.query(
    `select s.*, (select count(*) from node n where n.space_id = s.id)::int as node_count
       from space s order by s.created_at asc`
  );
  return r.rows;
}

export async function insertNode({
  spaceId,
  parentId,
  kind,
  authorAccount,
  publishedText,
  originalText,
  transcript,
}) {
  const r = await db.query(
    `insert into node
       (space_id, parent_id, kind, author_account, published_text, original_text, transcript)
     values ($1, $2, $3, $4, $5, $6, $7)
     returning *`,
    [
      spaceId,
      parentId || null,
      kind,
      authorAccount || "anon",
      publishedText,
      originalText,
      transcript ? JSON.stringify(transcript) : null,
    ]
  );
  return r.rows[0];
}

// Whole tree for a space as flat rows with vote tallies. The client nests them.
export async function getTree(spaceId) {
  const r = await db.query(
    `select n.id, n.parent_id, n.kind, n.author_account,
            n.published_text, n.original_text, n.created_at,
            coalesce(sum(v.value), 0)::int as score,
            count(v.*)::int as vote_count
       from node n
       left join vote v on v.node_id = n.id
      where n.space_id = $1
      group by n.id
      order by n.created_at asc`,
    [spaceId]
  );
  return r.rows;
}

export async function castVote(nodeId, account, value) {
  await db.query(
    `insert into vote (node_id, account, value) values ($1, $2, $3)
       on conflict (node_id, account) do update set value = excluded.value`,
    [nodeId, account, value]
  );
}
