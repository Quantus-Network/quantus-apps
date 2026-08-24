import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/components/password_field.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _unlockWithPassword() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(walletControllerProvider.notifier).unlockWithPassword(_passwordController.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = 'Incorrect password';
    });
  }

  Future<void> _unlockWithBiometric() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(walletControllerProvider.notifier).unlockWithBiometric();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!ok) _error = 'Biometric unlock failed';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final biometricEnabled = ref.watch(walletControllerProvider).biometricEnabled;

    return ScaffoldBase(
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(Icons.lock_outline_rounded, size: 64, color: colors.accentFlare),
          const SizedBox(height: 24),
          Text(
            'Cold Wallet Locked',
            style: text.titleScreen.copyWith(color: colors.textContent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          PasswordField(
            controller: _passwordController,
            hintText: 'Enter password',
            error: _error,
            onSubmitted: (_) => _unlockWithPassword(),
          ),
          const Spacer(),
          QuantusButton.simple(label: 'Unlock', onTap: _busy ? null : _unlockWithPassword, isLoading: _busy),
          if (biometricEnabled) ...[
            const SizedBox(height: 12),
            QuantusButton.simple(
              label: 'Use biometrics',
              icon: Icon(Icons.fingerprint, color: colors.textContent, size: 18),
              iconPlacement: IconPlacement.leading,
              variant: ButtonVariant.secondary,
              onTap: _busy ? null : _unlockWithBiometric,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
