import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/card_info.dart';
import 'package:resonance_network_wallet/features/components/mnemonic_grid.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';

class CreateWalletAndBackupScreen extends ConsumerStatefulWidget {
  const CreateWalletAndBackupScreen({super.key});

  @override
  CreateWalletAndBackupScreenState createState() =>
      CreateWalletAndBackupScreenState();
}

class CreateWalletAndBackupScreenState
    extends ConsumerState<CreateWalletAndBackupScreen> {
  String _mnemonic = '';
  bool _isLoading = true;
  bool _isEditing = false;
  String? _error;

  final SettingsService _settingsService = SettingsService();
  final AccountsService _accountsService = AccountsService();
  final HdWalletService _hdWalletService = HdWalletService();

  final _accountName = TextEditingController();
  late List<Account> _accounts;
  late String _address;
  late String _checksum;

  @override
  void initState() {
    super.initState();

    _generateMnemonic();
    _accounts = _settingsService.getAccounts();
    _accountName.text = 'Account ${_accounts.length + 1}';
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

      _address = _hdWalletService
          .keyPairAtIndex(_mnemonic, _accounts.length)
          .ss58Address;
      _checksum = await HumanReadableChecksumService().getHumanReadableName(
        _address,
      );

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
      if (_accounts.isEmpty) {
        await _accountsService.addAccount(
          Account(index: 0, name: _accountName.value.text, accountId: _address),
        );
      }
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);

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

    final bool canContinue = !_isLoading && _error == null;

    return ScaffoldBase(
      appBar: 'Create New Wallet',
      decorations: [
        const Positioned(
          right: -32.0,
          bottom: 120.0,
          child: Sphere(variant: 1, size: 321.0),
        ),
      ],
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 25.0),
                Focus(
                  child: CustomTextField(
                    controller: _accountName,
                    labelText: 'ACCOUNT NAME',
                    icon: !_isEditing ? const Icon(Icons.edit) : null,
                  ),
                  onFocusChange: (value) {
                    setState(() {
                      _isEditing = value;
                    });
                  },
                ),
                const SizedBox(height: 25.0),
                CardInfo(
                  text: _isLoading ? 'Loading checksum...' : _checksum,
                  icon: const Icon(Icons.info_outline),
                  label: 'ACCOUNT CHECKPHRASE',
                  onPressed: () {},
                  textColor: context.themeColors.checksumDarker,
                ),
                const SizedBox(height: 25.0),
                CardInfo(
                  text: _isLoading
                      ? 'Loading address...'
                      : AddressFormattingService.splitIntoChunks(
                          _address,
                        ).join(' '),
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    ClipboardExtensions.copyTextWithSnackbar(context, _address);
                  },
                  label: 'ACCOUNT ADDRESS',
                ),
                const SizedBox(height: 25.0),
                CardInfo(
                  text: 'Show Recovery Phrase',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    showRecoveryPhraseSheet(
                      context,
                      words,
                      _isLoading,
                      _error,
                      _mnemonic,
                    );
                  },
                ),
                const SizedBox(height: 32),
                Button(
                  variant: ButtonVariant.primary,
                  label: 'Create Wallet',
                  textStyle: context.themeText.smallTitle,
                  onPressed: _saveWalletAndContinue,
                  isLoading: _isLoading,
                  isDisabled: !canContinue,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function to show the recovery phrase sheet
void showRecoveryPhraseSheet(
  BuildContext context,
  List<String> words,
  bool isLoading,
  String? error,
  String mnemonic,
) {
  final TelemetryService telemetry = TelemetryService();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width, // Ensure full width
    ),
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black,
                  const Color(0xFF312E6E).useOpacity(0.4),
                  Colors.black,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Stack(
              children: [
                BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                  child: Container(color: Colors.black.useOpacity(0.3)),
                ),
                Container(
                  height: MediaQuery.of(context).size.height * 0.75,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 20,
                  ),
                  decoration: const BoxDecoration(color: Colors.black),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              size: context.themeSize.overlayCloseIconSize,
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      Text(
                        'Your Secret Recovery Phrase',
                        textAlign: TextAlign.start,
                        style: context.themeText.smallTitle,
                      ),
                      const SizedBox(height: 13),
                      Text(
                        'Write down and save your seed phrase in a secure '
                        'location. This is the only way to recover your '
                        'wallet',
                        textAlign: TextAlign.start,
                        style: context.themeText.smallParagraph?.copyWith(
                          color: context.themeColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 21),
                      if (isLoading)
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
                      else if (error != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 50.0,
                            horizontal: 20,
                          ),
                          child: Text(
                            error,
                            style: context.themeText.paragraph?.copyWith(
                              color: context.themeColors.textError,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        MnemonicGrid(words: words),
                      const SizedBox(height: 8),
                      if (!isLoading && error == null)
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: mnemonic));
                              showTopSnackBar(
                                context,
                                title: 'Copied!',
                                message: 'Recovery phrase copied to clipboard',
                              );
                              telemetry.sendEvent(
                                'onboarding_copy_recovery_phrase',
                              );
                            },
                            child: Opacity(
                              opacity: 0.8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
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
                        ),
                      const SizedBox(height: 35),
                      Button(
                        label: 'Close',
                        variant: ButtonVariant.neutral,
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
