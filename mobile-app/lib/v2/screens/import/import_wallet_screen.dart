import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/v2/components/glass_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
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
  final _focusNode = FocusNode();
  final _buttonKey = GlobalKey();
  final _settingsService = SettingsService();
  final _accountsService = AccountsService();
  final _discoveryService = AccountDiscoveryService(HdWalletService(), SubstrateService());
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_revealButton);
  }

  void _revealButton() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = _buttonKey.currentContext;
        if (mounted && ctx != null) {
          // ignore: use_build_context_synchronously
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
  }

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

      if (!HdWalletService.isDevAccount(mnemonic)) {
        await _discoverAccounts(mnemonic);
      }
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
      _settingsService.setReferralCheckCompleted();
      _settingsService.setExistingUserSeenPromoVideo();

      if (ref.read(remoteConfigProvider).enableRemoteNotifications) {
        ref.read(firebaseMessagingServiceProvider).registerDeviceIfPossible();
      }

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
    return ScaffoldBase(
      appBar: V2AppBar(
        title: 'Import Wallet',
        trailing: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.close, color: colors.textPrimary, size: 24),
        ),
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                'Restore an existing wallet with your 24 word recovery phrase',
                textAlign: TextAlign.center,
                style: textSTyleSmallTitle,
              ),
              const SizedBox(height: 24),
              Container(
                height: 202,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
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
              const SizedBox(height: 24),
              GlassButton.simple(
                key: _buttonKey,
                label: 'Import Wallet',
                onTap: _import,
                isLoading: _isLoading,
                variant: ButtonVariant.secondary,
                isDisabled: !_hasInput,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_revealButton);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}
