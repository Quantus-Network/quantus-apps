import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/app_version.dart';
import 'package:quantus_cold_wallet/components/step_header.dart';
import 'package:quantus_cold_wallet/debug/debug_calls_screen.dart';
import 'package:quantus_cold_wallet/screens/sign_near_transaction_screen.dart';
import 'package:quantus_cold_wallet/screens/sign_transaction_screen.dart';

/// Step 1 of signing: scans the animated UR QR the hot wallet shows on the
/// shared [AnimatedQrScanner], then hands the decoded request to the signing
/// screen. Fails loudly on decode errors.
class ScanTransactionScreen extends StatefulWidget {
  /// How long without a new frame before the header swaps in the scanning
  /// tips. Scanning never stops: the frames already collected stay, the
  /// counter keeps going, and only Back or Cancel leaves.
  static const stallTimeout = Duration(seconds: 3);

  const ScanTransactionScreen({super.key});

  @override
  State<ScanTransactionScreen> createState() => _ScanTransactionScreenState();
}

class _ScanTransactionScreenState extends State<ScanTransactionScreen> {
  static const _labels = ScannerLabels(
    back: 'Back',
    torch: 'Torch',
    gallery: 'Gallery',
    cameraUnavailable: 'Camera unavailable',
    cameraPermissionDenied: 'Grant camera access in Settings to scan the transaction QR.',
    retry: 'Try again',
  );

  String? _error;
  Timer? _stallTimer;
  bool _stalled = false;

  @override
  void dispose() {
    _stallTimer?.cancel();
    super.dispose();
  }

  /// Every new frame restarts the clock; when it runs out the header shows
  /// the tips. Armed only once a frame has arrived: with nothing received yet
  /// there is nothing to hint about.
  void _armStallTimer() {
    _stallTimer?.cancel();
    if (_stalled) setState(() => _stalled = false);
    _stallTimer = Timer(ScanTransactionScreen.stallTimeout, () {
      if (mounted) setState(() => _stalled = true);
    });
  }

  Future<void> _open(Uint8List payload) async {
    _stallTimer?.cancel();
    final screen = switch (AnySigningRequest.decode(payload)) {
      final SigningRequest request => SignTransactionScreen(request: request),
      final NearSigningRequest request => SignNearTransactionScreen(
        request: request,
        transaction: decodeNearTransaction(transaction: request.transaction),
      ),
    };
    if (!mounted) return;
    unawaited(Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen)));
  }

  void _fail(Object error) {
    debugPrint('Rejected signing request QR: $error');
    _stallTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _stalled = false;
      _error = switch (error) {
        UrScanLimitException() => 'Too many unusable QR frames. Restart the transfer on your hot wallet.',
        UnsupportedSigningRequestVersionException() => '${error.message}. $updateAppHint $currentAppVersion',
        FormatException() => 'Not a Quantus signing request: ${error.message}',
        // decodeNearTransaction reports a malformed transaction as a bare string.
        String() => 'Could not read the NEAR transaction: $error',
        _ => 'Failed to decode QR: $error',
      };
    });
  }

  /// Simulators have no camera, so debug builds open the catalogue of every
  /// call the signer can review and inject one directly, exercising the same
  /// review → sign path a scan would reach.
  Future<void> _openDebugCalls() {
    return Navigator.push(context, MaterialPageRoute(builder: (_) => const DebugCallsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedQrScanner(
      onComplete: _open,
      onError: _fail,
      onFrame: _armStallTimer,
      labels: _labels,
      progressLabel: 'RECEIVING TRANSACTION',
      errorText: _error,
      caption: StepHeader(
        step: 1,
        total: 3,
        title: _stalled ? 'Not picking up new frames' : 'Scan the transaction',
        subtitle: _stalled
            ? "Move the two screens further apart, turn your phone's brightness up, and avoid glare."
            : "Hold this device over your phone's screen to load the transaction.",
      ),
      footerActions: [
        const SizedBox(height: 20),
        QuantusButton.simple(
          label: 'Cancel Transaction',
          variant: ButtonVariant.underline,
          padding: const EdgeInsets.symmetric(vertical: 12),
          onTap: () => Navigator.pop(context),
        ),
        if (kDebugMode)
          QuantusButton.simple(
            label: 'Debug calls',
            variant: ButtonVariant.underline,
            padding: const EdgeInsets.symmetric(vertical: 12),
            onTap: _openDebugCalls,
          ),
      ],
    );
  }
}
