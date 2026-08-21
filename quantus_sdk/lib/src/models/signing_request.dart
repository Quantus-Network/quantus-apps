import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:quantus_sdk/src/quantus_payload_parser.dart';
import 'package:ss58/ss58.dart';

/// A signing payload together with the account that must sign it.
///
/// The payload alone says nothing about which key it belongs to, so a signer
/// holding several accounts cannot tell which to use, and one holding the wrong
/// account cannot tell that it does.
class SigningRequest {
  static const int version = 1;

  final String signer;
  final Uint8List payload;

  const SigningRequest({required this.signer, required this.payload});

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(jsonEncode({'v': version, 'signer': signer, 'payload': '0x${hex.encode(payload)}'})),
  );

  /// Throws [FormatException] on anything that is not exactly this envelope.
  static SigningRequest decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw FormatException('Not a signing request: $e');
    }
    if (json is! Map) throw const FormatException('Signing request is not a JSON object');

    const keys = {'v', 'signer', 'payload'};
    final actual = json.keys.map((k) => '$k').toSet();
    if (!actual.containsAll(keys) || actual.length != keys.length) {
      throw FormatException('Signing request keys ${actual.toList()..sort()} are not ${keys.toList()..sort()}');
    }
    if (json['v'] != version) {
      throw FormatException('Unsupported signing request version: ${json['v']}');
    }

    final signer = json['signer'];
    if (signer is! String) throw const FormatException('Signing request signer is not a string');
    try {
      Address.decode(signer);
    } catch (e) {
      throw FormatException('Signing request signer is not a valid address: $e');
    }

    final payload = json['payload'];
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

    return SigningRequest(signer: signer, payload: bytesOut);
  }
}
