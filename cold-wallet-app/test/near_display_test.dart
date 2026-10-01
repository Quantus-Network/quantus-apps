import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/debug/debug_near_payloads.dart';
import 'package:quantus_cold_wallet/services/near_display.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

NearTransaction _tx({
  String signer = 'alice.testnet',
  String receiver = 'bob.testnet',
  List<NearAction> actions = const [],
}) => NearTransaction(
  signerId: signer,
  publicKey: 'ml-dsa-65:abc',
  publicKeyBytes: Uint8List(1952),
  signsWithMlDsa65: true,
  nonce: BigInt.from(42),
  receiverId: receiver,
  blockHash: '3KLgJ',
  hash: Uint8List(32),
  actions: actions,
);

NearAction _action(NearActionKind kind, {bool fullAccess = false}) =>
    NearAction(kind: kind, fullAccess: fullAccess, methodNames: const []);

void main() {
  final near = BigInt.from(10).pow(24);

  group('NearDisplay.formatNear', () {
    test('keeps every significant decimal and drops trailing zeros', () {
      expect(NearDisplay.formatNear(near), '1');
      expect(NearDisplay.formatNear(near * BigInt.from(15) ~/ BigInt.from(10)), '1.5');
      expect(NearDisplay.formatNear(BigInt.one), '0.000000000000000000000001');
      expect(NearDisplay.formatNear(BigInt.zero), '0');
      expect(NearDisplay.formatNear(near * BigInt.from(1000000) + BigInt.from(10).pow(23)), '1000000.1');
    });
  });

  test('formatGas shows whole Tgas, otherwise raw gas', () {
    expect(NearDisplay.formatGas(BigInt.from(30) * BigInt.from(10).pow(12)), '30 Tgas');
    expect(NearDisplay.formatGas(BigInt.from(1234)), '1234 gas');
  });

  test('argsText pretty-prints JSON and falls back to hex', () {
    expect(NearDisplay.argsText(Uint8List.fromList(utf8.encode('{"a":1}'))), '{\n  "a": 1\n}');
    expect(NearDisplay.argsText(Uint8List.fromList([0xff, 0x01])), '0xff01');
    expect(NearDisplay.argsText(Uint8List(0)), '(none)');
  });

  test('text that could reorder or hide what is shown falls back to hex', () {
    expect(NearDisplay.safeText('ft_transfer'), 'ft_transfer');
    expect(NearDisplay.safeText('a\u202Eb'), '0x61e280ae62');
    expect(NearDisplay.safeText('a\u200Bb'), '0x61e2808b62');
    expect(NearDisplay.safeText('a\x1bb'), '0x611b62');
    // JSON strings carrying a bidi override are shown as the raw bytes.
    final args = Uint8List.fromList(utf8.encode('{"to":"bob\u202Eten.tset"}'));
    expect(NearDisplay.argsText(args), '0x${args.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}');
    // Pretty-printed JSON keeps its newlines; escaped controls inside strings stay escaped.
    expect(NearDisplay.argsText(Uint8List.fromList(utf8.encode('{"a":"x\\ny"}'))), '{\n  "a": "x\\ny"\n}');
  });

  test('headline names a single action and counts several', () {
    expect(NearDisplay.headline(_tx(actions: [_action(NearActionKind.transfer)])), 'SEND');
    expect(
      NearDisplay.headline(_tx(actions: [_action(NearActionKind.addKey, fullAccess: true)])),
      'ADD FULL ACCESS KEY',
    );
    expect(NearDisplay.headline(_tx(actions: [_action(NearActionKind.addKey)])), 'ADD FUNCTION CALL KEY');
    expect(
      NearDisplay.headline(_tx(actions: [_action(NearActionKind.functionCall), _action(NearActionKind.transfer)])),
      '2 ACTIONS',
    );
  });

  test('key, code and account changes are dangerous; sends and calls are not', () {
    for (final kind in [
      NearActionKind.addKey,
      NearActionKind.deleteKey,
      NearActionKind.deleteAccount,
      NearActionKind.deployContract,
      NearActionKind.stake,
    ]) {
      expect(NearDisplay.isDangerous(_action(kind)), isTrue, reason: '$kind');
    }
    for (final kind in [NearActionKind.transfer, NearActionKind.functionCall, NearActionKind.createAccount]) {
      expect(NearDisplay.isDangerous(_action(kind)), isFalse, reason: '$kind');
    }
  });

  group('NearDisplay.networkMismatch', () {
    test('is silent when names match the network or are implicit', () {
      expect(NearDisplay.networkMismatch(_tx(), 'testnet'), isNull);
      expect(NearDisplay.networkMismatch(_tx(signer: 'alice.near', receiver: 'bob.near'), 'mainnet'), isNull);
      expect(NearDisplay.networkMismatch(_tx(signer: 'a' * 64, receiver: '0x${'b' * 40}'), 'mainnet'), isNull);
      expect(NearDisplay.networkMismatch(_tx(), 'localnet'), isNull);
    });

    test('names each account that does not belong to the network', () {
      expect(NearDisplay.networkMismatch(_tx(), 'mainnet'), contains('alice.testnet and bob.testnet are not mainnet'));
      expect(
        NearDisplay.networkMismatch(_tx(signer: 'alice.near'), 'mainnet'),
        contains('bob.testnet is not a mainnet account name'),
      );
    });
  });

  test('debug borsh writer reproduces the near-cli-rs transfer vector byte for byte', () {
    // near-cli-rs 0.30.1 `sign-later` for alice.testnet -> bob.testnet, 1 NEAR,
    // ed25519 key 0x11*32, nonce 42, block hash 0x22*32.
    const golden =
        'DQAAAGFsaWNlLnRlc3RuZXQAEREREREREREREREREREREREREREREREREREREREREREqAAAAAAAAAAsAAABib2IudGVzdG5ldCIiIiIiIiIi'
        'IiIiIiIiIiIiIiIiIiIiIiIiIiIiIiIiAQAAAAMAAACh7czOG8LTAAAAAAAA';
    final sample = DebugNearPayloads.samples(null).singleWhere((c) => c.label.startsWith('signed by an ed25519'));
    expect(base64Encode(sample.request.transaction), golden);
  });
}
