import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/lock_screen.dart';
import 'package:quantus_cold_wallet/components/password_field.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/secure_element_warning_screen.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_cold_wallet/ui/seal_wording.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';

/// The one-time step for a wallet an earlier app version created: what opens
/// it today, its password or its device key, moves it to how this version
/// holds the key, and the password is never asked again.
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

  /// What the vault moves behind: user presence where the device offers it,
  /// otherwise a plain entry, which would leave the wallet open to anyone
  /// holding the phone and so needs the same acceptance as creating one.
  /// Null when that warning was declined, or when a device that seals the
  /// phrase cannot yet, which the screen then says. The choice is made here,
  /// once, and carried into the migration.
  Future<bool?> _chooseProtection() async {
    if (ref.read(walletControllerProvider.notifier).sealed) {
      return await ref.refresh(sealPolicyProvider.future) == null ? null : true;
    }
    if (await ref.read(coldAuthServiceProvider).deviceCanProtect()) return true;
    if (!mounted) return null;
    final proceed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SecureElementWarningScreen()),
    );
    return proceed == true ? false : null;
  }

  Future<void> _submit(bool needsPassword) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final protected = await _chooseProtection();
      if (protected == null || !mounted) return;
      final moved = await ref
          .read(walletControllerProvider.notifier)
          .migrateLegacy(_password.text, protected: protected);
      if (!moved && mounted) {
        setState(
          () => _error = needsPassword
              ? 'Incorrect password'
              : 'This device can no longer open the wallet on its own. Enter its password.',
        );
      }
    } on VaultAccessCancelled {
      if (mounted) setState(() => _error = 'Cancelled. Your wallet has not moved yet.');
    } on KeyRefused catch (e) {
      if (mounted) setState(() => _error = e.message);
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
    final sealed = ref.read(walletControllerProvider.notifier).sealed;
    final available = sealed ? ref.watch(sealPolicyProvider) : null;
    final lockMissing = available?.cannotSeal ?? false;
    final error = _error ?? available?.failure;
    final policy = available?.value ?? SealPolicy.biometry;
    final credential = policy.credential;
    final needsPassword = !ref.watch(walletControllerProvider.select((s) => s.biometricEnabled));

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
              switch ((lockMissing, needsPassword)) {
                (true, _) => lockRequiredTitle,
                (false, true) => 'One last password',
                (false, false) => '${policy.credentialTitle} for every signature',
              },
              style: text.titleHero.copyWith(color: colors.textContent),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              switch ((sealed, needsPassword)) {
                _ when lockMissing => lockRequiredMessage,
                (false, _) =>
                  'Enter your password once to move this wallet behind your device lock. You will not need it again.',
                (true, true) =>
                  'Enter your password once to move the signing key behind $credential. You will not need it '
                      'again: from now on every signature asks for $credential.',
                (true, false) =>
                  'This update keeps the signing key behind $credential alone and asks for it at every '
                      'signature. You are asked up to twice now: to open the wallet as it is stored today, and to '
                      'confirm the new key.',
              },
              style: text.bodyLarge.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            if (needsPassword && !lockMissing)
              PasswordField(
                controller: _password,
                hintText: 'Password',
                enabled: !_busy,
                onSubmitted: (_) => _submit(needsPassword),
              ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Text(
                error,
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
              label: lockMissing ? 'Check again' : 'Continue',
              padding: coldButtonPadding,
              isLoading: _busy,
              onTap: _busy
                  ? null
                  : lockMissing
                  ? () {
                      setState(() => _error = null);
                      ref.invalidate(sealPolicyProvider);
                    }
                  : () => _submit(needsPassword),
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
