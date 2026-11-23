import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/signature_qr_view.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/rejected_screen.dart';

/// The approve and reject half of a signing review, the same for every
/// chain. Back from the signature QR returns to the review, so the review
/// remembers that a signature was shown: a rejection after that cannot claim
/// nothing was signed.
mixin SigningReviewState<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool signing = false;
  bool signatureShown = false;
  String? signError;

  /// Derives [signer]'s key at the point of use and shows what [sign] makes
  /// of it.
  void approve(String signer, Uint8List Function(Keypair keypair) sign) {
    final keypair = keypairFor(ref, signer);
    if (keypair == null) {
      setState(() => signError = 'Wallet is locked — unlock and try again. Nothing was signed.');
      return;
    }
    setState(() {
      signing = true;
      signError = null;
    });
    final Uint8List signed;
    try {
      signed = sign(keypair);
    } catch (e) {
      setState(() {
        signing = false;
        signError = 'Signing failed: $e';
      });
      return;
    }
    setState(() => signing = false);
    showSignature(signed);
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
