import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// Localized strings for every [QuantusScanner] in the app.
final scannerLabelsProvider = Provider<ScannerLabels>((ref) {
  final l10n = ref.watch(l10nProvider);
  return ScannerLabels(
    back: l10n.componentQrScannerBack,
    torch: l10n.componentQrScannerTorch,
    gallery: l10n.componentQrScannerGallery,
    cameraUnavailable: l10n.componentQrScannerCameraUnavailable,
    cameraPermissionDenied: l10n.componentQrScannerCameraDenied,
    retry: l10n.commonTryAgain,
  );
});
