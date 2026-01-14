import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/components/gradient_text.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/steps.dart';
import 'package:resonance_network_wallet/features/components/wallet_action_button.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/guardian_account_info_sheet.dart';
import 'package:resonance_network_wallet/features/main/screens/high_security/high_security_safeguard_window_wizard.dart';
import 'package:resonance_network_wallet/features/main/screens/send/qr_scanner_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/high_security_form_provider.dart';

final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();

class HighSecurityGuardianWizard extends ConsumerStatefulWidget {
  final Account account;
  const HighSecurityGuardianWizard({super.key, required this.account});

  @override
  ConsumerState<HighSecurityGuardianWizard> createState() => _HighSecurityGuardianWizardState();
}

class _HighSecurityGuardianWizardState extends ConsumerState<HighSecurityGuardianWizard> {
  late final TextEditingController _guardianController;

  // return null if the address is not valid
  Future<String?> _getHumanCheckphrase(String address) async {
    if (SubstrateService().isValidSS58Address(address)) {
      return await _checksumService.getHumanReadableName(address);
    } else {
      return null;
    }
  }

  Future<void> _scanQRCode() async {
    final formNotifier = ref.read(highSecurityFormProvider.notifier);

    final scannedAddress = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen(), fullscreenDialog: true),
    );

    if (scannedAddress != null && mounted) {
      formNotifier.updateGuardianAddress(scannedAddress);
      _guardianController.text = scannedAddress;
    }
  }

  @override
  void initState() {
    super.initState();
    _guardianController = TextEditingController(text: ref.read(highSecurityFormProvider).guardianAccountId);
  }

  @override
  void dispose() {
    _guardianController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formNotifier = ref.read(highSecurityFormProvider.notifier);
    final guardianAddress = ref.watch(highSecurityFormProvider).guardianAccountId;

    final bool isDisabled = guardianAddress.isEmpty;

    return ScaffoldBase(
      appBar: WalletAppBar.simpleWithBackButton(title: 'Theft Deterrence'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 36),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 204,
                child: StepsIndicator(currentStep: 1, totalSteps: AppConstants.highSecurityStepsCount),
              ),
            ],
          ),
          const SizedBox(height: 32),
          GradientText.highSecurity('THEFT DETERRENCE', context),
          const SizedBox(height: 4),
          Text(
            'Intercept any transaction or “pull” all funds in the case of theft.',
            style: context.themeText.smallParagraph,
          ),
          const SizedBox(height: 38),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Guardian Account', style: context.themeText.largeTag),
              InkWell(
                onTap: () {
                  showGuardianAccountInfoSheet(context);
                },
                child: const Icon(Icons.info_outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Choose an account that keeps your funds safe if your main wallet is compromised.',
            style: context.themeText.smallParagraph,
          ),
          const SizedBox(height: 13),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: () async {
                  final data = await Clipboard.getData('text/plain');
                  if (data != null && data.text != null) {
                    formNotifier.updateGuardianAddress(data.text!);
                    _guardianController.text = data.text!;
                  }
                },
                child: const WalletActionButton(assetPath: 'assets/paste_icon_1.svg'),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: _scanQRCode,
                child: const WalletActionButton(assetPath: 'assets/scan_1.svg'),
              ),
            ],
          ),
          const SizedBox(height: 13),
          CustomTextField(
            variant: TextFieldVariant.secondary,
            controller: _guardianController,
            onChanged: formNotifier.updateGuardianAddress,
            hintText: 'Enter address',
            fillColor: context.themeColors.darkGray,
          ),
          if (guardianAddress.isNotEmpty)
            FutureBuilder<String?>(
              key: ValueKey(guardianAddress),
              future: _getHumanCheckphrase(guardianAddress),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Invalid address',
                      style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.textError),
                    ),
                  );
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    snapshot.data!,
                    style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.checksum),
                  ),
                );
              },
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
                      MaterialPageRoute(
                        builder: (context) => HighSecuritySafeguardWindowWizard(account: widget.account),
                      ),
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
