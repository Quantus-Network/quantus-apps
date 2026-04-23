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
import 'package:resonance_network_wallet/v2/components/glass_icon_button.dart';
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
  final FocusNode _accountNameFocus = FocusNode();
  String? _accountNameError;
  bool _isEditingName = false;

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

  void _toggleEditName() {
    setState(() {
      _isEditingName = !_isEditingName;
      if (_isEditingName) {
        _accountNameError = null;
      } else {
        final v = _accountName.text.trim();
        if (v.isEmpty) {
          _accountNameError = "Name can't be empty";
          _isEditingName = true;
        }
      }
    });
    if (_isEditingName) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _accountNameFocus.requestFocus());
    } else {
      _accountNameFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _accountName.dispose();
    _accountNameFocus.dispose();
    super.dispose();
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
                    isLoading: _isLoading,
                    actionIcon: _isEditingName ? Icons.check : Icons.edit_outlined,
                    onAction: _toggleEditName,
                    child: TextField(
                      controller: _accountName,
                      focusNode: _accountNameFocus,
                      readOnly: !_isEditingName,
                      style: text.smallParagraph?.copyWith(color: colors.textPrimary),
                      cursorColor: colors.textPrimary,
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onTap: () {
                        if (!_isEditingName) _toggleEditName();
                      },
                      onSubmitted: (_) {
                        if (_isEditingName) _toggleEditName();
                      },
                    ),
                  ),
                  if (_accountNameError != null) ...[
                    const SizedBox(height: 6),
                    Text(_accountNameError!, style: text.detail?.copyWith(color: colors.accentPink)),
                  ],
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
                    actionIcon: Icons.copy_outlined,
                    onAction: () => context.copyTextWithToaster(_address),
                  ),
                  const SizedBox(height: 24),
                  _Field(
                    label: 'Wallet Checkphrase',
                    value: _isLoading ? '...' : _checksum,
                    isLoading: _isLoading,
                    valueColor: colors.accentPink,
                    actionIcon: Icons.copy_outlined,
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
}

class _Field extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? child;
  final bool isLoading;
  final Color? valueColor;
  final IconData actionIcon;
  final VoidCallback onAction;

  const _Field({
    required this.label,
    this.value,
    this.child,
    required this.isLoading,
    this.valueColor,
    required this.actionIcon,
    required this.onAction,
  }) : assert(value != null || child != null, 'Provide value or child');

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
                child:
                    child ??
                    Text(
                      value!,
                      style: text.smallParagraph?.copyWith(color: valueColor ?? colors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: GlassIconButton.rounded(radius: 8, icon: actionIcon, onTap: isLoading ? null : onAction),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
