import 'dart:typed_data';

import 'package:quantus_sdk/generated/bell/types/quantus_runtime/runtime_call.dart';
import 'package:quantus_sdk/src/models/account.dart';
import 'package:quantus_sdk/src/models/signing_request.dart';
import 'package:quantus_sdk/src/models/unsigned_transaction_data.dart';
import 'package:quantus_sdk/src/services/substrate_service.dart';
import 'package:quantus_sdk/src/signing/cold_sign_era.dart';
import 'package:quantus_sdk/src/utils/ur_qr.dart';

/// Identifies a signing payload by the parameters that define the call. Block
/// height and nonce are excluded so chain drift does not invalidate a cached QR
/// within a session.
class ColdSignRequestKey {
  final String accountId;
  final String recipientAddress;
  final BigInt amount;
  final String identity;

  const ColdSignRequestKey({
    required this.accountId,
    required this.recipientAddress,
    required this.amount,
    this.identity = '',
  });

  factory ColdSignRequestKey.fromSendParams({
    required String accountId,
    required String recipientAddress,
    required BigInt amount,
  }) => ColdSignRequestKey(accountId: accountId, recipientAddress: recipientAddress.trim(), amount: amount);

  factory ColdSignRequestKey.forExtrinsic({required String accountId, required String identity}) =>
      ColdSignRequestKey(accountId: accountId, recipientAddress: '', amount: BigInt.zero, identity: identity);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ColdSignRequestKey &&
          accountId == other.accountId &&
          recipientAddress == other.recipientAddress &&
          amount == other.amount &&
          identity == other.identity;

  @override
  int get hashCode => Object.hash(accountId, recipientAddress, amount, identity);
}

/// An unsigned transaction prepared for an air-gapped signer: the payload,
/// wrapped in a [SigningRequest] naming the account that must sign it, framed
/// as UR parts ready to display.
class ColdSignRequest {
  static const int defaultFragmentLength = 200;

  final Account account;
  final UnsignedTransactionData unsignedData;
  final List<String> urParts;
  final DateTime createdAt;
  final ColdSignRequestKey? key;

  const ColdSignRequest({
    required this.account,
    required this.unsignedData,
    required this.urParts,
    required this.createdAt,
    this.key,
  });

  static Uint8List requestBytes({required String signer, required Uint8List payload}) =>
      SigningRequest(signer: signer, payload: payload).encode();

  static Future<ColdSignRequest> build({
    required Account account,
    required RuntimeCall call,
    ColdSignRequestKey? key,
    int maxFragmentLength = defaultFragmentLength,
    SubstrateService? substrate,
    DateTime? now,
  }) async {
    final unsigned = await (substrate ?? SubstrateService()).getUnsignedTransactionPayload(account, call);
    final parts = encodeUrForQr(
      data: requestBytes(signer: account.accountId, payload: unsigned.encodedPayloadRaw),
      maxFragmentLength: maxFragmentLength,
    );
    if (parts.isEmpty) throw StateError('UR encoding of the sign request produced no frames');
    return ColdSignRequest(
      account: account,
      unsignedData: unsigned,
      urParts: parts,
      createdAt: now ?? DateTime.now(),
      key: key,
    );
  }

  bool isStale([DateTime? now]) => ColdSignEra.isStale(unsignedData.payloadToSign, createdAt, now ?? DateTime.now());
}
