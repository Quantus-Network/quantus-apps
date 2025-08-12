import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/gradient_action_button.dart';
import 'package:resonance_network_wallet/features/components/mnemonic_grid.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';

class CreateWalletAndBackupScreen extends StatefulWidget {
  const CreateWalletAndBackupScreen({super.key});

  @override
  CreateWalletAndBackupScreenState createState() =>
      CreateWalletAndBackupScreenState();
}

class CreateWalletAndBackupScreenState
    extends State<CreateWalletAndBackupScreen> {
  String _mnemonic = '';
  bool _isLoading = true;
  bool _hasSavedMnemonic = false;
  String? _error;
  final SettingsService _settingsService = SettingsService();
  final TelemetryService _telemetry = TelemetryService();

  @override
  void initState() {
    super.initState();
    _generateMnemonic();
  }

  Future<void> _generateMnemonic() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _mnemonic = await SubstrateService().generateMnemonic();
      if (_mnemonic.isEmpty) {
        throw Exception('Mnemonic generation returned empty.');
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating mnemonic: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to generate recovery phrase: $e';
        });
      }
    }
  }

  Future<void> _saveWalletAndContinue() async {
    if (_mnemonic.isEmpty) {
      debugPrint('Cannot save wallet, mnemonic is empty.');
      if (mounted) {
        showTopSnackBar(
          context,
          title: 'Error',
          message: 'Recovery phrase not generated.',
        );
      }
      return;
    }

    try {
      await _settingsService.setMnemonic(_mnemonic);
      final accounts = await _settingsService.getAccounts();
      if (accounts.isEmpty) {
        final key = HdWalletService().keyPairAtIndex(_mnemonic, 0);
        await _settingsService.addAccount(
          Account(index: 0, name: 'Account 1', accountId: key.ss58Address),
        );
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'navbar'),
            builder: (context) => const Navbar(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error saving wallet: $e');
      if (mounted) {
        showTopSnackBar(
          context,
          title: 'Error',
          message: 'Error saving wallet: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> words = _mnemonic.isNotEmpty ? _mnemonic.split(' ') : [];

    final bool canContinue = _hasSavedMnemonic && !_isLoading && _error == null;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const WalletAppBar(title: 'Create Wallet'),
      backgroundColor: context.themeColors.background,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/light_leak_effect_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Your Secret Recovery Phrase',
                          textAlign: TextAlign.center,
                          style: context.themeText.smallTitle,
                        ),
                        const SizedBox(height: 13),
                        Text(
                          'Write down and save your seed phrase in a secure '
                          'location. This is the only way to recover your '
                          'wallet',
                          textAlign: TextAlign.center,
                          style: context.themeText.smallParagraph?.copyWith(
                            color: context.themeColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 21),
                        if (_isLoading)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 50.0),
                            child: Column(
                              children: [
                                CircularProgressIndicator(
                                  color: context.themeColors.circularLoader,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Generating secure phrase...',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        else if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 50.0,
                              horizontal: 20,
                            ),
                            child: Text(
                              _error!,
                              style: context.themeText.paragraph?.copyWith(
                                color: context.themeColors.textError,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          MnemonicGrid(words: words),
                        const SizedBox(height: 21),
                        if (!_isLoading && _error == null)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _mnemonic));
                              showTopSnackBar(
                                context,
                                title: 'Copied!',
                                message: 'Recovery phrase copied to clipboard',
                              );
                              _telemetry.sendEvent(
                                'onboarding_copy_recovery_phrase',
                              );
                            },
                            child: Opacity(
                              opacity: 0.8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.copy,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Copy to Clipboard',
                                    style: context.themeText.smallParagraph,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 35),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    children: [
                      CheckboxListTile(
                        contentPadding: const EdgeInsets.all(0),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(
                          'I have copied and stored my seed phrase',
                          style: context.themeText.smallParagraph,
                        ),
                        value: _hasSavedMnemonic,
                        onChanged: _isLoading
                            ? null
                            : (value) {
                                setState(() {
                                  _hasSavedMnemonic = value ?? false;
                                });
                              },
                        activeColor: const Color(0xFF8AF9A8),
                        checkColor: const Color(0xFF8AF9A8),
                        side: WidgetStateBorderSide.resolveWith((states) {
                          return const BorderSide(
                            width: 1,
                            color: Colors.white,
                          );
                        }),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const SizedBox(height: 17),
                      if (canContinue)
                        GradientActionButton(
                          label: 'Continue',
                          textStyle: context.themeText.smallTitle,
                          onPressed: _saveWalletAndContinue,
                          isLoading: _isLoading,
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              backgroundColor: Colors.grey[400],
                              minimumSize: const Size(double.infinity, 50),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                            ),
                            onPressed: null,
                            child: Text(
                              'Continue',
                              style: context.themeText.smallTitle?.copyWith(
                                color: context.themeColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
