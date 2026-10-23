import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
// ignore: implementation_imports — QuantusSdk.init also opens device storage, which a test host does not have.
import 'package:quantus_sdk/src/rust/frb_generated.dart';

/// Writes the demo account's README, a static QR code per signing request
/// addressed to it, and the HTML that generate.sh prints to the App Review PDF.
/// Run through generate.sh, which points the Rust bridge at the SDK's library.

/// Public on purpose so App Review can import it. Never fund this account.
const _mnemonic =
    'dismiss decline gasp pulse orchard distance isolate inflict derive tiger glad used '
    'humor quarter capital clinic ride hour host purity night steel transfer proud';

/// The calls the App Review PDF carries, by pallet and debug catalogue label.
const _reviewCalls = [
  ('Balances', 'transfer_allow_death'),
  ('Balances', 'transfer_all'),
  ('ReversibleTransfers', 'schedule_transfer'),
  ('ReversibleTransfers', 'schedule_transfer_with_delay'),
  ('Utility', 'batch_all [two transfers]'),
  ('Multisig', 'propose [carrying a transfer]'),
  ('Multisig', 'approve [carrying a transfer]'),
  ('Multisig', 'execute [carrying a transfer]'),
  ('TechCollective', 'vote'),
  ('Vesting', 'claim'),
];

final _dir = Directory('tests');

class _Request {
  final String file;
  final ParsedPayload parsed;
  final List<String> parts;

  _Request(this.file, this.parsed, this.parts);

  String get headline {
    final summary = parsed.call.summary;
    if (summary == null) return parsed.call.actionTitle;
    return '${parsed.call.actionTitle} ${NumberFormattingService().formatAmount(summary.amount)} '
        '${AppConstants.tokenSymbol}';
  }

  String? get recipient => parsed.call.summary?.recipient;

  String partFile(int index) => parts.length == 1 ? '$file.png' : '$file-part${index + 1}of${parts.length}.png';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes the demo account and its signing request QR codes', () async {
    await RustLib.init();
    setDefaultSs58Prefix(prefix: 189);
    final htmlPath = Platform.environment['REVIEW_HTML'];
    if (htmlPath == null) throw StateError('REVIEW_HTML is not set; run tests/generate.sh');

    final account = ColdAccount(label: 'Main key', index: 0, scheme: ColdAccount.newAccountScheme);
    final signer = HdWalletService().keyPairAtPath(_mnemonic, account.derivationPath, account.scheme).ss58Address;
    final checkphrase = await HumanReadableChecksumService().getHumanReadableName(signer);
    if (checkphrase == null) throw StateError('No checkphrase for $signer');

    final qrDir = Directory('${_dir.path}/qr');
    if (qrDir.existsSync()) qrDir.deleteSync(recursive: true);
    qrDir.createSync();

    final requests = <_Request>[];
    for (final (i, (pallet, label)) in _reviewCalls.indexed) {
      final call = DebugPayloads.byPallet[pallet]?.where((c) => c.label == label).firstOrNull;
      if (call == null) throw StateError('No debug call $pallet $label');
      final request = _encode(signer, call, '${(i + 1).toString().padLeft(2, '0')}-${_slug('$pallet $label')}');
      for (final (index, part) in request.parts.indexed) {
        File('${qrDir.path}/${request.partFile(index)}').writeAsBytesSync(await _png(part));
      }
      requests.add(request);
    }

    File('${_dir.path}/README.txt').writeAsStringSync(_readme(account, signer, checkphrase, requests));
    File(htmlPath).writeAsStringSync(_html(signer, checkphrase, requests, qrDir));
  });
}

/// The request [call] makes of [signer], checked to decode back to exactly
/// what the wallet will show before any image is written.
_Request _encode(String signer, DebugCall call, String file) {
  final bytes = SigningRequest(signer: signer, payload: DebugPayloads.payloadForCall(call.call)).encode();
  final parts = encodeUrForQr(data: bytes, maxFragmentLength: maxUrScanPartChars);
  final decoded = AnySigningRequest.decode(Uint8List.fromList(decodeUr(urParts: parts)));
  if (decoded is! SigningRequest || decoded.signer != signer) throw StateError('$file does not decode for $signer');
  return _Request(file, QuantusPayloadParser.parsePayload(decoded.payload, policy: const FullCallPolicy()), parts);
}

String _slug(String text) => text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]+'), '-').replaceAll(RegExp(r'-$'), '');

/// [data] as a black-on-white QR with a four-module quiet zone, at the error
/// correction [encodeUrForQr] sizes its frames for.
Future<Uint8List> _png(String data) async {
  const module = 10.0;
  const quiet = 4;
  final qr = QrImage(QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L));
  final side = (qr.moduleCount + 2 * quiet) * module;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder)
    ..drawRect(ui.Rect.fromLTWH(0, 0, side, side), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  final dark = ui.Paint()..color = const ui.Color(0xFF000000);
  for (var row = 0; row < qr.moduleCount; row++) {
    for (var col = 0; col < qr.moduleCount; col++) {
      if (!qr.isDark(row, col)) continue;
      canvas.drawRect(ui.Rect.fromLTWH((col + quiet) * module, (row + quiet) * module, module, module), dark);
    }
  }
  final image = await recorder.endRecording().toImage(side.toInt(), side.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  if (png == null) throw StateError('Could not encode the QR image for $data');
  return png.buffer.asUint8List();
}

List<String> get _words => _mnemonic.split(' ');

String _readme(ColdAccount account, String signer, String checkphrase, List<_Request> requests) {
  final words = [for (final (i, w) in _words.indexed) '${'${i + 1}'.padLeft(2)}. ${w.padRight(10)}'];
  return '''
Quantus Cold Wallet: demo account and test QR codes
===================================================

A demo account for the Quantus Cold Wallet and signing requests addressed to
it, for App Store review and manual testing. app-review.pdf is the document
for Apple: the import steps below and every QR code in qr/.

The recovery phrase is public. Never send funds to this account.

Recovery phrase (24 words)
--------------------------
${[for (var i = 0; i < words.length; i += 4) words.sublist(i, i + 4).join(' ').trimRight()].join('\n')}

$_mnemonic

Account
-------
Signature scheme:  ML-DSA-87
Derivation path:   ${account.derivationPath}
Address:           $signer
Checkphrase:       $checkphrase

Import the account
------------------
1. Switch Wi-Fi, cellular and Bluetooth off (Airplane Mode, then check Wi-Fi
   and Bluetooth in Settings). The wallet does not create, import or unlock
   a key while the phone reports any connection. For testing only, the
   "Override for Testing" button on that screen lifts the lock.
2. Tap Import Key, type the 24 words separated by spaces, tap Import Key.
   Leave Advanced untouched: it already selects ML-DSA-87, account 0.
3. Tap Enable Face ID or Use Passcode only, then Go To Wallet.
4. The wallet shows the address and checkphrase above.

Sign a request
--------------
Tap Scan Transaction and point the camera at a code in qr/. A request too
large for one code has one image per part; scan the parts one after the
other. Check the review screen, tap Approve and Sign, and the wallet shows the
signature as a QR code for the hot wallet to scan. Tap Done.

The requests are for the Planck test network and are never broadcast.

QR codes
--------
${[for (final r in requests) '${r.parts.length == 1 ? '${r.file}.png' : '${r.file}-part*.png'}\n    ${r.headline}${r.recipient == null ? '' : ' to ${r.recipient}'}\n    ${r.parsed.call.displayTitleChain}'].join('\n')}

Regenerate
----------
Build the SDK's Rust library once (quantus_sdk/test/build_library.sh), then
run cold-wallet-app/tests/generate.sh. The calls and the phrase are set in
generate_review_qr.dart.
''';
}

String _html(String signer, String checkphrase, List<_Request> requests, Directory qrDir) {
  const esc = HtmlEscape();
  String img(String file) => 'data:image/png;base64,${base64Encode(File('${qrDir.path}/$file').readAsBytesSync())}';
  final words = [for (final (i, w) in _words.indexed) '<li><span>${i + 1}</span>${esc.convert(w)}</li>'].join();
  final codes = [
    for (final (i, r) in requests.indexed)
      for (var p = 0; p < r.parts.length; p++)
        '''
<section class="code">
  <h2>${i + 1}. ${esc.convert(r.headline)}${r.parts.length == 1 ? '' : ' <small>part ${p + 1} of ${r.parts.length}</small>'}</h2>
  <p>${r.recipient == null ? '' : 'To ${esc.convert(r.recipient!)}<br>'}${esc.convert(r.parsed.call.displayTitleChain)}</p>
  <img src="${img(r.partFile(p))}">
</section>''',
  ].join();

  return '''
<!doctype html>
<html><head><meta charset="utf-8"><title>Quantus Cold Wallet: App Review demo</title>
<style>
@page { size: Letter; margin: 16mm; }
body { font: 11pt/1.45 -apple-system, Helvetica, Arial, sans-serif; color: #111; }
h1 { font-size: 20pt; margin: 0 0 4mm; }
h2 { font-size: 13pt; margin: 0 0 1mm; }
h2 small { font-weight: normal; color: #555; }
ol.steps li { margin-bottom: 2mm; }
ol.words { columns: 4; list-style: none; padding: 3mm 4mm; border: 1px solid #ccc; border-radius: 2mm;
  font: 11pt/1.8 Menlo, monospace; }
ol.words span { display: inline-block; width: 7mm; color: #888; }
.mono { font-family: Menlo, monospace; word-break: break-all; }
.note { color: #555; font-size: 10pt; }
.code { break-inside: avoid; text-align: center; padding-top: 6mm; }
.code p { margin: 0 0 2mm; font-size: 9.5pt; color: #444; font-family: Menlo, monospace; word-break: break-all; }
.code img { width: 92mm; height: 92mm; image-rendering: pixelated; }
.codes { break-before: page; }
</style></head><body>
<h1>Quantus Cold Wallet: App Review demo</h1>
<p>Quantus Cold Wallet is an offline signer. It holds a key, reads a transaction from a QR code shown by the
Quantus hot wallet, shows what is about to be signed, and returns the signature as a QR code. It never sends
anything over a network. This document has a demo key and ${requests.length} transactions to sign with it.</p>

<h2>1. Go offline</h2>
<p>The wallet does not create, import or unlock a key while the phone reports any connection. Turn on Airplane
Mode, then make sure Wi-Fi and Bluetooth are off as well. For a quick test the <b>Override for Testing</b> button
on the "Network Detected" screen lifts this lock.</p>

<h2>2. Import the demo key</h2>
<ol class="steps">
<li>Tap <b>Import Key</b>, type the 24 words below separated by spaces, and tap <b>Import Key</b>.</li>
<li>Tap <b>Enable Face ID</b> or <b>Use Passcode only</b>, then <b>Go To Wallet</b>.</li>
<li>The wallet shows this account:<br><span class="mono">$signer</span><br>checkphrase <b>${esc.convert(checkphrase)}</b></li>
</ol>
<ol class="words">$words</ol>

<h2>3. Sign a transaction</h2>
<ol class="steps">
<li>Tap <b>Scan Transaction</b> and allow camera access.</li>
<li>Point the camera at any QR code on the following pages, on screen or printed.</li>
<li>The review screen shows the transaction in the heading of its code. Tap <b>Approve and Sign</b> and confirm
with Face ID or the passcode.</li>
<li>The signature appears as a QR code, which the hot wallet would scan to submit the transaction. Tap <b>Done</b>.
<b>Cancel Transaction</b> rejects a request instead.</li>
</ol>
<p class="note">The demo account holds no funds and the transactions are for the Planck test network. Nothing is
broadcast: the cold wallet has no network access, and only the hot wallet can submit a signed transaction.</p>

<div class="codes">$codes</div>
</body></html>
''';
}
