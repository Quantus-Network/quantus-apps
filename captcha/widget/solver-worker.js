// Web Worker: loads the WASM solver and grinds nonces in chunks, reporting
// progress so the widget can animate. Terminated by the main thread when done.

const CHUNK_ITERS = 2048;

// I/O buffer layout inside the WASM module (see solver-wasm/src/lib.rs)
const HEADER_OFF = 0;
const NONCE_OFF = 32;
const TARGET_OFF = 96;
const IO_SIZE = 224;

function hexToBytes(hex, length) {
  const clean = hex.replace(/^0x/, "").padStart(length * 2, "0");
  const bytes = new Uint8Array(length);
  for (let i = 0; i < length; i++) {
    bytes[i] = parseInt(clean.slice(i * 2, i * 2 + 2), 16);
  }
  return bytes;
}

function bytesToHex(bytes) {
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

self.onmessage = async (e) => {
  const { wasmUrl, headerHash, nonceStart, shareTarget } = e.data;
  try {
    const response = await fetch(wasmUrl);
    if (!response.ok) throw new Error(`failed to fetch solver wasm: ${response.status}`);
    const { instance } = await WebAssembly.instantiate(await response.arrayBuffer(), {});
    const { io_ptr, io_len, solve, memory } = instance.exports;

    if (io_len() !== IO_SIZE) throw new Error("solver wasm I/O layout mismatch");
    const ioBase = io_ptr();
    const io = () => new Uint8Array(memory.buffer, ioBase, IO_SIZE);

    io().set(hexToBytes(headerHash, 32), HEADER_OFF);
    io().set(hexToBytes(nonceStart, 64), NONCE_OFF);
    io().set(hexToBytes(shareTarget, 64), TARGET_OFF);

    let hashes = 0;
    for (;;) {
      const found = solve(CHUNK_ITERS);
      hashes += CHUNK_ITERS;
      if (found === 1) {
        const nonce = bytesToHex(io().slice(NONCE_OFF, NONCE_OFF + 64));
        self.postMessage({ type: "found", nonce, hashes });
        return;
      }
      self.postMessage({ type: "progress", hashes });
    }
  } catch (err) {
    self.postMessage({ type: "error", message: String(err && err.message ? err.message : err) });
  }
};
