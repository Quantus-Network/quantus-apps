import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ImportWalletScreenV2 extends ConsumerStatefulWidget {
  const ImportWalletScreenV2({super.key, this.walletIndex = 0});

  final int walletIndex;

  @override
  ConsumerState<ImportWalletScreenV2> createState() => _ImportWalletScreenV2State();
}

class _ImportWalletScreenV2State extends ConsumerState<ImportWalletScreenV2> {
  final _controller = TextEditingController();
  final _settingsService = SettingsService();
  final _accountsService = AccountsService();
  final _discoveryService = AccountDiscoveryService(HdWalletService(), SubstrateService());
  bool _isLoading = false;
  String? _error;

  bool get _hasInput => _controller.text.trim().isNotEmpty;

  Future<void> _import() async {
    final mnemonic = _controller.text.trim();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (!mnemonic.startsWith('//')) {
        final words = mnemonic.split(' ').where((w) => w.isNotEmpty).toList();
        if (words.length != 12 && words.length != 24) {
          throw Exception('Recovery phrase must be 12 or 24 words');
        }
      }

      final key = HdWalletService().keyPairAtIndex(mnemonic, 0);
      await _settingsService.setMnemonic(mnemonic, widget.walletIndex);
      await _accountsService.addAccount(
        Account(walletIndex: widget.walletIndex, index: 0, name: 'Account 1', accountId: key.ss58Address),
      );

      await _discoverAccounts(mnemonic);
      _settingsService.setReferralCheckCompleted();
      _settingsService.setExistingUserSeenPromoVideo();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _discoverAccounts(String mnemonic) async {
    try {
      final discovered = await _discoveryService.discoverAccounts(mnemonic: mnemonic, walletIndex: widget.walletIndex);
      final existing = (await _accountsService.getAccounts()).map((e) => e.accountId).toSet();
      for (final account in discovered) {
        if (!existing.contains(account.accountId)) {
          await _accountsService.addAccount(account);
        }
      }
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    var textSTyleSmallTitle = text.smallTitle?.copyWith(
      fontSize: 20,
      color: colors.textPrimary,
      fontWeight: FontWeight.w400,
      height: 1.35,
    );
    return Scaffold(
      backgroundColor: colors.background,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppBackButton(),
                    Text('Import Wallet', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close, color: colors.textPrimary, size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 80),
                Text(
                  'Restore an existing wallet with your 24 word recovery phrase',
                  textAlign: TextAlign.center,
                  style: textSTyleSmallTitle,
                ),
                const SizedBox(height: 64),
                Container(
                  height: 202,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: _controller,
                    onChanged: (_) => setState(() {}),
                    style: textSTyleSmallTitle,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Type in or paste your recovery phrase. Separate words with spaces.',
                      hintStyle: textSTyleSmallTitle?.copyWith(color: colors.textSecondary),
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.done,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: text.detail?.copyWith(color: colors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const Spacer(),
                Opacity(
                  opacity: _hasInput ? 1.0 : 0.2,
                  child: GlassContainer(
                    asset: GlassContainer.wideAsset,
                    onTap: _hasInput && !_isLoading ? _import : null,
                    child: _isLoading
                        ? Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: colors.textPrimary),
                            ),
                          )
                        : Center(
                            child: Text(
                              'Import Wallet',
                              style: text.paragraph?.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: colors.textPrimary,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
