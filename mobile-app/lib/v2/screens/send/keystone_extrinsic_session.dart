import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// Callback that broadcasts an extrinsic after a hardware device has signed it.
///
/// Implementations should create pending UI state, submit via
/// [SubstrateService.submitExtrinsicWithExternalSignature], and start any
/// indexer polling. Returns the extrinsic hash hex (`0x…`).
typedef KeystoneExternalSubmitter =
    Future<String> Function(
      WidgetRef ref, {
      required UnsignedTransactionData unsignedData,
      required Uint8List signature,
      required Uint8List publicKey,
    });

/// Describes a Keystone (hardware) signing session for an arbitrary extrinsic.
///
/// Used by the shared QR show / signature-scan screens so transfers, multisig
/// approvals, and other calls can share one hardware path.
class KeystoneExtrinsicSession {
  /// Account that must sign (hardware / Keystone).
  final Account account;

  /// Builds the runtime call to wrap in an unsigned payload.
  final RuntimeCall Function() buildCall;

  /// App bar title while showing the unsigned QR.
  final String title;

  /// Primary detail line under the instruction (e.g. amount).
  final String? primaryDetail;

  /// Secondary detail line (e.g. recipient address).
  final String? secondaryDetail;

  /// Tertiary detail line (e.g. recipient checksum / checkphrase).
  final String? tertiaryDetail;

  /// Optional opaque identity for payload caching within a session.
  ///
  /// When null, the QR payload is always rebuilt.
  final String? cacheIdentity;

  /// Submits the signed extrinsic and updates app state.
  final KeystoneExternalSubmitter submitSigned;

  /// Telemetry event name sent when the payload is prepared / submitted.
  final String telemetryPrefix;

  const KeystoneExtrinsicSession({
    required this.account,
    required this.buildCall,
    required this.title,
    required this.submitSigned,
    this.primaryDetail,
    this.secondaryDetail,
    this.tertiaryDetail,
    this.cacheIdentity,
    this.telemetryPrefix = 'keystone_extrinsic',
  });
}
