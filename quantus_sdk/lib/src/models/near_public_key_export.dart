import 'dart:convert';
import 'dart:typed_data';

/// A cold wallet's ML-DSA-65 key published for use on NEAR, as the cold
/// wallet shows it in a QR and a hot wallet or CLI reads it.
///
/// [address] is the Quantus SS58 address of the account that holds the key,
/// so the reader can tie the NEAR key to a cold account it already knows;
/// [nearPublicKey] is the key in NEAR's `ml-dsa-65:<base58>` text form, ready
/// for `near account add-key` and for a signing request's `--signer-public-key`.
class NearPublicKeyExport {
  static const int version = 1;
  static const String kind = 'near-public-key';
  static const String nearKeyPrefix = 'ml-dsa-65:';

  final String address;
  final String nearPublicKey;

  const NearPublicKeyExport({required this.address, required this.nearPublicKey});

  Uint8List encode() => Uint8List.fromList(
    utf8.encode(jsonEncode({'v': version, 'kind': kind, 'address': address, 'near_public_key': nearPublicKey})),
  );

  /// Throws [FormatException] on anything that is not exactly one export.
  static NearPublicKeyExport decode(Uint8List bytes) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(bytes));
    } catch (e) {
      throw FormatException('Not a NEAR public key export: $e');
    }
    if (json is! Map) throw const FormatException('NEAR public key export is not a JSON object');
    final keys = json.keys.map((k) => '$k').toSet();
    const expected = {'v', 'kind', 'address', 'near_public_key'};
    if (keys.length != expected.length || !keys.containsAll(expected)) {
      throw FormatException(
        'NEAR public key export keys ${keys.toList()..sort()} are not ${expected.toList()..sort()}',
      );
    }
    if (json['v'] != version) throw FormatException('NEAR public key export version ${json['v']} is not $version');
    if (json['kind'] != kind) throw FormatException('NEAR public key export kind ${json['kind']} is not $kind');
    final address = json['address'];
    final nearPublicKey = json['near_public_key'];
    if (address is! String || address.isEmpty) throw const FormatException('NEAR public key export address missing');
    if (nearPublicKey is! String || !nearPublicKey.startsWith(nearKeyPrefix)) {
      throw const FormatException('NEAR public key export key is not $nearKeyPrefix…');
    }
    return NearPublicKeyExport(address: address, nearPublicKey: nearPublicKey);
  }
}
