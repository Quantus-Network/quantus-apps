import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/high_security_guardian_wizard.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/high_security_form_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

final highSecurityEstimatedFeeProvider = FutureProvider.family<BigInt, Account>((ref, account) async {
  final highSecurityService = ref.read(highSecurityServiceProvider);
  // Invent fake parameters for estimation
  final feeData = await highSecurityService.getHighSecuritySetupFee(
    account,
    account.accountId, // Use self as dummy guardian
    const Duration(days: 14), // Fake duration
  );
  return feeData.fee;
});

class HighSecurityGetStartedScreen extends ConsumerWidget {
  final Account account;
  const HighSecurityGetStartedScreen({super.key, required this.account});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formNotifier = ref.read(highSecurityFormProvider.notifier);
    final balanceAsync = ref.watch(balanceProviderFamily(account.accountId));
    final estimatedFeeAsync = ref.watch(highSecurityEstimatedFeeProvider(account));

    bool hasInsufficientFunds = false;
    String? formattedFee;

    if (balanceAsync.hasValue && estimatedFeeAsync.hasValue) {
      final balance = balanceAsync.value!;
      final fee = estimatedFeeAsync.value!;
      if (balance < fee) {
        hasInsufficientFunds = true;
        formattedFee = ref.read(numberFormattingServiceProvider).formatBalance(fee, addSymbol: true);
      }
    }

    final bool isLoading = balanceAsync.isLoading || estimatedFeeAsync.isLoading;
    final bool canStart = !isLoading && !hasInsufficientFunds && !balanceAsync.hasError && !estimatedFeeAsync.hasError;

    return ScaffoldBase(
      appBar: WalletAppBar.simpleWithBackButton(title: 'Security Settings'),
      child: Column(
        children: [
          const SizedBox(height: 73),
          SvgPicture.asset('assets/high_security/security_icon_big.svg', width: 140, height: 175),
          const SizedBox(height: 26),
          Text('HIGH SECURITY', style: context.themeText.largeTitle),
          const SizedBox(height: 25),
          Text(
            "Don't risk your funds!\nEnabling High Security is a great way to keep your money safe. But safety comes at the cost of convenience.",
            textAlign: TextAlign.center,
            style: context.themeText.paragraph,
          ),
          const SizedBox(height: 13),
          Text(
            'Once you enable this feature it cannot be disabled',
            textAlign: TextAlign.center,
            style: context.themeText.paragraph?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Expanded(child: SizedBox()),
          if (hasInsufficientFunds && formattedFee != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                'Insufficient funds. You need at least $formattedFee to proceed.',
                style: context.themeText.paragraph?.copyWith(color: context.themeColors.error),
                textAlign: TextAlign.center,
              ),
            ),
          Button(
            variant: ButtonVariant.neutral,
            label: 'Start',
            isDisabled: !canStart,
            isLoading: isLoading,
            onPressed: () {
              formNotifier.resetState();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => HighSecurityGuardianWizard(account: account)),
              );
            },
          ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }
}
