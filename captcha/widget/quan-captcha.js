// Quantus Captcha widget.
//
// Usage:
//   <div class="quan-captcha" data-endpoint="https://pool.example.com"></div>
//   <script src="/widget/quan-captcha.js" defer></script>
//
// On solve, a hidden input named "quan-captcha-token" is added to the widget's
// enclosing form (or the widget element itself), and a "quan-captcha-solved"
// CustomEvent (detail: { token }) is dispatched on the widget element.
// The site backend then redeems the token: POST {endpoint}/siteverify
// with JSON {"secret": "...", "response": "<token>"}.

(function () {
  "use strict";

  const WIDGET_CLASS = "quan-captcha";

  const STYLE = `
    .quan-captcha-box {
      display: inline-flex; align-items: center; gap: 10px;
      border: 1px solid #d0d5dd; border-radius: 8px; padding: 10px 14px;
      font: 14px/1.4 system-ui, -apple-system, sans-serif; color: #1f2937;
      background: #fff; min-width: 260px; user-select: none;
    }
    .quan-captcha-check {
      width: 22px; height: 22px; border: 2px solid #98a2b3; border-radius: 5px;
      display: inline-flex; align-items: center; justify-content: center;
      cursor: pointer; flex: none; background: #fff; transition: border-color .15s;
    }
    .quan-captcha-box[data-state="idle"] .quan-captcha-check:hover { border-color: #2563eb; }
    .quan-captcha-box[data-state="solving"] .quan-captcha-check {
      border-color: #2563eb; border-top-color: transparent; border-radius: 50%;
      animation: quan-captcha-spin .8s linear infinite;
    }
    .quan-captcha-box[data-state="solved"] .quan-captcha-check {
      border-color: #16a34a; background: #16a34a; color: #fff; cursor: default;
    }
    .quan-captcha-box[data-state="error"] .quan-captcha-check { border-color: #dc2626; }
    .quan-captcha-label { flex: 1; }
    .quan-captcha-sub { display: block; font-size: 11px; color: #667085; margin-top: 1px; }
    @keyframes quan-captcha-spin { to { transform: rotate(360deg); } }
  `;

  function injectStyle() {
    if (document.getElementById("quan-captcha-style")) return;
    const style = document.createElement("style");
    style.id = "quan-captcha-style";
    style.textContent = STYLE;
    document.head.appendChild(style);
  }

  function formatHashrate(h) {
    if (h >= 1e6) return (h / 1e6).toFixed(1) + " MH/s";
    if (h >= 1e3) return (h / 1e3).toFixed(1) + " kH/s";
    return h.toFixed(0) + " H/s";
  }

  function initWidget(el) {
    if (el.dataset.quanCaptchaInit) return;
    el.dataset.quanCaptchaInit = "1";

    const endpoint = (el.dataset.endpoint || "").replace(/\/$/, "");
    const workerUrl = el.dataset.workerUrl || endpoint + "/widget/solver-worker.js";
    const wasmUrl = el.dataset.wasmUrl || endpoint + "/dist/solver_wasm.wasm";

    const box = document.createElement("div");
    box.className = "quan-captcha-box";
    box.dataset.state = "idle";
    box.innerHTML =
      '<span class="quan-captcha-check" role="checkbox" aria-checked="false" tabindex="0"></span>' +
      '<span class="quan-captcha-label">I\'m not a spammer' +
      '<span class="quan-captcha-sub">Quantus proof-of-work &middot; no tracking, no puzzles</span>' +
      "</span>";
    el.appendChild(box);

    const check = box.querySelector(".quan-captcha-check");
    const sub = box.querySelector(".quan-captcha-sub");
    let worker = null;
    const startedAt = { t: 0 };

    function setState(state, subText) {
      box.dataset.state = state;
      check.setAttribute("aria-checked", state === "solved" ? "true" : "false");
      // Own the mark in both directions so error/retry states never keep a
      // stale checkmark from a previous solved transition.
      check.textContent = state === "solved" ? "\u2713" : "";
      if (subText) sub.textContent = subText;
    }

    function fail(message) {
      if (worker) { worker.terminate(); worker = null; }
      setState("error", message + " — click to retry");
    }

    async function start() {
      if (box.dataset.state === "solving" || box.dataset.state === "solved") return;
      setState("solving", "requesting challenge…");
      try {
        const res = await fetch(endpoint + "/api/session", { method: "POST" });
        if (!res.ok) throw new Error("challenge unavailable (" + res.status + ")");
        const session = await res.json();

        setState("solving", "computing (~" + session.expected_hashes + " hashes)…");
        startedAt.t = performance.now();

        worker = new Worker(workerUrl);
        worker.onerror = () => fail("solver failed to load");
        worker.onmessage = async (e) => {
          const msg = e.data;
          if (msg.type === "progress") {
            const secs = (performance.now() - startedAt.t) / 1000;
            sub.textContent = "computing… " + formatHashrate(msg.hashes / Math.max(secs, 0.001));
          } else if (msg.type === "error") {
            fail(msg.message);
          } else if (msg.type === "found") {
            worker.terminate();
            worker = null;
            try {
              const shareRes = await fetch(endpoint + "/api/share", {
                method: "POST",
                headers: { "content-type": "application/json" },
                body: JSON.stringify({ session_id: session.session_id, nonce: msg.nonce }),
              });
              const share = await shareRes.json();
              if (!share.success) throw new Error(share.error || "share rejected");

              // Do all fallible tail work BEFORE showing the solved state, so
              // a throw here lands in fail() without leaving solved visuals.
              const form = el.closest("form") || el;
              let input = form.querySelector('input[name="quan-captcha-token"]');
              if (!input) {
                input = document.createElement("input");
                input.type = "hidden";
                input.name = "quan-captcha-token";
                form.appendChild(input);
              }
              input.value = share.token;

              const secs = ((performance.now() - startedAt.t) / 1000).toFixed(1);
              setState("solved", "verified in " + secs + "s (" + msg.hashes + " hashes)" +
                (share.block_found ? " — BLOCK FOUND!" : ""));

              el.dispatchEvent(new CustomEvent("quan-captcha-solved", {
                bubbles: true,
                detail: { token: share.token, blockFound: !!share.block_found },
              }));
            } catch (err) {
              fail(String(err.message || err));
            }
          }
        };
        worker.postMessage({
          wasmUrl: wasmUrl,
          headerHash: session.header_hash,
          nonceStart: session.nonce_start,
          shareTarget: session.share_target,
        });
      } catch (err) {
        fail(String(err.message || err));
      }
    }

    check.addEventListener("click", start);
    check.addEventListener("keydown", (e) => {
      if (e.key === " " || e.key === "Enter") { e.preventDefault(); start(); }
    });
  }

  function initAll() {
    injectStyle();
    document.querySelectorAll("." + WIDGET_CLASS).forEach(initWidget);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initAll);
  } else {
    initAll();
  }
})();
