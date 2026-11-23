import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/key_created_screen.dart';
import 'package:quantus_cold_wallet/screens/secure_element_warning_screen.dart';
import 'package:quantus_cold_wallet/services/vault_service.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_cold_wallet/components/cold_icon.dart';
import 'package:quantus_cold_wallet/components/cold_button.dart';

/// What a device that seals the phrase says while it cannot: sealing needs a
/// passcode and an enrolled Face ID, and there is no weaker way to continue.
const faceIdRequiredMessage =
    'Turn on a passcode and Face ID in Settings, then come back. This iPhone releases the signing key only to '
    'Face ID.';

enum _Method {
  /// Biometrics enrolled: the user picks (Figma 798:6205). Both choices store
  /// the key behind user presence; neither OS lets the app hide an enrolled
  /// biometric behind it.
  faceId,

  /// Device lock without biometrics: no choice to make, creation starts at once.
  passcode,

  /// No device lock, accepted on the warning screen: a plain key entry.
  none,

  /// A sealed phrase: Face ID alone, for every use of the key.
  eachUse,

  /// A device that seals the phrase but has no passcode or enrolled Face ID.
  unavailable,
}

/// Face ID (Figma 798:6205): the last step of both Create New Key and Import
/// Key. Decides how the device keeps the signing key, creates the wallet and
/// moves on to Key Created.
class UnlockMethodScreen extends ConsumerStatefulWidget {
  final String mnemonic;
  final List<ColdAccount> accounts;

  /// The phrase puts back the key of a wallet this device already lists, so
  /// nothing new was created to announce.
  final bool restoring;

  const UnlockMethodScreen({super.key, required this.mnemonic, required this.accounts, this.restoring = false});

  @override
  ConsumerState<UnlockMethodScreen> createState() => _UnlockMethodScreenState();
}

class _UnlockMethodScreenState extends ConsumerState<UnlockMethodScreen> {
  _Method? _method;
  bool _busy = false;
  bool _cancelled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _probe());
  }

  Future<void> _probe() async {
    final auth = ref.read(coldAuthServiceProvider);
    if (ref.read(walletControllerProvider.notifier).sealed) {
      final biometrics = await auth.canUseBiometrics();
      if (mounted) setState(() => _method = biometrics ? _Method.eachUse : _Method.unavailable);
      return;
    }
    final canProtect = await auth.deviceCanProtect();
    if (!mounted) return;
    if (!canProtect) {
      final proceed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const SecureElementWarningScreen()),
      );
      if (!mounted) return;
      if (proceed != true) {
        Navigator.pop(context);
        return;
      }
      setState(() => _method = _Method.none);
      await _create();
      return;
    }
    final biometrics = await auth.canUseBiometrics();
    if (!mounted) return;
    setState(() => _method = biometrics ? _Method.faceId : _Method.passcode);
    if (!biometrics) await _create();
  }

  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _cancelled = false;
      _error = null;
    });
    try {
      await ref
          .read(walletControllerProvider.notifier)
          .createWallet(mnemonic: widget.mnemonic, accounts: widget.accounts, protected: _method != _Method.none);
      if (!mounted) return;
      if (widget.restoring) {
        Navigator.popUntil(context, (route) => route.isFirst);
        return;
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => KeyCreatedScreen(account: widget.accounts.first)),
      );
    } on VaultAccessCancelled {
      if (mounted) setState(() => _cancelled = true);
    } on KeyRefused catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e, st) {
      debugPrint('Create wallet failed: $e\n$st');
      if (mounted) setState(() => _error = 'Secure storage failed. Nothing was saved.\n$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final method = _method;
    final usesFaceId = method == _Method.faceId || method == _Method.eachUse;

    return ScaffoldBase(
      appBar: V2AppBar(title: widget.restoring ? 'Restore Key' : 'New Key'),
      mainContent: method == null
          ? const Center(child: Loader(size: 24))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(flex: 2),
                Center(
                  child: switch (method) {
                    _Method.faceId ||
                    _Method.eachUse => ColdIcon(ColdIcons.faceId, size: 60, color: colors.accentFlare),
                    _Method.passcode => QuantusIcon(QuantusIcons.lock, size: 60, color: colors.accentFlare),
                    _Method.none ||
                    _Method.unavailable => ColdIcon(ColdIcons.warning, size: 60, color: colors.semanticSand),
                  },
                ),
                const SizedBox(height: 24),
                Text(
                  switch (method) {
                    _Method.faceId => 'Unlock with Face ID',
                    _Method.passcode => 'Unlock with your passcode',
                    _Method.none => 'No device lock',
                    _Method.eachUse => 'Sign with Face ID',
                    _Method.unavailable => 'Face ID is off',
                  },
                  style: text.titleHero.copyWith(color: colors.textContent),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  switch (method) {
                    _Method.faceId => "Used every time you open this device. Your phone's passcode is the fallback.",
                    _Method.passcode => 'Asked every time you open this device.',
                    _Method.none => 'The signing key is stored without user presence.',
                    _Method.eachUse =>
                      'Asked for every signature, with no passcode fallback. Changing Face ID or turning the '
                          'passcode off removes the key from this iPhone; your recovery phrase puts it back.',
                    _Method.unavailable => faceIdRequiredMessage,
                  },
                  style: text.bodyLarge.copyWith(color: colors.textMuted),
                  textAlign: TextAlign.center,
                ),
                if (_cancelled) ...[
                  const SizedBox(height: 16),
                  Text(
                    usesFaceId
                        ? 'Face ID was cancelled. Tap to try again.'
                        : 'Unlock was cancelled. Tap Continue to try again.',
                    style: text.caption.copyWith(color: colors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _error!,
                    style: text.caption.copyWith(color: colors.semanticEmber),
                    textAlign: TextAlign.center,
                  ),
                ],
                const Spacer(flex: 3),
              ],
            ),
      bottomContent: method == null
          ? null
          : ScaffoldBaseBottomContent(
              child: Column(
                children: [
                  if (method == _Method.unavailable)
                    QuantusButton.simple(label: 'Check again', padding: coldButtonPadding, onTap: _probe)
                  else
                    QuantusButton.simple(
                      label: usesFaceId ? 'Enable Face ID' : 'Continue',
                      padding: coldButtonPadding,
                      isLoading: _busy,
                      onTap: _busy ? null : _create,
                    ),
                  if (method == _Method.faceId) ...[
                    const SizedBox(height: 12),
                    ColdButton.secondary(label: 'Use Passcode only', onTap: _busy ? null : _create),
                    const SizedBox(height: 12),
                    Text(
                      'Your device may still offer Face ID first in the system prompt.',
                      style: text.caption.copyWith(color: colors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
