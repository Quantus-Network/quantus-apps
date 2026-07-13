// Steelman-loop spike server. Throwaway code; the prompts are the artifact.
//
//   node server.mjs                         # stub model (offline, tests the flow)
//   ANTHROPIC_API_KEY=... node server.mjs
//   OPENAI_API_KEY=...    node server.mjs
//   OPENROUTER_API_KEY=... OPENROUTER_MODEL=anthropic/claude-sonnet-4 node server.mjs
//
// Zero dependencies; serves index.html and POST /api/steelman.

import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import { SYSTEM_PROMPT, buildFirstRoundPrompt, buildRevisionPrompt } from "./prompts.mjs";
import {
  initDb,
  getOrCreateSpace,
  listSpaces,
  insertNode,
  getTree,
  getChildren,
  castVote,
} from "./db.mjs";

const PORT = process.env.PORT || 8788;
const DIR = dirname(fileURLToPath(import.meta.url));

const ANTHROPIC_KEY = process.env.ANTHROPIC_API_KEY;
const OPENAI_KEY = process.env.OPENAI_API_KEY;
const OPENROUTER_KEY = process.env.OPENROUTER_API_KEY;
const ANTHROPIC_MODEL = process.env.ANTHROPIC_MODEL || "claude-sonnet-4-5";
const OPENAI_MODEL = process.env.OPENAI_MODEL || "gpt-5.2";
const OPENROUTER_MODEL = process.env.OPENROUTER_MODEL || "anthropic/claude-sonnet-4";
const OPENROUTER_REFERER = process.env.OPENROUTER_REFERER || "http://localhost:8788";
const OPENROUTER_TITLE = process.env.OPENROUTER_TITLE || "Debate Tree steelman spike";

const provider = ANTHROPIC_KEY
  ? "anthropic"
  : OPENAI_KEY
    ? "openai"
    : OPENROUTER_KEY
      ? "openrouter"
      : "stub";
console.log(`model provider: ${provider}${provider === "openrouter" ? ` (${OPENROUTER_MODEL})` : ""}`);

async function callAnthropic(messages) {
  const res = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-api-key": ANTHROPIC_KEY,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: ANTHROPIC_MODEL,
      max_tokens: 1024,
      system: SYSTEM_PROMPT,
      messages,
    }),
  });
  if (!res.ok) throw new Error(`anthropic ${res.status}: ${await res.text()}`);
  const body = await res.json();
  return body.content.map((c) => c.text || "").join("");
}

async function callOpenAI(messages) {
  const res = await fetch("https://api.openai.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${OPENAI_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      messages: [{ role: "system", content: SYSTEM_PROMPT }, ...messages],
    }),
  });
  if (!res.ok) throw new Error(`openai ${res.status}: ${await res.text()}`);
  const body = await res.json();
  return body.choices[0].message.content;
}

// OpenRouter exposes an OpenAI-compatible chat API; handy for swapping models
// without changing provider code.
async function callOpenRouter(messages) {
  const res = await fetch("https://openrouter.ai/api/v1/chat/completions", {
    method: "POST",
    headers: {
      "content-type": "application/json",
      authorization: `Bearer ${OPENROUTER_KEY}`,
      "HTTP-Referer": OPENROUTER_REFERER,
      "X-Title": OPENROUTER_TITLE,
    },
    body: JSON.stringify({
      model: OPENROUTER_MODEL,
      messages: [{ role: "system", content: SYSTEM_PROMPT }, ...messages],
    }),
  });
  if (!res.ok) throw new Error(`openrouter ${res.status}: ${await res.text()}`);
  const body = await res.json();
  return body.choices[0].message.content;
}

// Offline stand-in: crude split on sentence boundaries + short prefix.
function callStub(messages) {
  const last = messages[messages.length - 1].content;
  const isRevision = /revision round/.test(last);

  if (isRevision) {
    const draft = (last.match(/Your previous draft[^]*?---\n([\s\S]*?)\n---/) || [, ""])[1].trim();
    return Promise.resolve(
      JSON.stringify({
        claims: [{ id: "1", label: "Revised", steelman: draft + " (revised per your feedback)", relevance: null }],
        notes: "- [stub model] echoed feedback",
        question: null,
      })
    );
  }

  const original = (last.match(/---\n([\s\S]*?)\n---/) || [, last])[1].trim();
  const sentences = original
    .split(/(?<=[.!?])\s+/)
    .map((s) =>
      s
        .replace(/\b(stupid|idiotic|insane|moronic|garbage|bullshit)\b/gi, "deeply flawed")
        .replace(/!+/g, ".")
        .trim()
    )
    .filter((s) => s.length > 20);

  // Crude relevance check: flag a claim that shares no substantive words with
  // the reply target (real models do this semantically; this tests the UI).
  const parentQuote = (last.match(/responding to this claim: "([\s\S]*?)"/) || [, ""])[1];
  // Stemmed word set: lowercase, letters only, first 6 chars — so that
  // "standardized" and "standardize" collide.
  const words = (t) =>
    new Set((t.toLowerCase().match(/[a-z][a-z-]{3,}/g) || []).map((w) => w.slice(0, 6)));
  const parentWords = words(parentQuote);
  const overlaps = (text) =>
    [...words(text)].some((w) => parentWords.has(w));

  // Crude duplicate check against the sibling list embedded in the prompt:
  // Jaccard similarity on stemmed words (real models judge this semantically).
  const siblings = [...last.matchAll(/^- \(id: ([0-9a-f-]+)\) (.+)$/gm)].map((m) => ({
    id: m[1],
    words: words(m[2]),
  }));
  const duplicateOf = (text) => {
    const w = words(text);
    for (const s of siblings) {
      const inter = [...w].filter((x) => s.words.has(x)).length;
      const union = new Set([...w, ...s.words]).size;
      if (union && inter / union > 0.4) return s.id;
    }
    return null;
  };

  const chunks = sentences.length >= 2 ? sentences.slice(0, 4) : [original];
  const claims = chunks.map((chunk, i) => ({
    id: String(i + 1),
    label: `Point ${i + 1}`,
    steelman: chunk.length > 120 ? chunk.slice(0, 117) + "…" : chunk,
    relevance:
      parentQuote && !overlaps(chunk)
        ? "This claim doesn't appear to engage the claim you're replying to — it may belong elsewhere in the tree."
        : null,
    duplicate_of: duplicateOf(chunk),
  }));

  return Promise.resolve(
    JSON.stringify({
      claims,
      notes:
        claims.length > 1
          ? `- [stub model] split into ${claims.length} claims\n- set an API key for real disentangling`
          : "- [stub model] single claim\n- set an API key for real steelmanning",
      question: null,
    })
  );
}

const callModel =
  provider === "anthropic"
    ? callAnthropic
    : provider === "openai"
      ? callOpenAI
      : provider === "openrouter"
        ? callOpenRouter
        : callStub;

function parseModelJson(text) {
  const cleaned = text.replace(/^```(?:json)?\s*/i, "").replace(/```\s*$/, "").trim();
  const parsed = JSON.parse(cleaned);

  let claims = parsed.claims;
  // Tolerate shapes a model tends to drift into, especially on revision:
  //   { steelman: "..." }        (old single-claim shape)
  //   { claim: { steelman } }    (singular key)
  //   { revised: "..." } | { text: "..." }
  if (!Array.isArray(claims)) {
    const single =
      (parsed.claim && typeof parsed.claim === "object" && parsed.claim) ||
      (typeof parsed.steelman === "string" && { steelman: parsed.steelman }) ||
      (typeof parsed.revised === "string" && { steelman: parsed.revised }) ||
      (typeof parsed.text === "string" && { steelman: parsed.text });
    if (single) {
      claims = [{ id: single.id ?? "1", label: single.label ?? "Main point", steelman: single.steelman }];
    }
  }
  if (!Array.isArray(claims) || claims.length === 0) {
    throw new Error("model reply missing claims");
  }
  claims = claims.map((c, i) => {
    if (typeof c.steelman !== "string" || !c.steelman.trim()) {
      throw new Error(`claim ${i + 1} missing steelman`);
    }
    const optionalStr = (v) =>
      typeof v === "string" && v.trim() && v.trim().toLowerCase() !== "null"
        ? v.trim()
        : null;
    return {
      id: String(c.id ?? i + 1),
      label: typeof c.label === "string" && c.label.trim() ? c.label.trim() : `Point ${i + 1}`,
      steelman: c.steelman.trim(),
      relevance: optionalStr(c.relevance),
      duplicate_of: optionalStr(c.duplicate_of),
    };
  });

  return {
    claims,
    notes: typeof parsed.notes === "string" ? parsed.notes : "",
    question: typeof parsed.question === "string" ? parsed.question : null,
  };
}

async function handleSteelman(req, res) {
  let raw = "";
  for await (const chunk of req) raw += chunk;
  const body = JSON.parse(raw);

  // Existing arguments at the target position, so the model can flag
  // duplicates before anything is published.
  let siblings = [];
  if (body.question) {
    const space = await getOrCreateSpace(body.question, body.spaceSlug);
    siblings = await getChildren(space.id, body.parentId || null);
  }

  // Rebuild the conversation from the client-held transcript. rounds is
  // [{draft, feedback}, ...] for completed rounds.
  const messages = [
    { role: "user", content: buildFirstRoundPrompt({ ...body, siblings }) },
  ];
  (body.rounds || []).forEach((r, i) => {
    messages.push({
      role: "assistant",
      content: JSON.stringify({
        claims: [{ id: r.claimId, label: r.claimLabel, steelman: r.draft }],
      }),
    });
    messages.push({
      role: "user",
      content: buildRevisionPrompt({
        original: body.original,
        claim: { id: r.claimId, label: r.claimLabel, steelman: r.draft },
        draft: r.draft,
        feedback: r.feedback,
        round: i + 1,
      }),
    });
  });

  const reply = await callModel(messages);
  const parsed = parseModelJson(reply);
  res.writeHead(200, { "content-type": "application/json" });
  res.end(JSON.stringify(parsed));
}

async function readBody(req) {
  let raw = "";
  for await (const chunk of req) raw += chunk;
  return raw ? JSON.parse(raw) : {};
}

function sendJson(res, status, obj) {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify(obj));
}

// GET /api/tree?space=<slug or question> — space row + flat node list.
async function handleTree(req, res, url) {
  const key = url.searchParams.get("space") || "";
  const question = url.searchParams.get("question") || key;
  const space = await getOrCreateSpace(question, /\s/.test(key) ? undefined : key);
  const nodes = await getTree(space.id);
  sendJson(res, 200, { space, nodes, provider });
}

async function handleSpaces(_req, res) {
  sendJson(res, 200, { spaces: await listSpaces() });
}

// POST /api/publish — persist an author-approved steelman as a tree node.
// parent_id null => 'answer' (direct to the question); otherwise pro/con by stance.
async function handlePublish(req, res) {
  const b = await readBody(req);
  if (!b.publishedText || !b.originalText || !b.question) {
    return sendJson(res, 400, { error: "question, publishedText, originalText required" });
  }
  const space = await getOrCreateSpace(b.question, b.spaceSlug);
  const kind = !b.parentId
    ? "answer"
    : /oppos|con/i.test(b.stance || "")
      ? "con"
      : "pro";
  const node = await insertNode({
    spaceId: space.id,
    parentId: b.parentId,
    kind,
    authorAccount: b.authorAccount,
    publishedText: b.publishedText,
    originalText: b.originalText,
    transcript: b.transcript,
  });
  sendJson(res, 200, { node, space });
}

async function handleVote(req, res) {
  const b = await readBody(req);
  if (!b.nodeId || ![1, -1].includes(b.value)) {
    return sendJson(res, 400, { error: "nodeId and value (1|-1) required" });
  }
  await castVote(b.nodeId, b.account || "anon", b.value);
  sendJson(res, 200, { ok: true });
}

const server = createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host}`);
    if (req.method === "POST" && url.pathname === "/api/steelman") {
      return await handleSteelman(req, res);
    }
    if (req.method === "POST" && url.pathname === "/api/publish") {
      return await handlePublish(req, res);
    }
    if (req.method === "POST" && url.pathname === "/api/vote") {
      return await handleVote(req, res);
    }
    if (req.method === "GET" && url.pathname === "/api/tree") {
      return await handleTree(req, res, url);
    }
    if (req.method === "GET" && url.pathname === "/api/spaces") {
      return await handleSpaces(req, res);
    }
    if (req.method === "GET" && (url.pathname === "/" || url.pathname === "/index.html")) {
      const html = await readFile(join(DIR, "index.html"));
      res.writeHead(200, { "content-type": "text/html; charset=utf-8" });
      return res.end(html);
    }
    res.writeHead(404);
    res.end("not found");
  } catch (err) {
    console.error(err);
    res.writeHead(500, { "content-type": "application/json" });
    res.end(JSON.stringify({ error: String(err.message || err) }));
  }
});

await initDb();
server.listen(PORT, () => console.log(`steelman spike: http://127.0.0.1:${PORT}/`));
