import 'package:quantus_desktop_wallet/l10n/app_localizations.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

QrScanStrings scanStringsFor(AppLocalizations l10n, {required String idleHint, String? collectingLabel}) =>
    QrScanStrings(
      idleHint: idleHint,
      collectingLabel: collectingLabel ?? l10n.signScanLabel,
      progress: l10n.signScanProgress,
      scanning: l10n.signScanScanning,
      stallHint: l10n.signScanStall,
      missingFrames: (shown, more) =>
          more > 0 ? l10n.signScanMissingMore(shown.join(', '), more) : l10n.signScanMissing(shown.join(', ')),
      errorHint: l10n.signScanError,
      completeLabel: l10n.signScanComplete,
    );
