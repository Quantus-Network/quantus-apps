import 'dart:async';
import 'dart:math';

import 'package:desktop_qr_camera/desktop_qr_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/account_management_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/qr_scan_source.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/utils/cold_wallet_target.dart';
import 'package:quantus_desktop_wallet/utils/scanned_address_reads.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/multisig_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// What the scan step says under the camera about the last code read.
enum _ScanNote { notAnAddress, alreadyInApp }

/// Adds a cold wallet by reading its account's QR code: the instructions
/// beside the camera, then the address read, to compare with the device
/// before anything is saved. The camera is on only during the first step.
/// With a cold wallet in the app already, the account is added to it
/// ([coldWalletTarget]), and the sheet says so.
class ConnectColdWalletSheet extends ConsumerStatefulWidget {
  const ConnectColdWalletSheet({super.key, required this.onConnected});

  /// Told the account saved, just before the sheet closes.
  final ValueChanged<Account> onConnected;

  @override
  ConsumerState<ConnectColdWalletSheet> createState() => _ConnectColdWalletSheetState();
}

class _ConnectColdWalletSheetState extends ConsumerState<ConnectColdWalletSheet> {
  static const double _cameraWidth = 392;
  static const double _stepsMinWidth = 180;
  static const double _columnGap = 24;

  late final QrScanSource _source = ref.read(qrScanSourceFactoryProvider)();
  late final ScannedAddressReads _scanned = ScannedAddressReads(
    isValidAddress: ref.read(substrateServiceProvider).isValidSS58Address,
    isInApp: _isInApp,
  );
  StreamSubscription<String>? _reads;

  QrCameraFailure? _failure;
  _ScanNote? _note;
  bool _isStarting = false;

  /// The address read, on the confirm step.
  String? _address;
  bool _isSaving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _reads = _source.reads.listen(_onRead, onError: _onCameraError);
    // After the first frame: the macOS camera needs its preview in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_startCamera());
    });
  }

  @override
  void dispose() {
    unawaited(_reads?.cancel());
    unawaited(_disposeSource());
    super.dispose();
  }

  Future<void> _disposeSource() async {
    try {
      await _source.dispose();
    } catch (e) {
      quantusPrint('Turning the camera off failed: $e');
    }
  }

  bool _isInApp(String address) {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final multisigs = ref.read(multisigAccountsProvider).value ?? const <MultisigAccount>[];
    return accounts.any((account) => account.accountId == address) ||
        multisigs.any((multisig) => multisig.accountId == address) ||
        ref.read(creatingMultisigsProvider).any((multisig) => multisig.accountId == address);
  }

  Future<void> _startCamera() async {
    if (_isStarting) return;
    _isStarting = true;
    _scanned.reset();
    setState(() {
      _failure = null;
      _note = null;
    });
    try {
      await _source.start();
    } on QrCameraException catch (error) {
      quantusPrint('The camera did not start: $error');
      if (mounted) setState(() => _failure = error.failure);
    } finally {
      _isStarting = false;
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _source.stop();
    } on QrCameraException catch (error) {
      quantusPrint('Turning the camera off failed: $error');
    }
  }

  void _onRead(String text) {
    if (!mounted || _address != null) return;
    switch (_scanned.add(text)) {
      case ReadPending():
        if (_note != null) setState(() => _note = null);
      case ReadNotAnAddress():
        setState(() => _note = _ScanNote.notAnAddress);
      case ReadAlreadyInApp():
        setState(() => _note = _ScanNote.alreadyInApp);
      case ReadConfirmed(:final address):
        setState(() {
          _address = address;
          _note = null;
        });
        unawaited(_stopCamera());
    }
  }

  void _onCameraError(Object error) {
    quantusPrint('The camera failed: $error');
    if (!mounted || _address != null) return;
    _scanned.reset();
    setState(() {
      _failure = error is QrCameraException ? error.failure : QrCameraFailure.failed;
      _note = null;
    });
  }

  void _scanAgain() {
    if (_isSaving) return;
    setState(() {
      _address = null;
      _saveError = null;
    });
    unawaited(_startCamera());
  }

  Future<void> _connect() async {
    final address = _address;
    if (address == null || _isSaving) return;
    final l10n = ref.read(l10nProvider);
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final Account account;
    try {
      account = await ref.read(accountManagerProvider).connectColdWallet(address);
    } on ColdWalletAlreadyInApp {
      _showSaveError(l10n.desktopColdWalletAlreadyAdded);
      return;
    } catch (e) {
      quantusPrint('Connecting a cold wallet failed: $e');
      _showSaveError(l10n.desktopColdWalletSaveFailed);
      return;
    }
    if (!mounted) return;
    widget.onConnected(account);
    Navigator.of(context).pop();
  }

  void _showSaveError(String message) {
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _saveError = message;
    });
  }

  Future<void> _openSettings(Uri url) async {
    try {
      await ref.read(openExternalUrlProvider)(url);
    } catch (e) {
      // The notice already says where to go.
      quantusPrint('Opening the camera settings failed: $e');
    }
  }

  static Uri? get _cameraSettings => switch (defaultTargetPlatform) {
    TargetPlatform.macOS => Uri.parse('x-apple.systempreferences:com.apple.preference.security?Privacy_Camera'),
    TargetPlatform.windows => Uri.parse('ms-settings:privacy-webcam'),
    _ => null,
  };

  static ({String title, String body}) _failureText(AppLocalizations l10n, QrCameraFailure failure) =>
      switch (failure) {
        QrCameraFailure.noCamera => (title: l10n.desktopCameraNoneTitle, body: l10n.desktopCameraNoneBody),
        QrCameraFailure.permissionDenied => (
          title: l10n.desktopCameraPermissionTitle,
          body: switch (defaultTargetPlatform) {
            TargetPlatform.macOS => l10n.desktopCameraPermissionMac,
            TargetPlatform.windows => l10n.desktopCameraPermissionWindows,
            _ => l10n.desktopCameraPermissionLinux,
          },
        ),
        QrCameraFailure.busy => (title: l10n.desktopCameraBusyTitle, body: l10n.desktopCameraBusyBody),
        QrCameraFailure.unsupported => (
          title: l10n.desktopCameraUnsupportedTitle,
          body: l10n.desktopCameraUnsupportedBody,
        ),
        QrCameraFailure.mediaUnavailable => (title: l10n.desktopCameraMediaTitle, body: l10n.desktopCameraMediaBody),
        QrCameraFailure.stopped => (title: l10n.desktopCameraStoppedTitle, body: l10n.desktopCameraStoppedBody),
        QrCameraFailure.failed => (title: l10n.desktopCameraFailedTitle, body: l10n.desktopCameraFailedBody),
      };

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final address = _address;
    final target = coldWalletTarget(
      ref.watch(accountsProvider).value ?? const <Account>[],
      activeAccountId: ref.watch(activeAccountProvider).value?.account.accountId,
    );
    final title = target.isNewWallet ? l10n.addKeystoneConnectTitle : l10n.desktopColdWalletAddAccountTitle;

    return PopScope(
      canPop: !_isSaving,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_stopCamera());
      },
      child: SheetBackShortcut(
        onBack: address == null ? null : _scanAgain,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kept in the tree on the confirm step: the macOS camera stays
            // attached to its preview between scans.
            Offstage(offstage: address != null, child: _scanStep(context, l10n, title)),
            if (address != null) _confirmStep(context, l10n, title, address, target.name),
          ],
        ),
      ),
    );
  }

  Widget _scanStep(BuildContext context, AppLocalizations l10n, String title) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShellSheetHeader(title: title),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final cameraWidth = min(_cameraWidth, constraints.maxWidth - _stepsMinWidth - _columnGap);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _Steps(l10n: l10n)),
                const SizedBox(width: _columnGap),
                SizedBox(
                  width: cameraWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _cameraBox(context, l10n, cameraWidth),
                      const SizedBox(height: 12),
                      ConstrainedBox(constraints: const BoxConstraints(minHeight: 20), child: _status(context, l10n)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SheetButton(
              label: l10n.commonCancel,
              kind: SheetButtonKind.secondary,
              onTap: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _cameraBox(BuildContext context, AppLocalizations l10n, double width) {
    final colors = context.colorsV3;
    final failure = _failure;

    return ClipRRect(
      borderRadius: context.radiusV3.mdBorder,
      child: Container(
        width: width,
        height: width * 0.72,
        decoration: BoxDecoration(
          color: colors.bgVoid,
          border: Border.all(color: colors.borderHairline),
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            _preview,
            if (failure == null)
              Center(
                child: SizedBox.square(
                  dimension: width * 0.6,
                  child: CustomPaint(
                    painter: ScanFramePainter(
                      accent: colors.accentFlare,
                      scrim: colors.bgVoid.useOpacity(0.35),
                      radius: context.radiusV3.md,
                    ),
                  ),
                ),
              )
            else
              ColoredBox(
                color: colors.bgVoid,
                child: _CameraNotice(
                  text: _failureText(l10n, failure),
                  tryAgainLabel: l10n.commonTryAgain,
                  onTryAgain: _startCamera,
                  settingsLabel: l10n.desktopCameraOpenSettings,
                  onOpenSettings: switch ((failure, _cameraSettings)) {
                    (QrCameraFailure.permissionDenied, final Uri url) => () => unawaited(_openSettings(url)),
                    _ => null,
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// One preview for the sheet's life, so a rebuild never reattaches it.
  late final Widget _preview = _source.buildPreview();

  Widget _status(BuildContext context, AppLocalizations l10n) {
    if (_failure != null) return const SizedBox.shrink();
    final note = _note;
    if (note == null) return TerminalBusyLine(label: l10n.desktopColdWalletLooking);
    return Semantics(
      liveRegion: true,
      child: Text(switch (note) {
        _ScanNote.notAnAddress => l10n.desktopColdWalletNotAddress,
        _ScanNote.alreadyInApp => l10n.desktopColdWalletAlreadyAdded,
      }, style: context.themeTextV3.body.copyWith(color: context.colorsV3.semanticEmber)),
    );
  }

  Widget _confirmStep(BuildContext context, AppLocalizations l10n, String title, String address, String name) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final error = _saveError;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ShellSheetHeader(title: l10n.desktopColdWalletConfirmTitle, parent: (title: title, onBack: _scanAgain)),
        const SizedBox(height: 12),
        Text(l10n.desktopColdWalletConfirmBody, style: text.body.copyWith(color: colors.textMuted)),
        const SizedBox(height: 14),
        _DetailRow(
          label: l10n.desktopCreateMultisigAddress,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: DesktopAddressCheckphrase(address: address, isCompact: true),
          ),
        ),
        _DetailRow(
          label: l10n.desktopAccountInfoName,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(name, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(error, style: text.caption.copyWith(color: colors.semanticEmber)),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          spacing: 10,
          children: [
            SheetButton(
              label: l10n.desktopColdWalletScanAgain,
              kind: SheetButtonKind.secondary,
              onTap: _scanAgain,
              isDisabled: _isSaving,
            ),
            SheetButton(label: l10n.desktopColdWalletConnect, onTap: _connect, isDisabled: _isSaving),
          ],
        ),
      ],
    );
  }
}

/// What to do on the device, numbered.
class _Steps extends StatelessWidget {
  const _Steps({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final steps = [l10n.addKeystoneStepUnlock, l10n.addKeystoneStepSelectQuantus, l10n.desktopColdWalletStepHold];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.addKeystoneOnYourKeystone,
          style: context.themeTextV3.dataAddress.copyWith(
            height: 1,
            letterSpacing: 2,
            color: context.colorsV3.textMuted2,
          ),
        ),
        const SizedBox(height: 10),
        for (final (index, words) in steps.indexed) _Step(number: index + 1, words: words),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.words});

  final int number;
  final String words;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colors.borderEmphasis),
            ),
            child: Text('$number', style: text.caption.copyWith(height: 1, color: colors.textContent)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(words, style: text.body.copyWith(color: colors.textContent)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Why the camera shows no picture, in its place, and what can be done.
class _CameraNotice extends StatelessWidget {
  const _CameraNotice({
    required this.text,
    required this.tryAgainLabel,
    required this.onTryAgain,
    required this.settingsLabel,
    required this.onOpenSettings,
  });

  final ({String title, String body}) text;
  final String tryAgainLabel;
  final VoidCallback onTryAgain;
  final String settingsLabel;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final style = context.themeTextV3;
    final onOpenSettings = this.onOpenSettings;

    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text.title,
              textAlign: TextAlign.center,
              style: style.bodyEmphasis.copyWith(color: colors.textContent),
            ),
            const SizedBox(height: 6),
            Text(
              text.body,
              textAlign: TextAlign.center,
              style: style.body.copyWith(color: colors.textMuted),
            ),
            const SizedBox(height: 14),
            // Side by side when they fit, each as wide as its label.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (onOpenSettings != null)
                  IntrinsicWidth(
                    child: SheetButton(label: settingsLabel, kind: SheetButtonKind.secondary, onTap: onOpenSettings),
                  ),
                IntrinsicWidth(
                  child: SheetButton(label: tryAgainLabel, kind: SheetButtonKind.secondary, onTap: onTryAgain),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(label, style: context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted)),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
