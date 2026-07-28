import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/components/animated_qr_scanner.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_sign_cache.dart';
import 'package:resonance_network_wallet/v2/screens/send/keystone_signing_session.dart';

/// Keystone-specific adapter for the generic animated QR scanner.
///
/// Decodes the completed UR payload and delegates submission to [session].
/// Pops with the submitted extrinsic hash.
class KeystoneSignatureScanScreen extends ConsumerStatefulWidget {
  final KeystoneSigningSession session;
  final UnsignedTransactionData unsignedData;

  const KeystoneSignatureScanScreen({super.key, required this.session, required this.unsignedData});

  @override
  ConsumerState<KeystoneSignatureScanScreen> createState() => _KeystoneSignatureScanScreenState();
}

class _KeystoneSignatureScanScreenState extends ConsumerState<KeystoneSignatureScanScreen> {
  static final RegExp _sequencePattern = RegExp(r'/(\d+)-(\d+)/');

  String? _error;

  AnimatedQrSequence? _sequenceForPart(String part) {
    final match = _sequencePattern.firstMatch(part);
    if (match == null) return null;
    return AnimatedQrSequence(index: int.parse(match.group(1)!), total: int.parse(match.group(2)!));
  }

  Future<void> _submit(List<String> parts) async {
    final bytes = decodeUr(urParts: parts);
    final signatureSize = signatureBytes().toInt();
    final expectedSize = signatureSize + publicKeyBytes().toInt();
    if (bytes.length != expectedSize) {
      throw Exception('Invalid signature length: expected $expectedSize bytes, got ${bytes.length}');
    }

    final hash = await widget.session.submitSigned(
      ref,
      unsignedData: widget.unsignedData,
      signature: bytes.sublist(0, signatureSize),
      publicKey: bytes.sublist(signatureSize),
    );

    ref.read(keystoneSignCacheProvider.notifier).reset();
    TelemetryService().sendEvent('${widget.session.telemetryPrefix}_submitted');
    if (!mounted) return;
    Navigator.pop(context, hash);
  }

  Future<void> _handleError(Object error) async {
    quantusDebugPrint('Keystone signature processing failed: $error');
    TelemetryService().sendError('Keystone signature processing failed', error: error);
    ref.read(keystoneSignCacheProvider.notifier).reset();
    if (!mounted) return;
    setState(() => _error = ref.read(l10nProvider).keystoneScanError);
  }

  Future<List<String>> _simulateSignature() async {
    final keypair = await widget.session.account.getKeypair();
    final signed = signMessageWithPubkey(keypair: keypair, message: widget.unsignedData.encodedPayloadToSign);
    return encodeUr(data: signed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return AnimatedQrScanner(
      acceptsPart: (part) => part.toLowerCase().startsWith('ur:'),
      isComplete: (parts) => isCompleteUr(urParts: parts),
      sequenceForPart: _sequenceForPart,
      onComplete: _submit,
      onError: _handleError,
      instruction: l10n.keystoneScanInstruction,
      submittingLabel: l10n.keystoneScanSubmitting,
      progressLabel: l10n.keystoneScanProgress,
      scanningLabel: l10n.keystoneScanScanning,
      errorText: _error,
      debugPartsBuilder: AppConstants.debugHardwareWallet ? _simulateSignature : null,
      debugActionLabel: 'DEBUG: Simulate signature',
    );
  }
}
