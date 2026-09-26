import 'dart:convert';
import 'dart:typed_data';

import 'package:base_x/base_x.dart';
import 'package:crypto/crypto.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'package:quantus_sdk/src/constants/app_constants.dart';

/// 1Click signs every quote response: Ed25519 over the base58 SHA-256 of a
/// key-sorted JSON of chosen request and quote fields plus the timestamp.
/// Mirrors verifyQuoteSignature in @defuse-protocol/one-click-sdk-typescript,
/// so a tampered deposit address or amount fails to verify.
class OneClickQuoteSignature {
  static const _prefix = 'ed25519:';
  static final _base58 = BaseXCodec('123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz');
  static const _requestFields = [
    'dry',
    'swapType',
    'slippageTolerance',
    'originAsset',
    'depositType',
    'destinationAsset',
    'amount',
    'refundTo',
    'refundType',
    'recipient',
    'recipientType',
    'deadline',
  ];
  static const _optionalRequestFields = [
    'quoteWaitingTimeMs',
    'referral',
    'virtualChainRecipient',
    'virtualChainRefundRecipient',
    'customRecipientMsg',
  ];
  static const _quoteFields = [
    'amountIn',
    'amountInFormatted',
    'amountInUsd',
    'minAmountIn',
    'amountOut',
    'amountOutFormatted',
    'amountOutUsd',
    'minAmountOut',
  ];
  static const _liveQuoteFields = [
    'depositAddress',
    'depositMemo',
    'deadline',
    'timeWhenInactive',
    'timeEstimate',
    'refundFee',
    'withdrawFee',
  ];

  /// Whether [response] carries a valid signature from [managerPublicKey].
  static bool verify(Map<String, dynamic> response, {String managerPublicKey = AppConstants.oneClickManagerPublicKey}) {
    final signature = response['signature'];
    if (signature is! String) return false;
    try {
      final message = utf8.encode(hash(response));
      return ed25519.verify(ed25519.PublicKey(decodeKey(managerPublicKey)), message, decodeKey(signature));
    } on FormatException {
      return false;
    } on ArgumentError {
      return false;
    }
  }

  /// Base58 SHA-256 of the signed payload; the bytes of this string are what
  /// the signature covers.
  static String hash(Map<String, dynamic> response) {
    final request = response['quoteRequest'] as Map<String, dynamic>;
    final quote = response['quote'] as Map<String, dynamic>;
    final signed = <String, Object?>{
      for (final k in _requestFields)
        if (request[k] != null) k: request[k],
      for (final k in _optionalRequestFields)
        if (_truthy(request[k])) k: request[k],
      for (final k in _quoteFields)
        if (quote[k] != null) k: quote[k],
      if (request['dry'] != true)
        for (final k in _liveQuoteFields)
          if (_truthy(quote[k])) k: quote[k],
      if (response['timestamp'] != null) 'timestamp': response['timestamp'],
    };
    final digest = sha256.convert(utf8.encode(stableJson(signed)));
    return _base58.encode(Uint8List.fromList(digest.bytes));
  }

  /// JSON with keys sorted at every level and no whitespace, as
  /// json-stable-stringify prints it; a whole-number double prints as an
  /// integer the way JavaScript does.
  static String stableJson(Object? value) => switch (value) {
    Map() =>
      '{${(value.keys.cast<String>().toList()..sort()).map((k) => '${jsonEncode(k)}:${stableJson(value[k])}').join(',')}}',
    List() => '[${value.map(stableJson).join(',')}]',
    double() when value.isFinite && value == value.truncateToDouble() && value.abs() < 1e21 => value.toInt().toString(),
    _ => jsonEncode(value),
  };

  static Uint8List decodeKey(String value) =>
      _base58.decode(value.startsWith(_prefix) ? value.substring(_prefix.length) : value);

  static String encodeKey(Uint8List bytes) => '$_prefix${_base58.encode(bytes)}';

  static bool _truthy(Object? v) => v != null && v != false && v != 0 && v != '' && !(v is double && v.isNaN);
}
