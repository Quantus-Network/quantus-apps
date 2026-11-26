import 'package:quantus_sdk/quantus_sdk.dart';

/// The one-line-plus-subtitle form used by multisig proposal rows and sheets.
class DecodedCallHeadline {
  final String primary;
  final String? recipient;
  final String? palletSubtitle;

  const DecodedCallHeadline({required this.primary, this.recipient, this.palletSubtitle});

  String? get secondary => recipient ?? palletSubtitle;

  static DecodedCallHeadline of(DecodedCall call, {required String Function(BigInt token) amountText}) {
    final summary = call.summary;
    if (summary == null) {
      return DecodedCallHeadline(
        primary: call.call.isEmpty ? call.pallet : call.humanCall,
        palletSubtitle: call.call.isEmpty ? null : call.pallet,
      );
    }
    return DecodedCallHeadline(
      primary: summary.assetId == null ? amountText(summary.amount) : '${summary.amount} (asset #${summary.assetId})',
      recipient: summary.recipient == null ? null : AddressFormattingService.formatAddress(summary.recipient!),
    );
  }
}
