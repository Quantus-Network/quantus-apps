import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/gradient_action_button.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';

class ImportWalletScreen extends ConsumerStatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  ImportWalletScreenState createState() => ImportWalletScreenState();
}

class ImportWalletScreenState extends ConsumerState<ImportWalletScreen> {
  final TextEditingController _mnemonicController = TextEditingController();
  bool _isLoading = false;
  bool _isDiscovering = false;
  String _errorMessage = '';
  final SettingsService _settingsService = SettingsService();
  final AccountsService _accountsService = AccountsService();
  final AccountDiscoveryService _accountDiscoveryService =
      AccountDiscoveryService(HdWalletService(), SubstrateService());

  Future<void> _discoverAccounts(String mnemonic) async {
    if (!mounted) return;
    setState(() {
      _isDiscovering = true;
    });

    try {
      final discoveredAccounts = await _accountDiscoveryService
          .discoverAccounts(mnemonic: mnemonic);

      for (final account in discoveredAccounts) {
        await _accountsService.addAccount(account);
      }
      ref.invalidate(accountsProvider);
    } catch (e) {
      debugPrint('Error discovering accounts: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDiscovering = false;
        });
      }
    }
  }

  Future<void> _importWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final mnemonic = _mnemonicController.text.trim();

      // Check if it's a derivation path
      if (mnemonic.startsWith('//')) {
        // No validation needed for derivation paths
        debugPrint('Using derivation path: $mnemonic');
      } else {
        // Validate mnemonic
        final words = mnemonic
            .split(' ')
            .where((word) => word.isNotEmpty)
            .toList();
        if (words.length != 12 && words.length != 24) {
          throw Exception('Mnemonic must be 12 or 24 words');
        }
      }

      final key = HdWalletService().keyPairAtIndex(mnemonic, 0);
      await _settingsService.setMnemonic(mnemonic);
      await _accountsService.addAccount(
        Account(index: 0, name: 'Account 1', accountId: key.ss58Address),
      );

      await _discoverAccounts(mnemonic);

      if (context.mounted && mounted) {
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
      setState(() {
        _errorMessage = e.toString();
      });
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
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const WalletAppBar(title: 'Import Wallet'),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Text('Import Wallet', style: context.themeText.smallTitle),
                const SizedBox(height: 13),
                Text(
                  'Restore an existing wallet with your 12 or 24 word '
                  'recovery phrase',
                  style: context.themeText.smallParagraph?.copyWith(
                    color: context.themeColors.textMuted,
                  ),
                ),
                const SizedBox(height: 21),
                Expanded(
                  child: TextField(
                    controller: _mnemonicController,
                    style: context.themeText.smallParagraph,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: context.themeColors.surface,
                      contentPadding: const EdgeInsets.all(13),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: context.themeColors.border,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          width: 1,
                          color: context.themeColors.border,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: context.themeColors.border,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      hintText:
                          'Type in or paste your recovery phrase. Separate'
                          ' words with spaces',
                      hintStyle: context.themeText.smallParagraph?.copyWith(
                        color: context.themeColors.textMuted,
                      ),
                    ),
                    maxLines: null,
                    minLines: 8,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.done,
                  ),
                ),

                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: 8.0,
                      bottom: 8.0,
                    ), // Added bottom padding
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const Spacer(), // Add Spacer to push the button down
                if (_isDiscovering)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 50.0),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 16),
                        Text(
                          'Discovering existing accounts...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  )
                else
                  GradientActionButton(
                    label: 'Import Wallet',
                    onPressed: _importWallet,
                    isLoading: _isLoading,
                  ),
                const SizedBox(
                  height: 24,
                ), // Consistent bottom padding like CreateWalletScreen
              ],
            ),
          ),
        ),
      ),
    );
  }
}
