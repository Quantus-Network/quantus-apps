import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';
import 'package:quantus_cold_wallet/components/cold_button.dart';
import 'package:quantus_cold_wallet/components/cold_dialog.dart';

/// Destructive confirmation, then the wipe and a return to the first route,
/// which RootGate turns into Welcome.
Future<void> confirmResetWallet(BuildContext context, WidgetRef ref) async {
  final confirmed = await showColdDialog(
    context,
    title: 'Reset wallet?',
    titleColor: context.colorsV3.semanticEmber,
    body:
        'This erases the encrypted key and its device-protected unlock key from this phone. You can only restore '
        'the key with your recovery phrase.',
    actionLabel: 'Reset',
    isDestructive: true,
  );
  if (!confirmed) return;
  await ref.read(walletControllerProvider.notifier).wipe();
  if (context.mounted) Navigator.popUntil(context, (r) => r.isFirst);
}

/// Asks the device to release the signing key as soon as it appears and
/// again when the app comes back from the background; "Unlock" retries.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> with WidgetsBindingObserver {
  bool _busy = false;
  bool _unlockOnResume = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
      Future.microtask(_unlock);
    } else {
      _unlockOnResume = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android's own prompt pauses the activity; its result resumes the
    // unlock already in flight, so only an idle pause schedules a new one.
    if (state == AppLifecycleState.paused) _unlockOnResume = !_busy;
    if (state == AppLifecycleState.resumed && _unlockOnResume) {
      _unlockOnResume = false;
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(walletControllerProvider.notifier).unlockWithBiometric();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final error = ref.watch(walletControllerProvider.select((s) => s.error));
    final cancelled = error == unlockCancelledError;
    final failed = error != null && !cancelled;

    return ScaffoldBase(
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          Center(child: QuantusIcon(QuantusIcons.lock, size: 60, color: colors.accentFlare)),
          const SizedBox(height: 24),
          Text(
            'Locked',
            style: text.titleHero.copyWith(color: colors.textContent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Confirm it is you to use the signing key on this device.',
            style: text.bodyLarge.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          if (cancelled) ...[
            const SizedBox(height: 16),
            Text(
              'Unlock cancelled. Tap Unlock to try again.',
              style: text.caption.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
          if (failed) ...[
            const SizedBox(height: 16),
            Text(
              error,
              style: text.caption.copyWith(color: colors.semanticEmber),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(flex: 3),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            QuantusButton.simple(
              label: 'Unlock',
              padding: coldButtonPadding,
              isLoading: _busy,
              onTap: _busy ? null : _unlock,
            ),
            if (failed) ...[
              const SizedBox(height: 12),
              ColdButton.danger(label: 'Reset wallet…', onTap: _busy ? null : () => confirmResetWallet(context, ref)),
            ],
          ],
        ),
      ),
    );
  }
}
