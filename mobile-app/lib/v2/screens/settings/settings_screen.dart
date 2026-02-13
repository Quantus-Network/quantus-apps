import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/reset_confirmation_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/v2/screens/settings/recovery_phrase_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/select_wallet_screen.dart';
import 'package:resonance_network_wallet/v2/screens/welcome/welcome_screen.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/notification_config_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/screens/settings/auto_lock_screen.dart';
import 'package:resonance_network_wallet/v2/screens/settings/change_pin_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreenV2 extends ConsumerStatefulWidget {
  const SettingsScreenV2({super.key});

  @override
  ConsumerState<SettingsScreenV2> createState() => _SettingsScreenV2State();
}

class _SettingsScreenV2State extends ConsumerState<SettingsScreenV2> {
  final _authService = LocalAuthService();
  final _settingsService = SettingsService();
  bool _biometricEnabled = false;
  String _biometricDesc = 'Face ID Disabled';
  int _autoLockMinutes = 5;
  bool _reversibleEnabled = false;
  int _reversibleTimeSeconds = 600;
  bool _hasPinSet = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPinState();
  }

  Future<void> _loadPinState() async {
    final has = await _settingsService.hasPin();
    if (mounted) setState(() => _hasPinSet = has);
  }

  Future<void> _loadSettings() async {
    final bioEnabled = _authService.isLocalAuthEnabled();
    final bioDesc = await _authService.getBiometricDescription();
    final timeout = _authService.getAuthTimeoutMinutes();
    final revTime = await _settingsService.getReversibleTimeSeconds() ?? 600;
    final revEnabled = _settingsService.isReversibleEnabled();

    if (!mounted) return;
    setState(() {
      _biometricEnabled = bioEnabled;
      _biometricDesc = bioEnabled ? bioDesc : 'Face ID Disabled';
      _autoLockMinutes = timeout;
      _reversibleTimeSeconds = revTime;
      _reversibleEnabled = revEnabled;
    });
  }

  Future<void> _toggleBiometric(bool enable) async {
    if (enable) {
      final available = await _authService.isBiometricAvailable();
      if (!available) {
        if (mounted) showTopSnackBar(context, title: 'Error', message: 'Biometric not available on this device');
        return;
      }
    }
    final ok = await _authService.authenticate(
      localizedReason: 'Authenticate to ${enable ? 'enable' : 'disable'} biometric',
      biometricOnly: false,
      forSetup: true,
    );
    if (ok) {
      _authService.setLocalAuthEnabled(enable);
      _loadSettings();
    }
  }

  void _toggleNotifications(bool enable) {
    final current = ref.read(notificationConfigProvider);
    ref.read(notificationConfigProvider.notifier).updateConfig(current.copyWith(enabled: enable));
  }

  void _navigateToRecoveryPhrase() {
    final accountsAsync = ref.read(accountsProvider);
    accountsAsync.whenData((accounts) {
      final walletIndices = getNonHardwareWalletIndices(accounts);
      if (walletIndices.isEmpty) return;
      if (walletIndices.length == 1) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RecoveryPhraseScreen(walletIndex: walletIndices.first)),
        );
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SelectWalletScreen()));
      }
    });
  }

  void _resetAndClearData() {
    _settingsService.clearAll();
    SubstrateService().logout();
    ref.read(pendingTransactionsProvider.notifier).clear();
    ref.read(accountsProvider.notifier).reset();
    ref.read(activeAccountProvider.notifier).reset();
    ref.read(accountAssociationsProvider.notifier).reset();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const WelcomeScreenV2()), (r) => false);
    }
  }

  void _showResetConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ResetConfirmationBottomSheet(onReset: _resetAndClearData),
    );
  }

  String _autoLockLabel() {
    if (_autoLockMinutes == 0) return 'Immediately';
    if (_autoLockMinutes == 60) return '1 hour';
    return '$_autoLockMinutes mins';
  }

  String _timeLimitLabel() {
    if (_reversibleTimeSeconds <= 0) return 'Disabled';
    final mins = _reversibleTimeSeconds ~/ 60;
    if (mins < 60) return '$mins minutes';
    final hours = mins ~/ 60;
    final remMins = mins % 60;
    return remMins > 0 ? '${hours}h ${remMins}m' : '$hours hours';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final notifConfig = ref.watch(notificationConfigProvider);

    return Scaffold(
      backgroundColor: colors.background,
      body: GradientBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppBackButton(),
                    Text('Settings', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
                    const SizedBox(width: 24),
                  ],
                ),
              ),
              const SizedBox(height: 48),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                    _section('Security', colors, text, [
                      _toggleItem('Biometric Lock', _biometricDesc, _biometricEnabled, _toggleBiometric, colors, text),
                      _divider(colors),
                      _chevronItem(
                        'PIN Code',
                        _hasPinSet ? '6-digit code' : 'Not set',
                        colors,
                        text,
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePinScreen()));
                          _loadPinState();
                        },
                      ),
                      _divider(colors),
                      _chevronItem(
                        'Auto-Lock',
                        _autoLockLabel(),
                        colors,
                        text,
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AutoLockScreen()));
                          _loadSettings();
                        },
                      ),
                    ]),
                    const SizedBox(height: 40),
                    _section('Wallet', colors, text, [
                      _chevronItem('Recovery Phase', 'View Backup', colors, text, onTap: _navigateToRecoveryPhrase),
                    ]),
                    const SizedBox(height: 40),
                    _section('Reversible Transactions', colors, text, [
                      _toggleItem(
                        'Reversible Transactions',
                        'Coming Soon', //_reversibleEnabled ? 'Enabled' : 'Disabled',
                        _reversibleEnabled,
                        null,
                        colors,
                        text,
                      ),
                      _divider(colors),
                      _chevronItem('Time Limit', _timeLimitLabel(), colors, text, onTap: () {}),
                      _divider(colors),
                      _chevronItem('Amount Limit', 'No Limit', colors, text, onTap: () {}),
                    ]),
                    const SizedBox(height: 40),
                    _section('Account Type', colors, text, [
                      _comingSoonItem('High Security Account', 'Guardian Approval', colors, text),
                      _divider(colors),
                      _comingSoonItem('Multi-Signature', 'Multiple Accounts', colors, text),
                      _divider(colors),
                      _comingSoonItem('Hardware Wallet', 'Pair Device', colors, text),
                    ]),
                    const SizedBox(height: 40),
                    _section('Preferences', colors, text, [
                      // _chevronItem('Currency', 'USD (\$)', colors, text, onTap: () {}),
                      // _divider(colors),
                      _toggleItem(
                        'Notifications',
                        notifConfig.enabled ? 'Transaction Alerts Enabled' : 'Alerts Disabled',
                        notifConfig.enabled,
                        _toggleNotifications,
                        colors,
                        text,
                      ),
                    ]),
                    const SizedBox(height: 40),
                    _section('About & Support', colors, text, [
                      _externalItem(
                        'Help & Support',
                        null,
                        colors,
                        text,
                        onTap: () => launchUrl(Uri.parse(AppConstants.helpAndSupportUrl)),
                      ),
                      _divider(colors),
                      _externalItem(
                        'Privacy & Terms of Service',
                        null,
                        colors,
                        text,
                        onTap: () => launchUrl(Uri.parse(AppConstants.termsOfServiceUrl)),
                      ),
                    ]),
                    const SizedBox(height: 40),
                    _resetButton(colors, text),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, AppColorsV2 colors, AppTextTheme text, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: colors.surfaceCard, borderRadius: BorderRadius.circular(14)),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _toggleItem(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool>? onChanged,
    AppColorsV2 colors,
    AppTextTheme text,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: text.detail?.copyWith(color: colors.textTertiary)),
            ],
          ),
        ),
        CupertinoSwitch(value: value, onChanged: onChanged, activeTrackColor: colors.accentGreen),
      ],
    );
  }

  Widget _chevronItem(
    String title,
    String subtitle,
    AppColorsV2 colors,
    AppTextTheme text, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
                const SizedBox(height: 4),
                Text(subtitle, style: text.detail?.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: colors.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _externalItem(
    String title,
    String? subtitle,
    AppColorsV2 colors,
    AppTextTheme text, {
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Expanded(
            child: subtitle != null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
                      const SizedBox(height: 4),
                      Text(subtitle, style: text.detail?.copyWith(color: colors.textTertiary)),
                    ],
                  )
                : Text(title, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
          ),
          Icon(Icons.north_east, color: colors.textSecondary, size: 20),
        ],
      ),
    );
  }

  Widget _comingSoonItem(String title, String subtitle, AppColorsV2 colors, AppTextTheme text) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
              const SizedBox(height: 4),
              Text(subtitle, style: text.detail?.copyWith(color: colors.textTertiary)),
            ],
          ),
        ),
        Text('Coming Soon', style: text.detail?.copyWith(color: colors.textTertiary)),
      ],
    );
  }

  Widget _divider(AppColorsV2 colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Divider(color: colors.separator, height: 1),
    );
  }

  Widget _resetButton(AppColorsV2 colors, AppTextTheme text) {
    return GestureDetector(
      onTap: _showResetConfirmation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colors.danger),
        ),
        child: Center(
          child: Text(
            'Reset Quantus',
            style: text.paragraph?.copyWith(color: colors.danger, fontWeight: FontWeight.w500),
          ),
        ),
      ),
    );
  }
}
