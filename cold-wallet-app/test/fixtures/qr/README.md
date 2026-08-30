# Cold signing QR fixtures

Test payloads for the cold wallet and the Keystone firmware. Each case is a real signing
request: a call plus its signed extensions, wrapped in the `{"v":1,"signer":..,"payload":..}`
envelope and UR-encoded into QR frames. That is exactly what a cold wallet scans.

## Layout

```
reduced/
  index.html                  pick a case, then show it to a camera or the simulator
  manifest.json               every case, what it is, and what a wallet must display
  <case>/
    index.html                animated QR for this case (arrow keys change speed)
    frames/frame-NNN.svg      one SVG per UR frame
    ur.txt                    the UR parts as text
    payload.hex               the signing payload
    request.json              the envelope before UR encoding
```

## Sets

- `reduced/` — the calls the Keystone firmware parses today. Small enough to scan on real
  hardware. This is the set to run on the device.
- A full set covering every cold wallet call can be added later. It is not here yet because
  large calls take a lot of QR frames (see below).

## Frame counts

The payload is hex encoded inside JSON, so the QR data is roughly twice the payload size.
UR splits it into 200 byte fragments. A simple transfer is 118 bytes and still needs 2
frames. A chain maximum 10 KiB call would need about 100 frames, which is not practical to
scan. Keep test calls small.

## Regenerating

```
cd ../quantus-cli
cargo run --example generate_qr_fixtures -- ../quantus-apps/cold-wallet-app/test/fixtures/qr
```

The generator encodes calls through the CLI's bundled chain metadata, so the bytes match
what the chain accepts. Regenerate after a runtime upgrade.
