import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:quantus_sdk/src/quantus_payload_parser.dart';
import 'package:ss58/ss58.dart';

/// A signing request in an envelope version this app does not read, usually
/// because the hot wallet is newer than this app.
class UnsupportedSigningRequestVersionException extends FormatException {
  final Object? requested;

  UnsupportedSigningRequestVersionException(this.requested)
    : super(
        'Signing request version $requested is not supported, this app reads versions '
        '${SigningRequest.version} and ${NearSigningRequest.version}',
      );
}

/// Any signing request this app reads, dispatched on the envelope's `v`.
///
/// Version 1 ([SigningRequest]) carries a Quantus signing payload for a named
/// SS58 account; version 2 ([NearSigningRequest]) carries a NEAR transaction,
/// which names its own signer and key. Both travel in the same
/// `ur:quantus-sign-request` UR, so a wallet built before v2 refuses it by
/// version, exactly as it refuses any version it does not know.
sealed class AnySigningRequest {
  const AnySigningRequest();

  /// Throws [FormatException] on anything that is not exactly one envelope.
  static AnySigningRequest decode(Uint8List bytes) {
    final json = _decodeJsonObject(bytes);
    final version = json['v'];
    return switch (version) {
      SigningRequest.version => SigningRequest.decode(bytes),
      NearSigningRequest.version => NearSigningRequest.decode(bytes),
      _ => throw UnsupportedSigningRequestVersionException(version),
    };
  }
}

Map<dynamic, dynamic> _decodeJsonObject(Uint8List bytes) {
  final Object? json;
  try {
    json = jsonDecode(utf8.decode(bytes));
  } catch (e) {
    throw FormatException('Not a signing request: $e');
  }
  if (json is! Map) throw const FormatException('Signing request is not a JSON object');
  return json;
}

void _requireExactKeys(Map<dynamic, dynamic> json, Set<String> keys) {
  final actual = json.keys.map((k) => '$k').toSet();
  if (!actual.containsAll(keys) || actual.length != keys.length) {
    throw FormatException('Signing request keys ${actual.toList()..sort()} are not ${keys.toList()..sort()}');
  }
}

Uint8List _decodePayload(Object? payload) {
  if (payload is! String || !payload.startsWith('0x')) {
    throw const FormatException('Signing request payload is not 0x hex');
  }
  final payloadHex = payload.substring(2);
  if (payloadHex.length > maxPayloadBytes * 2) {
    throw const FormatException('Signing request payload too large: more than $maxPayloadBytes bytes');
  }
  final Uint8List bytesOut;
  try {
    bytesOut = Uint8List.fromList(hex.decode(payloadHex));
  } catch (e) {
    throw FormatException('Signing request payload is not hex: $e');
  }
  if (bytesOut.isEmpty) throw const FormatException('Signing request payload is empty');
  if (bytesOut.length > maxPayloadBytes) {
    throw FormatException('Signing request payload too large: ${bytesOut.length} bytes');
  }
  return bytesOut;
}

/// A NEAR transaction for this wallet to sign (envelope version 2).
///
/// The payload is the borsh-encoded NEAR `TransactionV0`, sent raw so the
/// signer can decode and display every action. It already names the signer
/// account and the exact public key that must sign, so the envelope carries no
/// `signer`; the device matches that key against its own ML-DSA-65 accounts.
/// [network] is for display only — NEAR transactions carry no chain id, and
/// nothing in it is signed.
class NearSigningRequest extends AnySigningRequest {
  static const int version = 2;
  static const String chain = 'near';

  /// The only network labels a request may carry, spelled exactly. The label
  /// drives what the signer is told and which account-name check runs, so a
  /// lookalike such as `"testnet "` must be refused rather than shown.
  static const Set<String> supportedNetworks = {'mainnet', 'testnet'};

  final String network;
  final Uint8List transaction;

  const NearSigningRequest({required this.network, required this.transaction});

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({'v': version, 'chain': chain, 'network': network, 'payload': '0x${hex.encode(transaction)}'}),
    ),
  );

  /// Throws [FormatException] on anything that is not exactly this envelope.
  static NearSigningRequest decode(Uint8List bytes) {
    final json = _decodeJsonObject(bytes);
    _requireExactKeys(json, const {'v', 'chain', 'network', 'payload'});
    if (json['v'] != version) throw UnsupportedSigningRequestVersionException(json['v']);
    if (json['chain'] != chain) throw FormatException('Signing request is for chain ${json['chain']}, not NEAR');

    final network = json['network'];
    if (network is! String || !supportedNetworks.contains(network)) {
      throw FormatException('Signing request NEAR network ${jsonEncode(network)} is not one of $supportedNetworks');
    }

    return NearSigningRequest(network: network, transaction: _decodePayload(json['payload']));
  }
}

/// A signing payload together with the account that must sign it.
///
/// The payload alone says nothing about which key it belongs to, so a signer
/// holding several accounts cannot tell which to use, and one holding the wrong
/// account cannot tell that it does.
class SigningRequest extends AnySigningRequest {
  static const int version = 1;

  final String signer;
  final Uint8List payload;

  const SigningRequest({required this.signer, required this.payload});

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(jsonEncode({'v': version, 'signer': signer, 'payload': '0x${hex.encode(payload)}'})),
  );

  /// Throws [FormatException] on anything that is not exactly this envelope.
  static SigningRequest decode(Uint8List bytes) {
    final json = _decodeJsonObject(bytes);
    _requireExactKeys(json, const {'v', 'signer', 'payload'});
    if (json['v'] != version) throw UnsupportedSigningRequestVersionException(json['v']);

    final signer = json['signer'];
    if (signer is! String) throw const FormatException('Signing request signer is not a string');
    try {
      Address.decode(signer);
    } catch (e) {
      throw FormatException('Signing request signer is not a valid address: $e');
    }

    return SigningRequest(signer: signer, payload: _decodePayload(json['payload']));
  }
}
