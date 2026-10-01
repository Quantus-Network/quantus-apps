import 'dart:convert';
import 'dart:typed_data';

import 'package:quantus_sdk/quantus_sdk.dart';

/// One NEAR transaction the signer can be asked to review.
class DebugNearCall {
  final String label;
  final NearSigningRequest request;

  const DebugNearCall({required this.label, required this.request});
}

/// Sample NEAR signing requests for the simulator, built with a minimal borsh
/// writer so they are byte-identical in shape to a hot wallet's `TransactionV0`.
///
/// [signingKey] is the raw 1952-byte ML-DSA-65 public key the wallet's own
/// account holds, so the review screen finds a signer; null when the wallet
/// has no ML-DSA-65 account, in which case every sample is refused as a key
/// not held here, which is also worth seeing.
class DebugNearPayloads {
  const DebugNearPayloads._();

  static final BigInt _near = BigInt.from(10).pow(24);
  static final BigInt _tgas = BigInt.from(10).pow(12);
  static final Uint8List _blockHash = Uint8List.fromList(List.filled(32, 0x22));
  static final Uint8List _ed25519Key = Uint8List.fromList(List.filled(32, 0x11));
  static final Uint8List _foreignMlDsaKey = Uint8List.fromList(List.filled(1952, 0x42));

  static List<DebugNearCall> samples(Uint8List? signingKey) {
    final key = signingKey ?? _foreignMlDsaKey;
    return [
      DebugNearCall(
        label: 'send 1.5 NEAR',
        request: _testnet(
          _tx(key, receiver: 'bob.testnet', actions: [_transfer(_near * BigInt.from(15) ~/ BigInt.from(10))]),
        ),
      ),
      DebugNearCall(
        label: 'ft_transfer on a token contract',
        request: _testnet(
          _tx(
            key,
            receiver: 'token.rhea.testnet',
            actions: [
              _functionCall(
                'ft_transfer',
                args: {'receiver_id': 'bob.testnet', 'amount': '1000000', 'memo': null},
                gas: _tgas * BigInt.from(30),
                deposit: BigInt.one,
              ),
            ],
          ),
        ),
      ),
      DebugNearCall(
        label: 'swap: ft_transfer_call then storage_deposit [two actions]',
        request: _testnet(
          _tx(
            key,
            receiver: 'ref-finance.testnet',
            actions: [
              _functionCall(
                'storage_deposit',
                args: {},
                gas: _tgas * BigInt.from(30),
                deposit: _near ~/ BigInt.from(80),
              ),
              _functionCall(
                'ft_transfer_call',
                args: {'receiver_id': 'ref-finance.testnet', 'amount': '500000', 'msg': '{"actions":[]}'},
                gas: _tgas * BigInt.from(180),
                deposit: BigInt.one,
              ),
            ],
          ),
        ),
      ),
      DebugNearCall(
        label: 'add a full access key [dangerous]',
        request: _testnet(_tx(key, receiver: 'alice.testnet', actions: [_addFullAccessKey(_ed25519Key)])),
      ),
      DebugNearCall(
        label: 'add a function call key limited to one contract',
        request: _testnet(
          _tx(
            key,
            receiver: 'alice.testnet',
            actions: [
              _addFunctionCallKey(
                _ed25519Key,
                receiver: 'app.rhea.testnet',
                methods: ['claim', 'stake'],
                allowance: _near ~/ BigInt.from(4),
              ),
            ],
          ),
        ),
      ),
      DebugNearCall(
        label: 'delete the account, balance to bob [dangerous]',
        request: _testnet(_tx(key, receiver: 'alice.testnet', actions: [_deleteAccount('bob.testnet')])),
      ),
      DebugNearCall(
        label: 'mainnet label on testnet account names [mismatch]',
        request: NearSigningRequest(
          network: 'mainnet',
          transaction: _tx(key, receiver: 'bob.testnet', actions: [_transfer(_near)]),
        ),
      ),
      DebugNearCall(
        label: 'signed by an ed25519 key [refused]',
        request: _testnet(_tx(_ed25519Key, receiver: 'bob.testnet', actions: [_transfer(_near)])),
      ),
      DebugNearCall(
        label: 'signed by an ML-DSA-65 key this wallet does not hold [refused]',
        request: _testnet(_tx(_foreignMlDsaKey, receiver: 'bob.testnet', actions: [_transfer(_near)])),
      ),
    ];
  }

  static NearSigningRequest _testnet(Uint8List tx) => NearSigningRequest(network: 'testnet', transaction: tx);

  /// borsh `TransactionV0`: signer, public key, nonce, receiver, block hash, actions.
  static Uint8List _tx(Uint8List publicKey, {required String receiver, required List<List<int>> actions}) {
    final w = _Borsh()
      ..string('alice.testnet')
      ..publicKey(publicKey)
      ..u64(BigInt.from(42))
      ..string(receiver)
      ..bytes(_blockHash)
      ..u32(actions.length);
    for (final action in actions) {
      w.bytes(action);
    }
    return w.take();
  }

  static List<int> _transfer(BigInt deposit) =>
      (_Borsh()
            ..u8(3)
            ..u128(deposit))
          .take();

  static List<int> _functionCall(
    String method, {
    required Map<String, Object?> args,
    required BigInt gas,
    required BigInt deposit,
  }) {
    final encodedArgs = utf8.encode(jsonEncode(args));
    return (_Borsh()
          ..u8(2)
          ..string(method)
          ..u32(encodedArgs.length)
          ..bytes(encodedArgs)
          ..u64(gas)
          ..u128(deposit))
        .take();
  }

  static List<int> _addFullAccessKey(Uint8List key) =>
      (_Borsh()
            ..u8(5)
            ..publicKey(key)
            ..u64(BigInt.zero) // access key nonce
            ..u8(1)) // FullAccess
          .take();

  static List<int> _addFunctionCallKey(
    Uint8List key, {
    required String receiver,
    required List<String> methods,
    BigInt? allowance,
  }) {
    final w = _Borsh()
      ..u8(5)
      ..publicKey(key)
      ..u64(BigInt.zero)
      ..u8(0); // FunctionCall permission
    if (allowance == null) {
      w.u8(0);
    } else {
      w
        ..u8(1)
        ..u128(allowance);
    }
    w
      ..string(receiver)
      ..u32(methods.length);
    for (final method in methods) {
      w.string(method);
    }
    return w.take();
  }

  static List<int> _deleteAccount(String beneficiary) =>
      (_Borsh()
            ..u8(7)
            ..string(beneficiary))
          .take();
}

/// Just enough borsh to write a `TransactionV0`.
class _Borsh {
  final BytesBuilder _out = BytesBuilder();

  void u8(int v) => _out.addByte(v);

  void u32(int v) => _out.add((ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List());

  void u64(BigInt v) => _le(v, 8);

  void u128(BigInt v) => _le(v, 16);

  void bytes(List<int> v) => _out.add(v);

  void string(String s) {
    final encoded = utf8.encode(s);
    u32(encoded.length);
    bytes(encoded);
  }

  /// A NEAR `PublicKey`: curve tag then the raw key. 32 bytes is ed25519 (0),
  /// 1952 is ML-DSA-65 (2).
  void publicKey(Uint8List key) {
    u8(switch (key.length) {
      32 => 0,
      1952 => 2,
      _ => throw ArgumentError('Not an ed25519 or ML-DSA-65 key: ${key.length} bytes'),
    });
    bytes(key);
  }

  void _le(BigInt v, int width) {
    var rest = v;
    final mask = BigInt.from(0xff);
    for (var i = 0; i < width; i++) {
      u8((rest & mask).toInt());
      rest >>= 8;
    }
  }

  Uint8List take() => _out.takeBytes();
}
