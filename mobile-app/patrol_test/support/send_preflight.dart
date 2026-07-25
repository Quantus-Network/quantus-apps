import 'package:quantus_sdk/generated/planck/pallets/balances.dart' as balances;
import 'package:quantus_sdk/quantus_sdk.dart';

import 'e2e_locale.dart';

/// Pre-send checks for the send-flow Patrol test.
class SendPreflight {
  SendPreflight._();

  /// Throws [StateError] if the imported wallet cannot afford existential deposit + fee.
  static Future<({BigInt amount, String amountText})> assertFundedAndGetMinimalSend({
    required String recipientAddress,
  }) async {
    final ed = balances.Constants().existentialDeposit;
    final account = (await SettingsService().getActiveRegularAccount())!;
    final substrateService = SubstrateService();
    final balancesService = BalancesService();

    final balance = await substrateService.queryBalance(account.accountId);
    final feeData = await balancesService.getBalanceTransferFee(account, recipientAddress, ed);
    final required = ed + feeData.fee;

    if (balance < required) {
      throw StateError(
        'Test wallet underfunded for minimal send: '
        'balance=$balance, need>=$required (existentialDeposit=$ed + fee=${feeData.fee}). '
        'Fund TEST_IMPORT_MNEMONIC account or use a different fixture.',
      );
    }

    final localeConfig = E2eLocale.numberConfig();
    final amountText = NumberFormattingService(
      localeConfig: localeConfig,
    ).formatBalance(ed, smartDecimals: AppConstants.decimals, addThousandsSeparators: false);

    return (amount: ed, amountText: amountText);
  }
}
