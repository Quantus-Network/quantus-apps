import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/glass_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/create/recovery_phrase_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/home/home_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class WalletReadyScreenV2 extends ConsumerStatefulWidget {
  const WalletReadyScreenV2({super.key, this.walletIndex = 0});

  final int walletIndex;

  @override
  ConsumerState<WalletReadyScreenV2> createState() => _WalletReadyScreenV2State();
}

class _WalletReadyScreenV2State extends ConsumerState<WalletReadyScreenV2> {
  String _mnemonic = '';
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  final SettingsService _settingsService = SettingsService();
  final AccountsService _accountsService = AccountsService();
  final HdWalletService _hdWalletService = HdWalletService();
  final ReferralService _referralService = ReferralService();

  final _accountName = TextEditingController();
  String? _accountNameError;

  late String _address;
  late String _checksum;

  @override
  void initState() {
    super.initState();
    _accountName.text = 'Account 1';
    _generateMnemonic();
  }

  Future<void> _generateMnemonic() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      _mnemonic = await SubstrateService().generateMnemonic();
      if (_mnemonic.isEmpty) throw Exception('Mnemonic generation returned empty.');

      _address = _hdWalletService.keyPairAtIndex(_mnemonic, 0).ss58Address;
      _checksum = await HumanReadableChecksumService().getHumanReadableName(_address);

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to generate: $e';
        });
      }
    }
  }

  Future<void> _continue() async {
    if (_mnemonic.isEmpty || _accountNameError != null) return;

    setState(() => _isSubmitting = true);
    try {
      await _settingsService.setMnemonic(_mnemonic, widget.walletIndex);

      final accounts = ref.read(accountsProvider).value ?? <Account>[];
      final hasRoot = accounts.any((a) => a.walletIndex == widget.walletIndex && a.index == 0);
      if (!hasRoot) {
        await _accountsService.addAccount(
          Account(walletIndex: widget.walletIndex, index: 0, name: _accountName.text.trim(), accountId: _address),
        );
        try {
          _referralService.submitAddressToBackend();
        } catch (_) {}
      }
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);

      if (ref.read(remoteConfigProvider).enableRemoteNotifications) {
        ref.read(firebaseMessagingServiceProvider).registerDeviceIfPossible();
      }

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (route) => false);
    } catch (e) {
      if (mounted) context.showErrorToaster(message: 'Error saving wallet: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final canContinue = !_isLoading && _error == null && _accountNameError == null;

    return ScaffoldBase(
      appBar: V2AppBar(
        title: 'Your Wallet Is Ready',
        trailing: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.close, color: colors.textPrimary, size: 24),
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Field(
                    label: 'Wallet Name',
                    value: _accountName.text,
                    isLoading: _isLoading,
                    actionIcon: Icons.edit,
                    onAction: () => _showEditNameSheet(colors, text),
                  ),
                  const SizedBox(height: 24),
                  _Field(
                    label: 'Wallet Address',
                    value: _isLoading
                        ? '...'
                        : AddressFormattingService.formatAddress(
                            _address,
                            prefix: 15,
                            ellipses: '.......',
                            postFix: 14,
                          ),
                    isLoading: _isLoading,
                    actionIcon: Icons.copy,
                    onAction: () => context.copyTextWithToaster(_address),
                  ),
                  const SizedBox(height: 24),
                  _Field(
                    label: 'Wallet Checkphrase',
                    value: _isLoading ? '...' : _checksum,
                    isLoading: _isLoading,
                    valueColor: colors.accentPink,
                    actionIcon: Icons.copy,
                    onAction: () => context.copyTextWithToaster(_checksum, message: 'Checkphrase copied'),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      final words = _mnemonic.isNotEmpty ? _mnemonic.split(' ') : <String>[];
                      showRecoveryPhraseSheet(context, words, _isLoading, _error, _mnemonic);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility_outlined, size: 16, color: colors.textSecondary),
                        const SizedBox(width: 8),
                        Text('View recovery phrase', style: text.detail?.copyWith(color: colors.textSecondary)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          GlassButton.simple(
            label: 'Continue',
            onTap: _continue,
            isLoading: _isSubmitting,
            variant: ButtonVariant.secondary,
            isDisabled: !canContinue,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showEditNameSheet(AppColorsV2 colors, AppTextTheme text) {
    final controller = TextEditingController(text: _accountName.text);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Wallet Name', style: text.smallTitle?.copyWith(color: colors.textPrimary)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              style: text.paragraph?.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                filled: true,
                fillColor: colors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 24),
            GlassButton.simple(
              label: 'Save',
              onTap: () async {
                final v = controller.text.trim();
                if (v.isNotEmpty) {
                  setState(() {
                    _accountName.text = v;
                    _accountNameError = null;
                  });
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final bool isLoading;
  final Color? valueColor;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _Field({
    required this.label,
    required this.value,
    required this.isLoading,
    this.valueColor,
    required this.actionIcon,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(left: 12, right: 8, top: 8, bottom: 8),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: text.smallParagraph?.copyWith(color: valueColor ?? colors.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: GlassButton(
                  width: 40,
                  padding: EdgeInsets.zero,
                  onTap: isLoading ? null : onAction,
                  child: Icon(actionIcon, size: 20, color: colors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
