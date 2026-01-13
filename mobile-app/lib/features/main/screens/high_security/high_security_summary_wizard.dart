import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/gradient_text.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/steps.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/high_security_confirmation_sheet.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/high_security_form_provider.dart';

class HighSecuritySummaryWizard extends ConsumerStatefulWidget {
  final Account account;
  const HighSecuritySummaryWizard({super.key, required this.account});

  @override
  ConsumerState<HighSecuritySummaryWizard> createState() => _HighSecuritySummaryWizardState();
}

class _HighSecuritySummaryWizardState extends ConsumerState<HighSecuritySummaryWizard> {
  final HumanReadableChecksumService _humanReadableChecksumService = HumanReadableChecksumService();

  @override
  Widget build(BuildContext context) {
    final formData = ref.read(highSecurityFormProvider);

    final guardianChecksumFuture = _humanReadableChecksumService.getHumanReadableName(formData.guardianAccountId);
    final accountChecksumFuture = _humanReadableChecksumService.getHumanReadableName(widget.account.accountId);

    return ScaffoldBase(
      appBar: WalletAppBar.simpleWithBackButton(title: 'Summary'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 36),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 204,
                child: StepsIndicator(currentStep: 3, totalSteps: AppConstants.highSecurityStepsCount),
              ),
            ],
          ),
          const SizedBox(height: 32),
          GradientText.highSecurity('SUMMARY', context),
          const SizedBox(height: 19),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 4,
            children: [
              Text('HIGH SECURITY ACCOUNT:', style: context.themeText.detail),
              Text(widget.account.name, style: context.themeText.smallTitle),
              FutureBuilder<String>(
                future: accountChecksumFuture,
                builder: (context, snapshot) {
                  return Text(
                    snapshot.data ?? 'Loading...',
                    style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.checksumDarker),
                  );
                },
              ),
              SizedBox(
                width: 220,
                child: Text(
                  AddressFormattingService.splitIntoChunks(widget.account.accountId).join(' '),
                  style: context.themeText.detail?.copyWith(color: Colors.white.useOpacity(0.6000000238418579)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 19),
          SummaryCard(
            type: SummaryType.guardian,
            checksumFuture: guardianChecksumFuture,
            address: AddressFormattingService.splitIntoChunks(formData.guardianAccountId).join(' '),
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
                  variant: ButtonVariant.neutral,
                  label: 'Next',
                  onPressed: () {
                    showHighSecurityConfirmationSheet(context, widget.account);
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

enum SummaryType { guardian, recovery }

class SummaryCard extends StatelessWidget {
  final SummaryType type;
  final Future<String> checksumFuture;
  final String address;

  const SummaryCard({super.key, required this.type, required this.checksumFuture, required this.address});

  @override
  Widget build(BuildContext context) {
    final String label = type == SummaryType.guardian ? 'GUARDIAN ACCOUNT:' : 'RECOVERY ACCOUNT:';
    final Color checksumColor = type == SummaryType.guardian
        ? context.themeColors.yellow
        : context.themeColors.buttonDanger;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: const Color(0x99313131),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 2,
        children: [
          Text(label, style: context.themeText.detail),
          FutureBuilder(
            future: checksumFuture,
            builder: (context, snapshot) {
              String text = 'Loading checksum...';

              if (snapshot.error != null) {
                text = 'Failed loading checksum: ${snapshot.error}';
              } else if (snapshot.hasData) {
                text = snapshot.data!;
              }

              return Text(text, style: context.themeText.smallParagraph?.copyWith(color: checksumColor));
            },
          ),
          SizedBox(
            width: 220,
            child: Text(
              address,
              style: context.themeText.detail?.copyWith(color: Colors.white.useOpacity(0.6000000238418579)),
            ),
          ),
        ],
      ),
    );
  }
}
