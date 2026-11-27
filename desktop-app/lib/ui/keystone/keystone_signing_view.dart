import 'dart:async';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:desktop_qr_camera/desktop_qr_camera.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/keystone_signing_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/services/qr_scan_source.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_address_checkphrase.dart';
import 'package:quantus_desktop_wallet/ui/components/notice_box.dart';
import 'package:quantus_desktop_wallet/ui/components/qr_camera_box.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/keystone_sign_cache.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/keystone_signing_session.dart';
import 'package:wallet_core/services/telemetry.dart';

/// Where the signing is: the request shown, the cold wallet's screen checked
/// while its signature is scanned back, or the guide for a cold wallet that
/// showed something else.
enum _Stage { show, checkAndScan, mismatch }

/// Signing [session] on a cold wallet, inside a sheet: the request is shown
/// as an animated QR code for the cold wallet to scan, then what the cold
/// wallet must show is set above the camera, which reads its signature back.
/// Once the signature is handed to the network, [onSigned] has its hash.
///
/// [onLeave] goes back to where the signing was asked for, nothing signed.
/// [onSubmitting] says when the signature is being handed over, which
/// cannot be interrupted.
class KeystoneSigningView extends ConsumerStatefulWidget {
  const KeystoneSigningView({
    super.key,
    required this.session,
    required this.account,
    required this.parentTitle,
    required this.onLeave,
    required this.onSubmitting,
    required this.onSigned,
  });

  final KeystoneSigningSession session;

  /// The account the header names.
  final BaseAccount account;

  /// The title of the sheet the signing is a step of.
  final String parentTitle;
  final VoidCallback onLeave;
  final ValueChanged<bool> onSubmitting;
  final ValueChanged<String> onSigned;

  static const continueKey = Key('keystone-continue');
  static const cancelKey = Key('keystone-cancel');
  static const backKey = Key('keystone-back');
  static const mismatchKey = Key('keystone-mismatch');
  static const rejectedKey = Key('keystone-rejected');
  static const supportKey = Key('keystone-support');

  /// How often the request on screen is checked for its age.
  static const freshnessCheck = Duration(seconds: 5);

  @override
  ConsumerState<KeystoneSigningView> createState() => _KeystoneSigningViewState();
}

class _KeystoneSigningViewState extends ConsumerState<KeystoneSigningView> {
  static const double _qrSize = 232;
  static const double _cameraWidth = 300;

  _Stage _stage = _Stage.show;

  // ------------------------------------------------------------ the request
  UnsignedTransactionData? _unsigned;
  List<String>? _parts;
  DateTime? _storedAt;
  bool _isPreparing = false;
  bool _prepareFailed = false;
  late final Timer _freshness;

  // ------------------------------------------------------- the scan back
  late final QrScanSource _camera = ref.read(animatedQrScanSourceFactoryProvider)();
  late final UrScanAccumulator _collector = ref.read(signatureCollectorFactoryProvider)();
  StreamSubscription<String>? _reads;

  /// One preview for the view's life, so a rebuild never reattaches it.
  late final Widget _preview = _camera.buildPreview();
  QrCameraFailure? _cameraFailure;
  ({int scanned, int? total})? _progress;
  bool _isSubmitting = false;

  /// The signature came back too late: the request shown is over, and a new
  /// one is shown on the way back.
  bool _expired = false;
  String? _scanError;

  @override
  void initState() {
    super.initState();
    _freshness = Timer.periodic(KeystoneSigningView.freshnessCheck, (_) {
      if (_stage == _Stage.show && _isStale) unawaited(_prepare());
    });
    _reads = _camera.reads.listen(_onRead, onError: _onCameraError);
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _freshness.cancel();
    unawaited(_reads?.cancel());
    unawaited(_disposeCamera());
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    try {
      await _camera.dispose();
    } catch (e) {
      quantusPrint('Turning the camera off failed: $e');
    }
  }

  // ------------------------------------------------------------ the request

  /// The request on screen has used up its era's reserve: what is left of
  /// its life no longer covers a trip through the cold wallet.
  bool get _isStale {
    final unsigned = _unsigned;
    final storedAt = _storedAt;
    if (unsigned == null || storedAt == null) return false;
    return isKeystonePayloadStale(unsigned.payloadToSign, storedAt: storedAt, now: clock.now());
  }

  Future<void> _prepare() async {
    if (_isPreparing) return;
    _isPreparing = true;
    setState(() => _prepareFailed = false);
    // Read now: the sheet may be gone when the request is built.
    final telemetry = ref.read(telemetryProvider);
    try {
      final payload = await ensureKeystoneSignPayload(
        ref,
        account: widget.session.account,
        buildCall: widget.session.buildCall,
        cacheKey: widget.session.cacheKey,
      );
      telemetry.sendEvent('${widget.session.telemetryPrefix}_payload_ready');
      if (!mounted) return;
      setState(() {
        _unsigned = payload.unsignedData;
        _parts = payload.urParts;
        _storedAt = payload.storedAt;
      });
    } catch (e, st) {
      quantusPrint('Preparing the cold wallet request failed: $e\n$st');
      telemetry.sendError('Keystone payload preparation failed', error: e);
      if (mounted) setState(() => _prepareFailed = true);
    } finally {
      _isPreparing = false;
    }
  }

  /// Forgets the request on screen and builds another.
  void _prepareAnew() {
    setState(() {
      _unsigned = null;
      _parts = null;
      _storedAt = null;
    });
    unawaited(_prepare());
  }

  // ------------------------------------------------------------- the steps

  void _toCheckAndScan() {
    if (_unsigned == null) return;
    // A request near its end never goes to the cold wallet: it is built
    // again for the cold wallet to scan.
    if (_isStale) {
      unawaited(_prepare());
      return;
    }
    _startScan();
  }

  void _startScan() {
    _collector.reset();
    setState(() {
      _stage = _Stage.checkAndScan;
      _progress = null;
      _scanError = null;
      _expired = false;
      _cameraFailure = null;
    });
    // After the frame: the macOS camera needs its preview in the tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _stage == _Stage.checkAndScan) unawaited(_startCamera());
    });
  }

  void _backToShow() {
    if (_isSubmitting) return;
    unawaited(_stopCamera());
    final expired = _expired;
    setState(() {
      _stage = _Stage.show;
      _expired = false;
      _scanError = null;
    });
    if (expired) _prepareAnew();
  }

  void _toMismatch() {
    if (_isSubmitting) return;
    unawaited(_stopCamera());
    setState(() => _stage = _Stage.mismatch);
  }

  void _leave() {
    if (_isSubmitting) return;
    unawaited(_stopCamera());
    widget.onLeave();
  }

  void _back() => switch (_stage) {
    _Stage.show => _leave(),
    _Stage.checkAndScan => _backToShow(),
    _Stage.mismatch => _startScan(),
  };

  // ------------------------------------------------------------- the camera

  Future<void> _startCamera() async {
    if (mounted) setState(() => _cameraFailure = null);
    try {
      await _camera.start();
    } on QrCameraException catch (error) {
      quantusPrint('The camera did not start: $error');
      if (mounted) setState(() => _cameraFailure = error.failure);
    }
  }

  Future<void> _stopCamera() async {
    try {
      await _camera.stop();
    } on QrCameraException catch (error) {
      quantusPrint('Turning the camera off failed: $error');
    }
  }

  void _onCameraError(Object error) {
    quantusPrint('The camera stopped: $error');
    if (!mounted) return;
    setState(() => _cameraFailure = error is QrCameraException ? error.failure : QrCameraFailure.failed);
  }

  void _onRead(String code) {
    if (_stage != _Stage.checkAndScan || _isSubmitting || _expired) return;
    final l10n = ref.read(l10nProvider);
    switch (_collector.add(code)) {
      case UrScanIgnored():
        return;
      case UrScanProgress(:final scanned, :final total):
        setState(() {
          _progress = (scanned: scanned, total: total);
          _scanError = null;
        });
      case UrScanOverflow():
      case UrScanFailed():
        setState(() {
          _progress = null;
          _scanError = l10n.keystoneScanError;
        });
      case UrScanComplete(:final payload):
        unawaited(_submit(payload));
    }
  }

  Future<void> _submit(Uint8List signature) async {
    final unsigned = _unsigned;
    if (unsigned == null) throw StateError('A signature came back for no request.');
    setState(() {
      _isSubmitting = true;
      _scanError = null;
    });
    widget.onSubmitting(true);
    final telemetry = ref.read(telemetryProvider);
    String? hash;
    try {
      // Checks its length; the signature's scheme is read back off it.
      DilithiumSchemeExtension.forSignatureWithPublicKeyLength(signature.length);
      await ensureKeystoneEraNotExpired(
        unsigned.payloadToSign,
        currentBlock: ref.read(substrateServiceProvider).getCurrentBlockNumber,
      );
      hash = await widget.session.submitSigned(ref, unsignedData: unsigned, signatureWithPublicKey: signature);
      telemetry.sendEvent('${widget.session.telemetryPrefix}_submitted');
    } on KeystoneEraExpiredException catch (error) {
      quantusPrint('The cold wallet\'s signature came back too late: $error');
      telemetry.sendError('Keystone signature processing failed', error: error);
      if (mounted) {
        unawaited(_stopCamera());
        setState(() {
          _expired = true;
          _progress = null;
          _scanError = ref.read(l10nProvider).keystoneScanExpired;
        });
      }
    } catch (e, st) {
      quantusPrint('Handing the cold wallet\'s signature over failed: $e\n$st');
      telemetry.sendError('Keystone signature processing failed', error: e);
      _collector.reset();
      if (mounted) {
        setState(() {
          _progress = null;
          _scanError = ref.read(l10nProvider).keystoneScanError;
        });
      }
    } finally {
      // Signed or not, the request is not shown again.
      ref.read(keystoneSignCacheProvider.notifier).reset();
      if (mounted) setState(() => _isSubmitting = false);
      widget.onSubmitting(false);
    }
    if (hash != null && mounted) widget.onSigned(hash);
  }

  // ---------------------------------------------------------------- drawing

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final isMismatch = _stage == _Stage.mismatch;
    return PopScope(
      canPop: !_isSubmitting,
      child: SheetBackShortcut(
        onBack: _isSubmitting ? null : _back,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ShellSheetHeader(
              title: isMismatch ? l10n.keystoneVerifyMismatch : l10n.keystoneSignScreenTitle,
              account: widget.account,
              parent: (title: widget.parentTitle, onBack: _back),
            ),
            ...switch (_stage) {
              _Stage.show => _show(context, l10n),
              _Stage.checkAndScan => _checkAndScan(context, l10n),
              _Stage.mismatch => _mismatch(context, l10n),
            },
          ],
        ),
      ),
    );
  }

  List<Widget> _show(BuildContext context, AppLocalizations l10n) => [
    const SizedBox(height: 16),
    _StepStrip(current: 1, names: [l10n.desktopKeystoneStepShow, l10n.desktopKeystoneStepCheckAndScan]),
    const SizedBox(height: 20),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(dimension: _qrSize, child: _request(context, l10n)),
        const SizedBox(width: 28),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DeviceSteps(
                heading: l10n.desktopKeystoneOnColdWallet,
                steps: [
                  l10n.desktopKeystoneShowStepScan,
                  l10n.desktopKeystoneShowStepHold,
                  l10n.desktopKeystoneShowStepContinue,
                ],
              ),
              const SizedBox(height: 18),
              for (final (index, detail) in _details(context, l10n).indexed) ...[
                if (index > 0) const SizedBox(height: 14),
                detail,
              ],
            ],
          ),
        ),
      ],
    ),
    const SizedBox(height: 22),
    _Buttons(
      buttons: [
        SheetButton(
          key: KeystoneSigningView.cancelKey,
          label: l10n.commonCancel,
          kind: SheetButtonKind.secondary,
          onTap: _leave,
        ),
        SheetButton(
          key: KeystoneSigningView.continueKey,
          label: l10n.commonContinue,
          isDisabled: _unsigned == null,
          onTap: _toCheckAndScan,
        ),
      ],
    ),
  ];

  Widget _request(BuildContext context, AppLocalizations l10n) {
    if (_prepareFailed) {
      return Center(
        child: Text(
          l10n.keystoneSignError,
          textAlign: TextAlign.center,
          style: context.sendBody(color: context.colorsV3.semanticEmber),
        ),
      );
    }
    final parts = _parts;
    if (parts == null) return const Center(child: Loader());
    return AnimatedUrQr(parts: parts, fps: 10, size: _qrSize);
  }

  /// What is being signed: the amount, then who is paid, whole, over its
  /// checkphrase.
  List<Widget> _details(BuildContext context, AppLocalizations l10n) {
    final session = widget.session;
    final primary = session.primaryDetail;
    final secondary = session.secondaryDetail?.trim();
    return [
      if (primary != null)
        _Detail(
          label: session.primaryLabel ?? l10n.sendReviewAmount,
          child: Text(
            primary,
            // An amount reads as a figure; words, such as a whole balance or
            // an action, read as running text.
            style: session.primaryIsAmount
                ? context.themeTextV3.amountRow.copyWith(color: context.colorsV3.textContent)
                : context.sendBody(color: context.colorsV3.textContent),
          ),
        ),
      if (secondary != null)
        _Detail(
          label: session.secondaryLabel ?? l10n.sendReviewTo,
          child: session.secondaryIsAddress
              ? DesktopAddressCheckphrase(address: secondary, isCompact: true)
              : Text(secondary, style: context.sendBody(color: context.colorsV3.textContent)),
        ),
    ];
  }

  List<Widget> _checkAndScan(BuildContext context, AppLocalizations l10n) {
    final colors = context.colorsV3;
    return [
      const SizedBox(height: 16),
      _StepStrip(current: 2, names: [l10n.desktopKeystoneStepShow, l10n.desktopKeystoneStepCheckAndScan]),
      const SizedBox(height: 20),
      CapsText(l10n.desktopKeystoneCheckTitle, style: context.sendCaps(spacing: 2)),
      const SizedBox(height: 8),
      Text(l10n.desktopKeystoneCheckBody, style: context.sendBody()),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: colors.bgVoid, borderRadius: context.radiusV3.mdBorder),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, detail) in _details(context, l10n).indexed)
              if (index == 0)
                // Words, such as a whole balance, get the room to stay on a line or two.
                SizedBox(width: widget.session.primaryIsAmount ? 110 : 200, child: detail)
              else
                Expanded(child: detail),
          ],
        ),
      ),
      const SizedBox(height: 18),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _DeviceSteps(
              heading: l10n.desktopKeystoneThen,
              steps: [l10n.desktopKeystoneScanStepHold, l10n.desktopKeystoneScanStepKeep],
            ),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: _cameraWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                QrCameraBox(
                  preview: _preview,
                  width: _cameraWidth,
                  failure: _cameraFailure,
                  onTryAgain: () => unawaited(_startCamera()),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(constraints: const BoxConstraints(minHeight: 20), child: _scanStatus(context, l10n)),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _Buttons(
        leading: [
          SheetButton(
            key: KeystoneSigningView.mismatchKey,
            label: l10n.keystoneVerifyMismatch,
            kind: SheetButtonKind.destructive,
            isDisabled: _isSubmitting,
            onTap: _toMismatch,
          ),
        ],
        buttons: [
          SheetButton(
            key: KeystoneSigningView.backKey,
            label: l10n.commonBack,
            kind: SheetButtonKind.secondary,
            isDisabled: _isSubmitting,
            onTap: _backToShow,
          ),
          SheetButton(
            key: KeystoneSigningView.cancelKey,
            label: l10n.commonCancel,
            kind: SheetButtonKind.secondary,
            isDisabled: _isSubmitting,
            onTap: _leave,
          ),
        ],
      ),
    ];
  }

  Widget _scanStatus(BuildContext context, AppLocalizations l10n) {
    // The camera's box says why it shows nothing.
    if (_cameraFailure != null && !_isSubmitting && _scanError == null) return const SizedBox.shrink();
    if (_isSubmitting) return TerminalBusyLine(label: l10n.keystoneScanSubmitting);
    final error = _scanError;
    if (error != null) {
      return Semantics(
        liveRegion: true,
        child: Text(error, style: context.sendBody(color: context.colorsV3.semanticEmber)),
      );
    }
    final progress = _progress;
    if (progress == null) return TerminalBusyLine(label: l10n.desktopColdWalletLooking);
    final total = progress.total;
    return TerminalLine(
      name: l10n.keystoneScanReceiving,
      status: total == null ? '${progress.scanned}' : '${progress.scanned}/$total',
      isBusy: true,
    );
  }

  List<Widget> _mismatch(BuildContext context, AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final steps = [
      (l10n.keystoneRejectStep1Title, l10n.keystoneRejectStep1Body),
      (l10n.desktopKeystoneRejectStep2Title, l10n.desktopKeystoneRejectStep2Body),
      (l10n.keystoneRejectStep3Title, l10n.desktopKeystoneRejectStep3Body),
    ];
    return [
      const SizedBox(height: 18),
      Text(l10n.keystoneRejectTitle, style: text.titleScreen.copyWith(color: colors.semanticEmber)),
      const SizedBox(height: 14),
      NoticeBox(
        tone: colors.semanticEmber,
        symbol: CupertinoIcons.exclamationmark_triangle_fill,
        child: Text(l10n.keystoneVerifyWarning, style: text.body.copyWith(color: colors.textContent)),
      ),
      const SizedBox(height: 18),
      for (final (index, (title, body)) in steps.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 30,
                child: Text('0${index + 1}', style: text.dataAddressLarge.copyWith(color: colors.accentFlare)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.bodyEmphasis.copyWith(color: colors.textContent)),
                    const SizedBox(height: 3),
                    Text(body, style: context.sendBody()),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 14),
      Text(l10n.commonSupportScamWarning, style: text.caption.copyWith(color: colors.textMuted2)),
      const SizedBox(height: 8),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: ToolbarAction.symbol(
          key: KeystoneSigningView.supportKey,
          symbol: CupertinoIcons.chat_bubble_2,
          label: l10n.commonContactSupport,
          onPressed: () => unawaited(ref.read(openExternalUrlProvider)(Uri.parse(AppConstants.discordSupportUrl))),
        ),
      ),
      const SizedBox(height: 16),
      _Buttons(
        buttons: [SheetButton(key: KeystoneSigningView.rejectedKey, label: l10n.keystoneRejectConfirm, onTap: _leave)],
      ),
    ];
  }
}

/// The signing's steps, the current one in the accent, those done in sage.
class _StepStrip extends StatelessWidget {
  const _StepStrip({required this.current, required this.names});

  /// Counted from 1.
  final int current;
  final List<String> names;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    return Row(
      children: [
        for (var i = 0; i < names.length; i++) ...[
          if (i > 0) ...[const SizedBox(width: 10), Text('—', style: context.sendCaps()), const SizedBox(width: 10)],
          CapsText(
            '${i + 1}  ${names[i]}',
            style: context.sendCaps(
              spacing: 1.6,
              color: i == current - 1
                  ? colors.accentFlare
                  : i < current - 1
                  ? colors.semanticSage
                  : colors.textMuted2,
            ),
          ),
        ],
      ],
    );
  }
}

/// What to do on the cold wallet, numbered.
class _DeviceSteps extends StatelessWidget {
  const _DeviceSteps({required this.heading, required this.steps});

  final String heading;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CapsText(heading, style: context.sendCaps(spacing: 2)),
        const SizedBox(height: 10),
        for (final (index, words) in steps.indexed)
          Padding(
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
                  child: Text('${index + 1}', style: text.caption.copyWith(height: 1, color: colors.textContent)),
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
          ),
      ],
    );
  }
}

/// A detail of what is being signed, under its label.
class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      CapsText(label, style: context.sendCaps()),
      const SizedBox(height: 8),
      child,
    ],
  );
}

/// The sheet's buttons: [leading] at the left, [buttons] at the right, the
/// default one last.
class _Buttons extends StatelessWidget {
  const _Buttons({required this.buttons, this.leading = const []});

  final List<Widget> buttons;
  final List<Widget> leading;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ...leading,
      const Spacer(),
      for (final (index, button) in buttons.indexed) ...[if (index > 0) const SizedBox(width: 10), button],
    ],
  );
}
