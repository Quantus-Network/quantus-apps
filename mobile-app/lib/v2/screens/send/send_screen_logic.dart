import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

enum AmountStatus { valid, negative, zero, belowMinimum, insufficientBalance }

class SendScreenLogic {
  /// Smallest amount any send may move: one wormhole leaf quantum (0.01 token).
  /// A recipient can be a wormhole address, and anything below the quantum is
  /// committed as a zero-value leaf there — so it is rejected on the way in
  /// rather than at proving time. Sits above the existential deposit.
  static BigInt get minimumSendAmount => wormholeScaleFactor;

  static bool _isSelfTransfer(String recipient, String activeAccountId) {
    return recipient.isNotEmpty && recipient == activeAccountId;
  }

  static AmountStatus getAmountStatus(BigInt amount, BigInt balance, BigInt networkFee) {
    if (amount < BigInt.zero) return AmountStatus.negative;
    if (amount == BigInt.zero) return AmountStatus.zero;
    if (amount < minimumSendAmount) return AmountStatus.belowMinimum;
    if ((amount + networkFee) > balance) return AmountStatus.insufficientBalance;
    return AmountStatus.valid;
  }

  static bool hasAmountError({required BigInt amount, required BigInt balance, required BigInt networkFee}) {
    final status = getAmountStatus(amount, balance, networkFee);
    return status == AmountStatus.belowMinimum ||
        status == AmountStatus.insufficientBalance ||
        status == AmountStatus.negative;
  }

  static bool isButtonDisabled({
    required bool hasAddressError,
    required AmountStatus amountStatus,
    required String recipientText,
    required String activeAccountId,
  }) {
    final isSelfTransfer = _isSelfTransfer(recipientText, activeAccountId);
    final amountIsValid = amountStatus == AmountStatus.valid;

    return hasAddressError || !amountIsValid || recipientText.isEmpty || isSelfTransfer;
  }

  static String getButtonText({
    required AppLocalizations l10n,
    required bool hasAddressError,
    required AmountStatus amountStatus,
    required String recipientText,
    required BigInt amount,
    required String activeAccountId,
    required NumberFormattingService formattingService,
  }) {
    if (hasAddressError || recipientText.isEmpty) return l10n.sendEnterAddress;
    if (_isSelfTransfer(recipientText, activeAccountId)) return l10n.sendLogicCantSelfTransfer;

    switch (amountStatus) {
      case AmountStatus.zero:
        return l10n.sendLogicEnterAmount;
      case AmountStatus.negative:
        return l10n.sendLogicInvalidAmount;
      case AmountStatus.belowMinimum:
        return l10n.sendLogicBelowMinimum(formattingService.formatAmount(minimumSendAmount), AppConstants.tokenSymbol);
      case AmountStatus.insufficientBalance:
        return l10n.sendLogicInsufficientBalance;
      case AmountStatus.valid:
        return l10n.sendLogicReviewSend;
    }
  }

  static BigInt calculateMaxSendableAmount({required BigInt balance, required BigInt networkFee}) {
    final maxSendable = balance - networkFee;
    return maxSendable > BigInt.zero ? maxSendable : BigInt.zero;
  }

  static ReversibleTimeComponents getReversibleTimeComponents(int seconds) {
    final days = seconds ~/ 86400;
    final hours = (seconds % 86400) ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;

    return ReversibleTimeComponents(days: days, hours: hours, minutes: minutes);
  }

  static String formatReversibleTime(int seconds) {
    final components = getReversibleTimeComponents(seconds);

    if (components.days > 0) {
      return '${components.days}d, ${components.hours}h, ${components.minutes}m';
    } else if (components.hours > 0) {
      return '${components.hours}h, ${components.minutes}m';
    } else {
      return '${components.minutes}m';
    }
  }

  static bool isReversible(int reversibleTimeSeconds) {
    return reversibleTimeSeconds > 0;
  }
}

/// Data class for reversible time components
class ReversibleTimeComponents {
  final int days;
  final int hours;
  final int minutes;

  const ReversibleTimeComponents({required this.days, required this.hours, required this.minutes});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReversibleTimeComponents &&
          runtimeType == other.runtimeType &&
          days == other.days &&
          hours == other.hours &&
          minutes == other.minutes;

  @override
  int get hashCode => days.hashCode ^ hours.hashCode ^ minutes.hashCode;
}
