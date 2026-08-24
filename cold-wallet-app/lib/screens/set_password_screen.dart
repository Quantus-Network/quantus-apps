import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

class SetPasswordScreen extends ConsumerStatefulWidget {
  final String mnemonic;
  final List<ColdAccount> accounts;

  const SetPasswordScreen({super.key, required this.mnemonic, required this.accounts});

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
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
          .createWallet(
            mnemonic: widget.mnemonic,
            password: _password.text,
            enableBiometric: _enableBiometric,
            accounts: widget.accounts,
          );
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Set password'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your password encrypts the wallet key stored on this device. There is no recovery if you forget it.',
              style: text.body.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 24),
            QuantusPasswordField(controller: _password, hint: 'Password'),
            const SizedBox(height: 12),
            QuantusPasswordField(controller: _confirm, hint: 'Confirm password', onSubmitted: (_) => _create()),
            if (_biometricAvailable) ...[const SizedBox(height: 24), _biometricToggle(colors, text)],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: text.caption.copyWith(color: colors.semanticEmber)),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Create wallet', onTap: _busy ? null : _create, isLoading: _busy),
      ),
    );
  }

  Widget _biometricToggle(AppColorsV3 colors, AppTextThemeV3 text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.fingerprint, color: colors.textContent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text('Enable biometric unlock', style: text.body.copyWith(color: colors.textContent)),
          ),
          Switch(
            value: _enableBiometric,
            activeTrackColor: colors.accentFlare,
            onChanged: (v) => setState(() => _enableBiometric = v),
          ),
        ],
      ),
    );
  }
}
