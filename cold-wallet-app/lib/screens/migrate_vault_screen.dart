import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/lock_screen.dart';
import 'package:quantus_cold_wallet/components/password_field.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/secure_element_warning_screen.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';

/// The one-time step for a wallet created with an app password: the password
/// moves the vault behind the device key and is never asked again.
class MigrateVaultScreen extends ConsumerStatefulWidget {
  const MigrateVaultScreen({super.key});

  @override
  ConsumerState<MigrateVaultScreen> createState() => _MigrateVaultScreenState();
}

class _MigrateVaultScreenState extends ConsumerState<MigrateVaultScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  /// Without a device lock the rotation would leave the wallet open to anyone
  /// holding the phone, so it needs the same acceptance as creating one.
  Future<bool> _acceptUnprotected() async {
    if (await ref.read(coldAuthServiceProvider).deviceCanProtect()) return true;
    if (!mounted) return false;
    final proceed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SecureElementWarningScreen()),
    );
    return proceed == true;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!await _acceptUnprotected() || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final moved = await ref.read(walletControllerProvider.notifier).migrateLegacy(_password.text);
      if (!moved && mounted) setState(() => _error = 'Incorrect password');
    } on VaultAccessCancelled {
      if (mounted) setState(() => _error = 'Face ID is needed to finish moving your wallet.');
    } catch (e, st) {
      debugPrint('Migration failed: $e\n$st');
      if (mounted) setState(() => _error = 'Secure storage failed. Nothing was changed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Wallet update', showBackButton: false),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 32),
            Center(child: ColdIcon(ColdIcons.key, size: 60, color: colors.accentFlare)),
            const SizedBox(height: 24),
            Text(
              'One last password',
              style: text.titleHero.copyWith(color: colors.textContent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Enter your password once to move this wallet behind your device lock. You will not need it again.',
              style: text.bodyLarge.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            PasswordField(controller: _password, hintText: 'Password', enabled: !_busy, onSubmitted: (_) => _submit()),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: text.caption.copyWith(color: colors.semanticEmber),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(
              label: 'Continue',
              padding: coldButtonPadding,
              isLoading: _busy,
              onTap: _busy ? null : _submit,
            ),
            const SizedBox(height: 12),
            QuantusButton.simple(
              label: 'Reset wallet…',
              variant: ButtonVariant.ghost,
              padding: coldButtonPadding,
              onTap: _busy ? null : () => confirmResetWallet(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}
