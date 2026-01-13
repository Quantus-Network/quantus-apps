import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/gradient_text.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/steps.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/high_security_summary_wizard.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/safeguard_window_picker_sheet.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/high_security_form_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class HighSecuritySafeguardWindowWizard extends ConsumerStatefulWidget {
  final Account account;
  const HighSecuritySafeguardWindowWizard({super.key, required this.account});

  @override
  ConsumerState<HighSecuritySafeguardWindowWizard> createState() => _HighSecuritySafeguardWindowWizardState();
}

class _HighSecuritySafeguardWindowWizardState extends ConsumerState<HighSecuritySafeguardWindowWizard> {
  @override
  Widget build(BuildContext context) {
    final formNotifier = ref.read(highSecurityFormProvider.notifier);
    final safeguardTimeSeconds = ref.watch(highSecurityFormProvider).safeguardWindow.inSeconds;

    final int secondsInADay = 86400;
    final int secondsInAMonth = secondsInADay * 30; // 86400 seconds/day * 30 days/month

    /// This is an approximation.
    final int safeguardTimeMonths = safeguardTimeSeconds ~/ secondsInAMonth;
    final int safeguardTimeDays = (safeguardTimeSeconds % secondsInAMonth) ~/ secondsInADay;
    final int safeguardTimeHours = (safeguardTimeSeconds % secondsInADay) ~/ 3600;

    final bool isDisabled = safeguardTimeSeconds == 0;

    return ScaffoldBase(
      appBar: WalletAppBar.simpleWithBackButton(title: 'Safeguard Window'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 36),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 204,
                child: StepsIndicator(currentStep: 2, totalSteps: AppConstants.highSecurityStepsCount),
              ),
            ],
          ),
          const SizedBox(height: 32),
          GradientText.highSecurity('SAFEGUARD WINDOW', context),
          const SizedBox(height: 4),
          Text(
            'The time window in which the Guardian  can deny or intercept a transaction.',
            style: context.themeText.smallParagraph,
          ),
          const SizedBox(height: 38),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text('Safeguard Window', style: context.themeText.largeTag)],
          ),
          const SizedBox(height: 4),
          Text(
            'Set how long the Guardian account has to act once a transaction is initiated.',
            style: context.themeText.smallParagraph,
          ),
          const SizedBox(height: 13),
          GestureDetector(
            onTap: () {
              showSafeguardWindowPickerSheet(
                context,
                safeguardTimeMonths: safeguardTimeMonths,
                safeguardTimeDays: safeguardTimeDays,
                safeguardTimeHours: safeguardTimeHours,
                setSafeguardTimeSeconds: formNotifier.updateSafeguardWindow,
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: ShapeDecoration(
                color: const Color(0xFF313131),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    DatetimeFormattingService.formatSafeguardTime(
                      safeguardTimeMonths,
                      safeguardTimeDays,
                      safeguardTimeHours,
                    ),
                    style: context.themeText.smallParagraph,
                  ),
                  Icon(Icons.edit, color: Colors.white70, size: context.isTablet ? 22 : 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 13),
          Text(
            'Allow a reasonable window for your Guardian account to respond in an emergency.',
            style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.textMuted),
          ),
          const Expanded(child: SizedBox()),
          Row(
            spacing: 36,
            children: [
              Expanded(
                child: Button(
                  label: 'Back',
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ),
              Expanded(
                child: Button(
                  isDisabled: isDisabled,
                  variant: ButtonVariant.neutral,
                  label: 'Next',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => HighSecuritySummaryWizard(account: widget.account)),
                    );
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }
}
