import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/l10n/app_localizations.dart';
import 'package:quantus_desktop_wallet/app_info.dart';
import 'package:quantus_desktop_wallet/providers/camera_providers.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/providers/settings_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/camera_scanner_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_card.dart';
import 'package:quantus_desktop_wallet/ui/components/scan_strings.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fiat = ref.watch(selectedFiatCurrencyProvider);
    final hidden = ref.watch(isBalanceHiddenProvider);
    final qr = ref.watch(qrDisplaySettingsProvider);
    final cameras = ref.watch(availableCamerasProvider);
    final selectedCamera = ref.watch(selectedCameraNameProvider);
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    final labelStyle = text.bodyEmphasis.copyWith(color: colors.textContent);
    final captionStyle = text.caption.copyWith(color: colors.textMuted);

    return DesktopPage(
      title: l10n.settingsTitle,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DesktopCard(
                title: l10n.settingsDisplay,
                child: Column(
                  children: [
                    _row(
                      label: Text(l10n.settingsFiat, style: labelStyle),
                      control: DropdownMenu<FiatCurrency>(
                        initialSelection: fiat,
                        width: 260,
                        textStyle: text.body.copyWith(color: colors.textContent),
                        dropdownMenuEntries: [
                          for (final currency in FiatCurrency.values)
                            DropdownMenuEntry(value: currency, label: currency.line),
                        ],
                        onSelected: (currency) {
                          if (currency != null) ref.read(selectedFiatCurrencyProvider.notifier).select(currency);
                        },
                      ),
                    ),
                    const MenuDivider(),
                    _row(
                      label: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.settingsDiscreet, style: labelStyle),
                          Text(l10n.settingsDiscreetBody, style: captionStyle),
                        ],
                      ),
                      control: Switch(
                        value: hidden,
                        activeThumbColor: colors.accentFlare,
                        onChanged: (value) => ref.read(isBalanceHiddenProvider.notifier).setIsBalanceHidden(value),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              DesktopCard(
                title: l10n.settingsQr,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _slider(
                            context,
                            label: '${l10n.settingsQrFps}: ${qr.fps}',
                            value: qr.fps,
                            min: QrDisplaySettings.minFps,
                            max: QrDisplaySettings.maxFps,
                            onChanged: (v) => ref.read(qrDisplaySettingsProvider.notifier).setFps(v),
                          ),
                          _slider(
                            context,
                            label: '${l10n.settingsQrBytes}: ${qr.bytesPerFrame}',
                            value: qr.bytesPerFrame,
                            min: QrDisplaySettings.minBytesPerFrame,
                            max: QrDisplaySettings.maxBytesPerFrame,
                            step: 25,
                            onChanged: (v) => ref.read(qrDisplaySettingsProvider.notifier).setBytesPerFrame(v),
                          ),
                          Text(l10n.settingsQrBody, style: captionStyle),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    AnimatedUrQr(parts: ref.watch(sampleQrPartsProvider(qr.bytesPerFrame)), fps: qr.fps, size: 160),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              DesktopCard(
                title: l10n.settingsCamera,
                child: cameras.when(
                  loading: () => const Skeleton(height: 40),
                  error: (e, _) =>
                      Text(l10n.cameraError('$e'), style: text.caption.copyWith(color: colors.semanticEmber)),
                  data: (list) => list.isEmpty
                      ? Text(l10n.settingsCameraNone, style: captionStyle)
                      : Row(
                          children: [
                            Expanded(
                              child: DropdownMenu<String>(
                                initialSelection: list.any((c) => c.name == selectedCamera)
                                    ? selectedCamera
                                    : list.first.name,
                                expandedInsets: EdgeInsets.zero,
                                textStyle: text.body.copyWith(color: colors.textContent),
                                dropdownMenuEntries: [
                                  for (final camera in list) DropdownMenuEntry(value: camera.name, label: camera.name),
                                ],
                                onSelected: (name) => ref.read(selectedCameraNameProvider.notifier).select(name),
                              ),
                            ),
                            const SizedBox(width: 12),
                            QuantusButton.simple(
                              label: l10n.settingsCameraTest,
                              variant: ButtonVariant.staged,
                              width: 160,
                              onTap: () => _testCamera(context, l10n),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 24),
              DesktopCard(
                title: l10n.settingsAccounts,
                child: Column(
                  children: [
                    for (final account in accounts)
                      _row(
                        label: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(account.name, style: labelStyle),
                            Text(
                              AddressFormattingService.formatAddress(account.accountId),
                              style: text.dataAddress.copyWith(color: colors.textMuted),
                            ),
                          ],
                        ),
                        control: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            QuantusButton.simple(
                              label: l10n.settingsRename,
                              variant: ButtonVariant.ghost,
                              width: null,
                              onTap: () => _rename(context, ref, account),
                            ),
                            QuantusButton.simple(
                              label: l10n.settingsRemove,
                              variant: ButtonVariant.underline,
                              width: null,
                              onTap: () => _remove(context, ref, account),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              DesktopCard(
                title: l10n.settingsAbout,
                child: Column(
                  children: [
                    QuantusDataRow(label: l10n.settingsVersion, value: AppInfo.version),
                    QuantusDataRow(
                      label: l10n.settingsNetwork,
                      value: AppConstants.runOnTestnet ? l10n.settingsNetworkTestnet : l10n.settingsNetworkMainnet,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row({required Widget label, required Widget control}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: 16),
        control,
      ],
    ),
  );

  Widget _slider(
    BuildContext context, {
    required String label,
    required int value,
    required int min,
    required int max,
    int step = 1,
    required ValueChanged<int> onChanged,
  }) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: (max - min) ~/ step,
          activeColor: colors.accentFlare,
          inactiveColor: colors.bgSurface2,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  Future<void> _testCamera(BuildContext context, AppLocalizations l10n) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(48),
      child: QuantusDialogFrame(
        maxWidth: 800,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CameraScannerPanel(
              collector: SingleQrCollector(validator: (_) => false),
              onComplete: (_) async {},
              strings: scanStringsFor(l10n, idleHint: l10n.onboardingScanHint),
              showFrameMap: false,
            ),
            const SizedBox(height: 16),
            QuantusButton.simple(
              label: l10n.commonClose,
              variant: ButtonVariant.staged,
              width: 160,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _rename(BuildContext context, WidgetRef ref, Account account) async {
    final l10n = ref.read(l10nProvider);
    final controller = TextEditingController(text: account.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: QuantusDialogFrame(
          maxWidth: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.settingsRenameTitle,
                style: context.themeTextV3.titleScreen.copyWith(color: context.colorsV3.textContent),
              ),
              const SizedBox(height: 16),
              QuantusTextField(controller: controller, onSubmitted: (value) => Navigator.pop(context, value)),
              const SizedBox(height: 20),
              QuantusButton.simple(label: l10n.settingsRename, onTap: () => Navigator.pop(context, controller.text)),
              const SizedBox(height: 8),
              QuantusButton.simple(
                label: l10n.commonCancel,
                variant: ButtonVariant.staged,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || name.trim() == account.name) return;
    await ref.read(accountsServiceProvider).updateAccountName(account, name.trim());
    invalidateAccountProviders(ref);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, Account account) async {
    final l10n = ref.read(l10nProvider);
    final confirmed = await showQuantusDialog(
      context,
      title: l10n.settingsRemoveTitle(account.name),
      body: l10n.settingsRemoveBody,
      actionLabel: l10n.settingsRemoveAction,
      cancelLabel: l10n.commonCancel,
      isDestructive: true,
      maxWidth: 420,
    );
    if (!confirmed) return;
    await ref.read(accountsServiceProvider).removeAccount(account);
    invalidateAccountProviders(ref);
  }
}
