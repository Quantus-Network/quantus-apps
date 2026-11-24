import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/signature_qr_view.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/rejected_screen.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';

/// The approve and reject half of a signing review, the same for every
/// chain. Back from the signature QR returns to the review, so the review
/// remembers that a signature was shown: a rejection after that cannot claim
/// nothing was signed.
mixin SigningReviewState<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool signing = false;
  bool signatureShown = false;
  String? signError;

  /// Has the wallet [sign], which uses the key at that point only, and shows
  /// the signature. A wallet that seals its key prompts here.
  Future<void> approve(Future<Uint8List> Function(WalletController wallet) sign) async {
    setState(() {
      signing = true;
      signError = null;
    });
    final Uint8List signed;
    try {
      signed = await sign(ref.read(walletControllerProvider.notifier));
    } on VaultAccessCancelled {
      _refuse('Cancelled. Nothing was signed.');
      return;
    } on KeyRefused catch (e) {
      _refuse(e.message);
      return;
    } catch (e, st) {
      debugPrint('Signing failed: $e\n$st');
      _refuse('Signing failed: $e');
      return;
    }
    if (!mounted) return;
    setState(() => signing = false);
    showSignature(signed);
  }

  void _refuse(String message) {
    if (!mounted) return;
    setState(() {
      signing = false;
      signError = message;
    });
  }

  /// Step 3. From here on, this device has handed out a signature.
  @visibleForTesting
  void showSignature(Uint8List signed) {
    setState(() => signatureShown = true);
    SignatureQrView.push(context, signed);
  }

  void reject() => Navigator.pushReplacement(
    context,
    MaterialPageRoute(builder: (_) => RejectedScreen(signatureShown: signatureShown)),
  );
}
