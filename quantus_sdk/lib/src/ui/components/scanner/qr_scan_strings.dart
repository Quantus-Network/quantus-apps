/// Copy the scanner shows; apps pass localized values.
class QrScanStrings {
  final String idleHint;
  final String collectingLabel;
  final String Function(int scanned, int total) progress;
  final String Function(int scanned) scanning;
  final String stallHint;
  final String Function(List<int> shown, int more) missingFrames;
  final String errorHint;
  final String completeLabel;

  const QrScanStrings({
    required this.idleHint,
    required this.collectingLabel,
    required this.progress,
    required this.scanning,
    required this.stallHint,
    required this.missingFrames,
    required this.errorHint,
    required this.completeLabel,
  });
}
