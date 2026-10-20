import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_desktop_wallet/l10n/app_localizations.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/providers/simulation_providers.dart';
import 'package:quantus_desktop_wallet/router.dart';
import 'package:quantus_desktop_wallet/ui/components/camera_scanner_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/scan_strings.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

/// Imports a cold wallet account by scanning the address QR the phone shows.
class ConnectColdWalletScreen extends ConsumerStatefulWidget {
  final bool firstRun;

  const ConnectColdWalletScreen({super.key, required this.firstRun});

  @override
  ConsumerState<ConnectColdWalletScreen> createState() => _ConnectColdWalletScreenState();
}

class _ConnectColdWalletScreenState extends ConsumerState<ConnectColdWalletScreen> {
  static const int maxQrLength = 200;

  late final TextEditingController _name = TextEditingController(text: ref.read(l10nProvider).onboardingNameDefault);
  late SingleQrCollector _collector = _newCollector();
  String? _address;
  String? _error;
  bool _saving = false;

  SingleQrCollector _newCollector() => SingleQrCollector(
    validator: (value) => value.length <= maxQrLength && SubstrateService().isValidSS58Address(value.trim()),
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _scanned(List<String> parts) async {
    setState(() {
      _address = parts.first.trim();
      _error = null;
    });
  }

  void _scanAgain() => setState(() {
    _address = null;
    _error = null;
    _collector = _newCollector();
  });

  Future<void> _save() async {
    final address = _address;
    if (address == null || _saving) return;
    final l10n = ref.read(l10nProvider);
    final name = _name.text.trim().isEmpty ? l10n.onboardingNameDefault : _name.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final account = await ref.read(accountsServiceProvider).importColdWalletAccount(address: address, name: name);
      await ref.read(activeAccountProvider.notifier).setActiveAccount(RegularAccount(account));
      invalidateAccountProviders(ref);
      if (mounted) context.go(AppRoutes.dashboard);
    } on DuplicateAccountException {
      setState(() => _error = l10n.onboardingDuplicate);
    } on FormatException {
      setState(() => _error = l10n.onboardingInvalidAddress);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!widget.firstRun)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: QuantusIconButton.ghost(
              icon: Icons.arrow_back_rounded,
              size: IconButtonSize.small,
              onTap: () => context.go(AppRoutes.dashboard),
            ),
          ),
        Text(l10n.onboardingTitle, style: text.titleHero.copyWith(color: colors.textContent)),
        const SizedBox(height: 12),
        Text(l10n.onboardingBody, style: text.body.copyWith(color: colors.textMuted, height: 1.55)),
        const SizedBox(height: 32),
        for (final (i, step) in [l10n.onboardingStep1, l10n.onboardingStep2, l10n.onboardingStep3].indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('0${i + 1}', style: text.labelMonogram.copyWith(color: colors.accentFlare)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(step, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
                ),
              ],
            ),
          ),
      ],
    );
    final panel = _address == null ? _scanner(l10n) : _confirm(l10n);

    return Scaffold(
      backgroundColor: colors.bgVoid,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 920) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [copy, const SizedBox(height: 32), panel],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 400, child: copy),
                    const SizedBox(width: 48),
                    Expanded(child: panel),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _scanner(AppLocalizations l10n) {
    final simulated = ref.watch(simulatedColdWalletProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CameraScannerPanel(
          key: ValueKey(_collector),
          collector: _collector,
          onComplete: _scanned,
          strings: scanStringsFor(l10n, idleHint: l10n.onboardingScanHint),
          showFrameMap: false,
          aspectRatio: 4 / 3,
        ),
        if (simulated != null) ...[
          const SizedBox(height: 12),
          QuantusButton.simple(
            label: l10n.onboardingSimulated,
            variant: ButtonVariant.ghost,
            onTap: () => _scanned([simulated.address]),
          ),
        ],
      ],
    );
  }

  Widget _confirm(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final address = _address!;
    final checkphrase = ref.watch(checksumNameProvider(address)).value;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.onboardingNameLabel, style: text.labelMonogram.copyWith(color: colors.textMuted)),
          const SizedBox(height: 8),
          QuantusTextField(controller: _name, onSubmitted: (_) => _save(), textInputAction: TextInputAction.done),
          const SizedBox(height: 24),
          AddressCheckphrase(address: address, checkphrase: checkphrase, addressStyle: text.dataAddressLarge),
          const SizedBox(height: 16),
          QuantusBanner(tone: BannerTone.glacier, message: l10n.onboardingCompareBanner),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: text.caption.copyWith(color: colors.semanticEmber)),
          ],
          const SizedBox(height: 24),
          QuantusButton.simple(label: l10n.onboardingAdd, isLoading: _saving, onTap: _save),
          const SizedBox(height: 8),
          QuantusButton.simple(label: l10n.onboardingScanAgain, variant: ButtonVariant.ghost, onTap: _scanAgain),
        ],
      ),
    );
  }
}
