import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/l10n/app_localizations.dart';
import 'package:quantus_desktop_wallet/providers/controllers/cold_sign_flow.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/providers/settings_providers.dart';
import 'package:quantus_desktop_wallet/providers/simulation_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/camera_scanner_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/copyable_text.dart';
import 'package:quantus_desktop_wallet/ui/components/explorer_link.dart';
import 'package:quantus_desktop_wallet/ui/components/scan_strings.dart';
import 'package:quantus_desktop_wallet/ui/components/sign_step_indicator.dart';
import 'package:quantus_desktop_wallet/ui/components/success_mark.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

/// What the user is signing, as the dialog shows it next to the QR code.
class ColdSignDetails {
  final String amount;
  final String recipient;
  final String? recipientCheckphrase;

  const ColdSignDetails({required this.amount, required this.recipient, this.recipientCheckphrase});
}

/// Runs [flow] in a modal dialog. Resolves with the extrinsic hash once the
/// transaction is submitted, or null when the user backs out.
Future<String?> showSignFlowDialog(
  BuildContext context, {
  required ColdSignFlow flow,
  required ColdSignDetails details,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(48),
      child: SignFlowDialog(flow: flow, details: details),
    ),
  );
}

class SignFlowDialog extends ConsumerStatefulWidget {
  final ColdSignFlow flow;
  final ColdSignDetails details;

  const SignFlowDialog({super.key, required this.flow, required this.details});

  @override
  ConsumerState<SignFlowDialog> createState() => _SignFlowDialogState();
}

class _SignFlowDialogState extends ConsumerState<SignFlowDialog> {
  final UrScanCollector _collector = UrScanCollector();
  bool _paused = false;

  ColdSignFlow get flow => widget.flow;

  @override
  void initState() {
    super.initState();
    flow.addListener(_rebuild);
    flow.prepare();
  }

  @override
  void dispose() {
    flow.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  Future<void> _cancel() async {
    final l10n = ref.read(l10nProvider);
    if (flow.step == ColdSignStep.scan && _collector.parts.isNotEmpty) {
      final stop = await showQuantusDialog(
        context,
        title: l10n.signDiscardTitle,
        body: l10n.signDiscardBody,
        actionLabel: l10n.signDiscardAction,
        cancelLabel: l10n.commonCancel,
        isDestructive: true,
      );
      if (!stop) return;
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final stepIndex = switch (flow.step) {
      ColdSignStep.show => 0,
      ColdSignStep.verify || ColdSignStep.rejected => 1,
      ColdSignStep.scan || ColdSignStep.success => 2,
    };
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _cancel},
      child: Focus(
        autofocus: true,
        child: QuantusDialogFrame(
          maxWidth: 800,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(l10n.signTitle, style: text.titleScreen.copyWith(color: colors.textContent)),
                  ),
                  if (flow.step != ColdSignStep.success)
                    QuantusIconButton.ghost(icon: Icons.close_rounded, size: IconButtonSize.small, onTap: _cancel),
                ],
              ),
              const SizedBox(height: 12),
              SignStepIndicator(
                labels: [l10n.signStepShow, l10n.signStepVerify, l10n.signStepScan],
                current: stepIndex,
              ),
              const SizedBox(height: 24),
              switch (flow.step) {
                ColdSignStep.show => _show(l10n),
                ColdSignStep.verify => _verify(l10n),
                ColdSignStep.rejected => _rejected(l10n),
                ColdSignStep.scan => _scan(l10n),
                ColdSignStep.success => _success(l10n),
              },
            ],
          ),
        ),
      ),
    );
  }

  Widget _details(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.signYouAreSigning, style: text.labelData.copyWith(color: colors.textContent)),
        const SizedBox(height: 8),
        DetailSummaryRow.review(label: l10n.signAmount.toUpperCase(), value: widget.details.amount),
        const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: MenuDivider()),
        DetailSummaryRow.review(
          label: l10n.signTo.toUpperCase(),
          value: AddressFormattingService.formatAddress(widget.details.recipient),
          checkphrase: widget.details.recipientCheckphrase,
        ),
      ],
    );
  }

  String _countdown(Duration left) {
    final minutes = left.inMinutes;
    final seconds = left.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _show(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final settings = ref.watch(qrDisplaySettingsProvider);
    final request = flow.request;
    final issue = flow.issue;
    final remaining = flow.remaining;
    final qrSize = (MediaQuery.sizeOf(context).height - 96 - 260).clamp(300.0, 400.0);
    final qr = SizedBox(
      width: qrSize,
      height: qrSize,
      child: request == null
          ? Center(
              child: issue == ColdSignIssue.prepareFailed
                  ? Text(
                      l10n.signPrepareFailed,
                      style: text.caption.copyWith(color: colors.semanticEmber),
                      textAlign: TextAlign.center,
                    )
                  : const Loader(size: 24),
            )
          : AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Container(
                key: ValueKey(request),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.borderHairline),
                  borderRadius: context.radiusV3.mdBorder,
                ),
                child: AnimatedUrQr(parts: request.urParts, size: qrSize, fps: settings.fps, paused: _paused),
              ),
            ),
    );
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _details(l10n),
        const SizedBox(height: 16),
        Text(l10n.signShowInstruction, style: text.caption.copyWith(color: colors.textMuted)),
        if (remaining != null) ...[
          const SizedBox(height: 8),
          Text(l10n.signValidFor(_countdown(remaining)), style: text.labelData.copyWith(color: colors.textMuted)),
        ],
        if (flow.refreshed) ...[
          const SizedBox(height: 8),
          Text(l10n.signRefreshed, style: text.caption.copyWith(color: colors.semanticSand)),
        ],
        if (issue == ColdSignIssue.expired) ...[
          const SizedBox(height: 8),
          Text(l10n.signExpired, style: text.caption.copyWith(color: colors.semanticEmber)),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: QuantusButton.simple(
                label: l10n.signScannedContinue,
                isDisabled: request == null,
                onTap: flow.continueToVerify,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: _paused ? l10n.signResume : l10n.signPause,
              child: QuantusIconButton.ghost(
                icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onTap: request == null ? null : () => setState(() => _paused = !_paused),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (issue == ColdSignIssue.prepareFailed)
          QuantusButton.simple(label: l10n.commonTryAgain, variant: ButtonVariant.staged, onTap: flow.prepare),
        QuantusButton.simple(label: l10n.commonCancel, variant: ButtonVariant.underline, onTap: _cancel),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth >= 680
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                qr,
                const SizedBox(width: 32),
                Expanded(child: side),
              ],
            )
          : Column(children: [qr, const SizedBox(height: 24), side]),
    );
  }

  Widget _verify(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.signVerifyInstruction, style: text.body.copyWith(color: colors.textMuted, height: 1.55)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: colors.bgSurface2, borderRadius: context.radiusV3.mdBorder),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.details.amount, style: text.amountHero.copyWith(color: colors.textContent)),
              const SizedBox(height: 12),
              AddressCheckphrase(
                address: widget.details.recipient,
                checkphrase: widget.details.recipientCheckphrase,
                addressStyle: text.dataAddressLarge,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        QuantusBanner(tone: BannerTone.ember, message: l10n.signVerifyWarning),
        const SizedBox(height: 20),
        QuantusButton.simple(label: l10n.signMatches, onTap: flow.matches),
        const SizedBox(height: 8),
        QuantusButton.simple(label: l10n.signMismatch, variant: ButtonVariant.underline, onTap: flow.mismatch),
      ],
    );
  }

  Widget _rejected(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.signRejectedTitle, style: text.headingRow.copyWith(color: colors.textContent)),
        const SizedBox(height: 8),
        Text(l10n.signRejectedBody, style: text.body.copyWith(color: colors.textMuted, height: 1.55)),
        const SizedBox(height: 20),
        QuantusButton.simple(
          label: l10n.signRejectedDone,
          variant: ButtonVariant.danger,
          onTap: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Future<void> _simulateSignature(SimulatedColdWallet simulated) async {
    final request = flow.request;
    if (request == null || flow.submitting) return;
    try {
      await flow.onSignature(simulated.signRequest(request.unsignedData));
    } on ColdSignerMismatchException catch (_) {
      // Shown by the scan step through flow.issue.
    } on ColdSignatureInvalidException catch (_) {
      // Shown by the scan step through flow.issue.
    }
  }

  Widget _scan(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final issue = flow.issue;
    final simulated = ref.watch(simulatedColdWalletProvider);
    final canSimulate = simulated != null && simulated.address == flow.account.accountId;
    final issueText = switch (issue) {
      ColdSignIssue.wrongSigner => l10n.signWrongSigner,
      ColdSignIssue.invalidSignature => l10n.signInvalid,
      ColdSignIssue.submitFailed => l10n.signSubmitFailed(flow.issueDetail ?? ''),
      ColdSignIssue.aborted => flow.issueDetail,
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(l10n.signScanInstruction, style: text.caption.copyWith(color: colors.textMuted)),
        const SizedBox(height: 12),
        Stack(
          children: [
            CameraScannerPanel(
              collector: _collector,
              onComplete: flow.onSignature,
              strings: scanStringsFor(l10n, idleHint: l10n.signScanInstruction),
            ),
            if (flow.submitting)
              Positioned.fill(
                child: ColoredBox(
                  color: colors.bgVoid.useOpacity(0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Loader(size: 24),
                        const SizedBox(height: 12),
                        Text(l10n.signSubmitting, style: text.body.copyWith(color: colors.textContent)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (issueText != null) ...[
          const SizedBox(height: 12),
          QuantusBanner(tone: BannerTone.ember, message: issueText),
        ],
        const SizedBox(height: 16),
        if (canSimulate) ...[
          QuantusButton.simple(
            label: l10n.signSimulate,
            variant: ButtonVariant.danger,
            isLoading: flow.submitting,
            onTap: () => _simulateSignature(simulated),
          ),
          const SizedBox(height: 8),
        ],
        if (issue == ColdSignIssue.submitFailed)
          QuantusButton.simple(label: l10n.commonTryAgain, onTap: flow.retrySubmit)
        else if (issue != ColdSignIssue.aborted)
          QuantusButton.simple(label: l10n.signRejectedOnDevice, variant: ButtonVariant.ghost, onTap: flow.mismatch),
        const SizedBox(height: 8),
        QuantusButton.simple(label: l10n.commonCancel, variant: ButtonVariant.underline, onTap: _cancel),
      ],
    );
  }

  Widget _success(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final hash = flow.extrinsicHash!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Center(child: SuccessMark()),
        const SizedBox(height: 16),
        Text(
          l10n.signSuccessTitle,
          style: text.titleSuccess.copyWith(color: colors.textContent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _details(l10n),
        const SizedBox(height: 16),
        Row(
          children: [
            QuantusBadge(label: l10n.txDetailStatusPending, tone: BadgeTone.glacier, dot: true),
            const SizedBox(width: 8),
            Text(l10n.signSuccessPending, style: text.caption.copyWith(color: colors.textMuted)),
          ],
        ),
        const SizedBox(height: 8),
        CopyableText(value: hash, copiedMessage: l10n.commonCopied),
        ExplorerLink(extrinsicHash: hash, label: l10n.accountOpenExplorer),
        const SizedBox(height: 16),
        QuantusButton.simple(label: l10n.commonDone, onTap: () => Navigator.pop(context, hash)),
      ],
    );
  }
}
