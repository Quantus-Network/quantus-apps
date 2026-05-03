import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/services/logout_service.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_caution_scaffold.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_divider.dart';

class ResetConfirmationScreen extends ConsumerStatefulWidget {
  const ResetConfirmationScreen({super.key});

  @override
  ConsumerState<ResetConfirmationScreen> createState() => _ResetConfirmationScreenState();
}

class _ResetConfirmationScreenState extends ConsumerState<ResetConfirmationScreen> {
  bool _backedUpChecked = false;
  bool _isResetting = false;

  Future<void> _resetAndClearData() async {
    setState(() => _isResetting = true);

    final authed = await LocalAuthService().authenticate(localizedReason: 'Authenticate to reset wallet');

    if (authed && mounted) {
      try {
        await ref.read(logoutServiceProvider).logout(context);
      } catch (e) {
        if (mounted) {
          context.showErrorToaster(message: 'Failed to reset wallet: $e');
        }
        setState(() => _isResetting = false);
      }
    } else if (mounted) {
      context.showErrorToaster(message: 'Authentication required to reset wallet');

      setState(() => _isResetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsCautionScaffold(
      appBarTitle: 'Reset Wallet',
      data: const SettingsCautionScaffoldData.walletReset(),
      betweenBulletsStyle: SettingsDividerStyle.sectionEmphasis,
      checkboxChecked: _backedUpChecked,
      onCheckboxChanged: () => setState(() => _backedUpChecked = !_backedUpChecked),
      onContinue: _resetAndClearData,
      continueButtonLoading: _isResetting,
    );
  }
}
