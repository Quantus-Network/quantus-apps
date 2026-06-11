import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';
import 'package:quantus_cold_wallet/widgets/password_field.dart';

class SetPasswordScreen extends ConsumerStatefulWidget {
  final String mnemonic;
  const SetPasswordScreen({super.key, required this.mnemonic});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  static const _minLength = 8;

  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _biometricAvailable = false;
  bool _enableBiometric = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkBiometric();
  }

  Future<void> _checkBiometric() async {
    final available = await ref.read(walletControllerProvider.notifier).auth.canUseBiometrics();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _enableBiometric = available;
    });
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_password.text.length < _minLength) return 'Password must be at least $_minLength characters';
    if (_password.text != _confirm.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _create() async {
    final error = _validate();
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(walletControllerProvider.notifier)
          .createWallet(mnemonic: widget.mnemonic, password: _password.text, enableBiometric: _enableBiometric);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Failed to create wallet: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Set password'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your password encrypts the wallet key stored on this device. There is no recovery if you forget it.',
              style: text.smallParagraph?.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: 24),
            PasswordField(controller: _password, hintText: 'Password'),
            const SizedBox(height: 12),
            PasswordField(controller: _confirm, hintText: 'Confirm password', onSubmitted: (_) => _create()),
            if (_biometricAvailable) ...[const SizedBox(height: 24), _biometricToggle(colors, text)],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: text.detail?.copyWith(color: colors.error)),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Create wallet', onTap: _busy ? null : _create, isLoading: _busy),
      ),
    );
  }

  Widget _biometricToggle(AppColorsV2 colors, AppTextTheme text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderButton, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.fingerprint, color: colors.textPrimary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Enable biometric unlock', style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
          ),
          Switch(
            value: _enableBiometric,
            activeThumbColor: colors.accentOrange,
            onChanged: (v) => setState(() => _enableBiometric = v),
          ),
        ],
      ),
    );
  }
}
