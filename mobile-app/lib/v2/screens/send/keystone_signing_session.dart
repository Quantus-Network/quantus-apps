import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';

/// Callback that broadcasts an extrinsic after a hardware device has signed it.
///
/// Implementations should create pending UI state, submit via
/// [SubstrateService.submitExtrinsicWithExternalSignature], and start any
/// indexer polling. Returns the extrinsic hash hex (`0x…`).
typedef KeystoneSignatureSubmitter =
    Future<String> Function(
      WidgetRef ref, {
      required UnsignedTransactionData unsignedData,
      required Uint8List signature,
      required Uint8List publicKey,
    });

/// Describes one Keystone hardware-signing flow.
///
/// Transfers, multisig actions, and future runtime calls configure this session
/// and share the same QR display and signature scanner screens.
class KeystoneSigningSession {
  final Account account;
  final RuntimeCall Function() buildCall;
  final String? primaryDetail;
  final String? secondaryDetail;
  final String? tertiaryDetail;
  final KeystoneSignCacheKey? cacheKey;
  final KeystoneSignatureSubmitter submitSigned;
  final String telemetryPrefix;

  const KeystoneSigningSession({
    required this.account,
    required this.buildCall,
    required this.submitSigned,
    this.primaryDetail,
    this.secondaryDetail,
    this.tertiaryDetail,
    this.cacheKey,
    this.telemetryPrefix = 'keystone_signing',
  });
}
