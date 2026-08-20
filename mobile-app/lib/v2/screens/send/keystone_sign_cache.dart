import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

/// Blocks of era lifetime that must still remain when a payload is served or
/// kept on screen. After the QR is displayed the user still has to scan it
/// with the device, verify, approve, and scan the signature back, so a payload
/// anywhere near expiry must never enter that round trip.
const int keystoneSignEraReserveBlocks = 10;

/// Blocks left before era expiry below which a signed payload is refused at
/// submission: it would likely expire while propagating.
const int keystoneSignSubmitEraMarginBlocks = 2;

/// Thrown when a signed payload reaches submission too close to era expiry.
class KeystoneEraExpiredException implements Exception {
  final int currentBlock;
  final int expiryBlock;

  const KeystoneEraExpiredException({required this.currentBlock, required this.expiryBlock});

  @override
  String toString() => 'Keystone payload era expired: block $currentBlock, era ends at block $expiryBlock';
}

/// Max age for a Keystone payload derived from its mortal era period: expired
/// once less than [keystoneSignEraReserveBlocks] of era lifetime remain.
Duration keystoneSignCacheMaxAge(QuantusSigningPayload payload) {
  if (payload.eraPeriod == 0) {
    return const Duration(days: 1);
  }
  final usableBlocks = payload.eraPeriod - keystoneSignEraReserveBlocks;
  if (usableBlocks <= 0) {
    throw StateError(
      'Era period ${payload.eraPeriod} is not longer than the $keystoneSignEraReserveBlocks-block reserve',
    );
  }
  return Duration(seconds: usableBlocks * AppConstants.avgBlockTimeSeconds);
}

/// Returns true when [entry] is older than the mortal era validity window.
bool isKeystoneSignCacheEntryExpired(KeystoneSignCacheEntry entry, DateTime now) {
  return now.difference(entry.storedAt) >= keystoneSignCacheMaxAge(entry.unsignedData.payloadToSign);
}

/// Identifies a Keystone signing payload by the parameters that define the
/// extrinsic call. Block height and nonce are excluded so chain drift does not
/// invalidate the cached QR within a session.
///
/// Transfer payloads use [fromSendParams]; arbitrary extrinsics (e.g. multisig
/// approve) use [forExtrinsic] with an opaque [identity].
class KeystoneSignCacheKey {
  final String accountId;
  final String recipientAddress;
  final BigInt amount;

  /// Opaque call identity for non-transfer extrinsics. Empty for send payloads.
  final String identity;

  const KeystoneSignCacheKey({
    required this.accountId,
    required this.recipientAddress,
    required this.amount,
    this.identity = '',
  });

  factory KeystoneSignCacheKey.fromSendParams({
    required String accountId,
    required String recipientAddress,
    required BigInt amount,
  }) {
    return KeystoneSignCacheKey(accountId: accountId, recipientAddress: recipientAddress.trim(), amount: amount);
  }

  /// Cache key for non-transfer extrinsics (multisig approve/execute/cancel, …).
  factory KeystoneSignCacheKey.forExtrinsic({required String accountId, required String identity}) {
    return KeystoneSignCacheKey(accountId: accountId, recipientAddress: '', amount: BigInt.zero, identity: identity);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeystoneSignCacheKey &&
          accountId == other.accountId &&
          recipientAddress == other.recipientAddress &&
          amount == other.amount &&
          identity == other.identity;

  @override
  int get hashCode => Object.hash(accountId, recipientAddress, amount, identity);
}

class KeystoneSignCacheEntry {
  final KeystoneSignCacheKey key;
  final UnsignedTransactionData unsignedData;
  final List<String> urParts;
  final DateTime storedAt;

  const KeystoneSignCacheEntry({
    required this.key,
    required this.unsignedData,
    required this.urParts,
    required this.storedAt,
  });
}

class KeystoneSignCacheNotifier extends StateNotifier<KeystoneSignCacheEntry?> {
  KeystoneSignCacheNotifier() : super(null);

  void startNewSendSession() {
    state = null;
  }

  KeystoneSignCacheEntry? lookup(KeystoneSignCacheKey key, {DateTime? now}) {
    final entry = state;
    if (entry == null || entry.key != key) return null;
    if (isKeystoneSignCacheEntryExpired(entry, now ?? DateTime.now())) {
      state = null;
      return null;
    }
    return entry;
  }

  void store({
    required KeystoneSignCacheKey key,
    required UnsignedTransactionData unsignedData,
    required List<String> urParts,
    DateTime? storedAt,
  }) {
    state = KeystoneSignCacheEntry(
      key: key,
      unsignedData: unsignedData,
      urParts: urParts,
      storedAt: storedAt ?? DateTime.now(),
    );
  }

  void reset() {
    state = null;
  }
}

final keystoneSignCacheProvider = StateNotifierProvider<KeystoneSignCacheNotifier, KeystoneSignCacheEntry?>(
  (ref) => KeystoneSignCacheNotifier(),
);

/// What an air-gapped signer is sent, before UR framing: the payload wrapped in
/// a [SigningRequest], which names the account that must sign it.
///
/// The payload alone says nothing about whose key it belongs to, so a signer
/// holding several accounts could not tell which to use, and one holding none
/// of them could not tell that it does not hold the right key.
Uint8List signRequestBytes({required String signer, required Uint8List payload}) =>
    SigningRequest(signer: signer, payload: payload).encode();

/// Builds the unsigned payload and its UR frames, serving a fresh cache entry
/// when one exists and storing the result under [cacheKey]. The review screen
/// prefetches through this so the QR screen usually renders instantly; the QR
/// screen itself calls it as the fallback when nothing was prefetched.
Future<({UnsignedTransactionData unsignedData, List<String> urParts, DateTime storedAt})> ensureKeystoneSignPayload(
  WidgetRef ref, {
  required Account account,
  required RuntimeCall Function() buildCall,
  KeystoneSignCacheKey? cacheKey,
}) async {
  final cache = ref.read(keystoneSignCacheProvider.notifier);
  if (cacheKey != null) {
    final cached = cache.lookup(cacheKey);
    if (cached != null) {
      return (unsignedData: cached.unsignedData, urParts: cached.urParts, storedAt: cached.storedAt);
    }
  }
  final unsigned = await ref.read(substrateServiceProvider).getUnsignedTransactionPayload(account, buildCall());
  final parts = encodeUr(
    data: signRequestBytes(signer: account.accountId, payload: unsigned.encodedPayloadRaw),
  );
  if (parts.isEmpty) throw Exception('Failed to encode transaction payload as UR');
  final storedAt = DateTime.now();
  if (cacheKey != null) cache.store(key: cacheKey, unsignedData: unsigned, urParts: parts, storedAt: storedAt);
  return (unsignedData: unsigned, urParts: parts, storedAt: storedAt);
}
