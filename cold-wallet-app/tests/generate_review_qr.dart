import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_cold_wallet/components/scheme_picker.dart';
import 'package:quantus_cold_wallet/debug/debug_near_payloads.dart';
import 'package:quantus_cold_wallet/debug/debug_payloads.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
// ignore: implementation_imports — QuantusSdk.init also opens device storage, which a test host does not have.
import 'package:quantus_sdk/src/rust/frb_generated.dart';
// ignore: implementation_imports — the generated corpus is test/debug data, deliberately not public SDK API.
import 'package:quantus_sdk/src/testing/call_corpus.dart';

/// Writes the demo account's README, a static QR code per debug catalogue
/// request addressed to it (every call the wallet reviews, every one it must
/// refuse, and the NEAR samples), and the HTML that generate.sh prints to the
/// PDFs. Run through generate.sh, which points the Rust bridge at the SDK's
/// library.

/// Public on purpose so App Review can import it. Never fund this account.
const _mnemonic =
    'dismiss decline gasp pulse orchard distance isolate inflict derive tiger glad used '
    'humor quarter capital clinic ride hour host purity night steel transfer proud';

/// The calls app-review.pdf carries, by pallet and debug catalogue label.
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

typedef _Account = ({ColdAccount account, Keypair keypair, String checkphrase});

/// A request as the static QR frames it is printed in.
abstract class _Code {
  final String file;
  final List<String> parts;

  _Code(this.file, this.parts);

  /// What the wallet shows for it, one README line each.
  List<String> get notes;

  String partFile(int index) => parts.length == 1 ? '$file.png' : '$file-part${index + 1}of${parts.length}.png';

  String get files => parts.length == 1 ? '$file.png' : '$file-part*.png';
}

class _Request extends _Code {
  final DebugCall call;
  final ParsedPayload parsed;

  _Request(this.call, super.file, super.parts, this.parsed);

  (String, String) get key => (call.pallet, call.label);

  String get headline {
    final summary = parsed.call.summary;
    if (summary == null) return parsed.call.actionTitle;
    return '${parsed.call.actionTitle} ${NumberFormattingService().formatAmount(summary.amount)} '
        '${AppConstants.tokenSymbol}';
  }

  String? get recipient => parsed.call.summary?.recipient;

  /// [DecodedCall.displayTitleChain] with runs of one call counted, so a
  /// batch of sixteen transfers stays one line.
  String get chain {
    final runs = <(String, int)>[];
    for (final title in parsed.call.displayTitleChain.split(' → ')) {
      if (runs.isNotEmpty && runs.last.$1 == title) {
        runs.last = (title, runs.last.$2 + 1);
      } else {
        runs.add((title, 1));
      }
    }
    return [for (final (title, count) in runs) count == 1 ? title : '$count × $title'].join(' → ');
  }

  @override
  List<String> get notes => ['$headline${recipient == null ? '' : ' to $recipient'}', chain];
}

class _Sample extends _Code {
  @override
  final List<String> notes;

  _Sample(super.file, super.parts, this.notes);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes the demo account and its signing request QR codes', () async {
    await RustLib.init();
    setDefaultSs58Prefix(prefix: 189);
    final htmlDir = Platform.environment['HTML_DIR'];
    if (htmlDir == null) throw StateError('HTML_DIR is not set; run tests/generate.sh');

    final demo = await _derive(ColdAccount(label: 'Main key', index: 0, scheme: ColdAccount.newAccountScheme));
    final near = await _derive(ColdAccount(label: 'Account 2', index: 0, scheme: DilithiumScheme.mlDsa65));
    final signer = demo.keypair.ss58Address;

    final requests = [
      for (final (i, call) in DebugPayloads.byPallet.values.expand((calls) => calls).indexed)
        _valid(signer, call, _file(i, '${call.pallet} ${call.label}')),
    ];
    final seen = <String>{};
    final refused = [
      for (final (i, call) in [
        ...DebugPayloads.refused,
        ...DebugPayloads.invalidQrData,
        ...refusedCallCorpus.entries.map(DebugPayloads.fromCorpus),
      ].where((call) => seen.add('${call.signer} ${hex.encode(call.call)}')).indexed)
        _refused(signer, call, 'refused/${_file(i, '${call.pallet} ${call.label}')}'),
    ];
    final nearRequests = [
      for (final (i, call) in DebugNearPayloads.samples(near.keypair.publicKey).indexed)
        _near(near.keypair.publicKey, call, 'near/${_file(i, call.label)}'),
    ];

    final qrDir = Directory('${_dir.path}/qr');
    if (qrDir.existsSync()) qrDir.deleteSync(recursive: true);
    for (final code in [...requests, ...refused, ...nearRequests]) {
      for (final (index, part) in code.parts.indexed) {
        (File('${qrDir.path}/${code.partFile(index)}')..createSync(recursive: true)).writeAsBytesSync(await _png(part));
      }
    }
    final review = [for (final key in _reviewCalls) requests.firstWhere((r) => r.key == key)];

    File('${_dir.path}/README.txt').writeAsStringSync(_readme(demo, near, requests, review, refused, nearRequests));
    File(
      '$htmlDir/app-review.html',
    ).writeAsStringSync(_html('App Review demo', signer, demo.checkphrase, review, qrDir));
    File('$htmlDir/all-calls.html').writeAsStringSync(_html('every call', signer, demo.checkphrase, requests, qrDir));
  });
}

Future<_Account> _derive(ColdAccount account) async {
  final keypair = HdWalletService().keyPairAtPath(_mnemonic, account.derivationPath, account.scheme);
  final checkphrase = await HumanReadableChecksumService().getHumanReadableName(keypair.ss58Address);
  if (checkphrase == null) throw StateError('No checkphrase for ${keypair.ss58Address}');
  return (account: account, keypair: keypair, checkphrase: checkphrase);
}

/// [request] as static QR frames, and what the scanner reads back from them.
(List<String>, AnySigningRequest) _frames(Uint8List request) {
  final parts = encodeUrForQr(data: request, maxFragmentLength: maxUrScanPartChars);
  return (parts, AnySigningRequest.decode(Uint8List.fromList(decodeUr(urParts: parts))));
}

/// The request [call] makes of [signer] in static QR frames, checked to
/// decode back to exactly that request.
(List<String>, SigningRequest) _quantusFrames(String signer, DebugCall call, String file) {
  final (parts, request) = _frames(
    SigningRequest(signer: signer, payload: DebugPayloads.payloadForCall(call.call)).encode(),
  );
  if (request is! SigningRequest || request.signer != signer) throw StateError('$file does not decode for $signer');
  return (parts, request);
}

_Request _valid(String signer, DebugCall call, String file) {
  final (parts, request) = _quantusFrames(signer, call, file);
  return _Request(
    call,
    file,
    parts,
    QuantusPayloadParser.parsePayload(request.payload, policy: const FullCallPolicy()),
  );
}

/// A request the wallet holding [signer] must refuse, with the reason its
/// review screen gives.
_Sample _refused(String signer, DebugCall call, String file) {
  final (parts, request) = _quantusFrames(call.signer ?? signer, call, file);
  final label = '${call.pallet} · ${call.label}';
  if (request.signer != signer) return _Sample(file, parts, [label, 'Refused: account not in this wallet']);
  try {
    QuantusPayloadParser.parsePayload(request.payload, policy: const FullCallPolicy());
  } on FormatException catch (e) {
    return _Sample(file, parts, [label, 'Refused: ${e.message}']);
  }
  throw StateError('$file parses, but the wallet must refuse it');
}

/// A NEAR request, and what the wallet holding the ML-DSA-65 [key] does with it.
_Sample _near(Uint8List key, DebugNearCall call, String file) {
  final (parts, request) = _frames(call.request.encode());
  if (request is! NearSigningRequest || !listEquals(request.transaction, call.request.transaction)) {
    throw StateError('$file does not decode to its transaction');
  }
  final tx = decodeNearTransaction(transaction: request.transaction);
  return _Sample(file, parts, [
    call.label,
    !tx.signsWithMlDsa65
        ? 'Refused: not a Quantus key'
        : listEquals(tx.publicKeyBytes, key)
        ? 'Signs with the ML-DSA-65 account'
        : 'Refused: key not in this wallet',
  ]);
}

String _file(int index, String label) => '${'${index + 1}'.padLeft(2, '0')}-${_slug(label)}';

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

String _accountLines(_Account a) =>
    '''
Signature scheme:  ${schemeLabel(a.account.scheme)}
Derivation path:   ${a.account.derivationPath}
Address:           ${a.keypair.ss58Address}
Checkphrase:       ${a.checkphrase}''';

String _list(List<_Code> codes, [Set<_Code> starred = const {}]) => [
  for (final c in codes) '${starred.contains(c) ? '*' : ' '} ${c.files}\n${c.notes.map((n) => '      $n').join('\n')}',
].join('\n');

String _readme(
  _Account demo,
  _Account near,
  List<_Request> requests,
  List<_Request> review,
  List<_Code> refused,
  List<_Code> nearRequests,
) {
  final words = [for (final (i, w) in _words.indexed) '${'${i + 1}'.padLeft(2)}. ${w.padRight(10)}'];
  return '''
Quantus Cold Wallet: demo account and test QR codes
===================================================

A demo account for the Quantus Cold Wallet and signing requests addressed to
it, for App Store review and manual testing:

  qr/          every call the wallet can review
  qr/refused/  requests the wallet must refuse: calls it cannot show in full,
               the payloads from past audit reports, an account it does not
               hold
  qr/near/     NEAR transactions, for the ML-DSA-65 account further down

app-review.pdf is the document for Apple: the import steps below and the ten
codes marked * in the list at the end. all-calls.pdf has the same steps and
every code in qr/ itself. The refused and NEAR codes are images only.

The recovery phrase is public. Never send funds to this account.

Recovery phrase (24 words)
--------------------------
${[for (var i = 0; i < words.length; i += 4) words.sublist(i, i + 4).join(' ').trimRight()].join('\n')}

$_mnemonic

Account
-------
${_accountLines(demo)}

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

A code in qr/refused/ opens a screen saying why the wallet will not sign it,
with the reason listed below.

The requests are for the Planck test network and are never broadcast.

NEAR account
------------
The codes in qr/near/ are NEAR testnet transactions, which only an ML-DSA-65
key signs. Add one from the same phrase: tap the Q at the top left, then
Manage accounts, Add Account. Open Advanced, choose ML-DSA-65 under Signature
type, check the index reads 0, and tap Create Account.

${_accountLines(near)}

QR codes
--------
qr/ (* = in app-review.pdf)
${_list(requests, review.toSet())}

qr/refused/
${_list(refused)}

qr/near/
${_list(nearRequests)}

Regenerate
----------
Build the SDK's Rust library once (quantus_sdk/test/build_library.sh), then
run cold-wallet-app/tests/generate.sh. The calls and the phrase are set in
generate_review_qr.dart.
''';
}

String _html(String subject, String signer, String checkphrase, List<_Request> requests, Directory qrDir) {
  const esc = HtmlEscape();
  final title = 'Quantus Cold Wallet: $subject';
  String img(String file) => 'data:image/png;base64,${base64Encode(File('${qrDir.path}/$file').readAsBytesSync())}';
  final words = [for (final (i, w) in _words.indexed) '<li><span>${i + 1}</span>${esc.convert(w)}</li>'].join();
  final codes = [
    for (final (i, r) in requests.indexed)
      for (var p = 0; p < r.parts.length; p++)
        '''
<section class="code">
  <h2>${i + 1}. ${esc.convert(r.headline)}${r.parts.length == 1 ? '' : ' <small>part ${p + 1} of ${r.parts.length}</small>'}</h2>
  <p>${r.recipient == null ? '' : 'To ${esc.convert(r.recipient!)}<br>'}${esc.convert(r.chain)}</p>
  <img src="${img(r.partFile(p))}">
</section>''',
  ].join();

  return '''
<!doctype html>
<html><head><meta charset="utf-8"><title>$title</title>
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
<h1>$title</h1>
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
<li>Point the camera at any QR code on the following pages, on screen or printed.${requests.any((r) => r.parts.length > 1) ? ' A transaction marked "part 1 of 2" is in two codes: scan both, one after the other.' : ''}</li>
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
