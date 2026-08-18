import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/animated_ur_qr.dart';
import 'package:quantus_cold_wallet/components/call_detail_view.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/titled_sheet.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// Reviews a scanned signing payload and, on approval, produces the signature QR.
///
/// The two questions that decide whether a signature is safe — how much, and to
/// whom — are answered above the fold, in the largest type on the screen. Every
/// call parameter the summary does not already show is listed under it; only the
/// signed extensions and the raw bytes, which no signer verifies by eye, live
/// behind the Advanced disclosure.
class SignTransactionScreen extends ConsumerStatefulWidget {
  final Uint8List payload;
  const SignTransactionScreen({super.key, required this.payload});

  @override
  ConsumerState<SignTransactionScreen> createState() => _SignTransactionScreenState();
}

class _SignTransactionScreenState extends ConsumerState<SignTransactionScreen> {
  ParsedPayload? _parsed;
  String? _parseError;
  Uint8List? _signed;
  List<String>? _urParts;
  int? _urPartsBytes;
  bool _qrPaused = false;
  bool _signing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _parsed = QuantusPayloadParser.parsePayload(widget.payload, policy: const FullCallPolicy());
    } catch (e) {
      debugPrint('Rejected signing payload: $e');
      _parseError = e is FormatException ? e.message : e.toString();
    }
  }

  void _sign() {
    final keypair = ref.read(keypairProvider);
    if (keypair == null) {
      setState(() => _error = 'Wallet is locked — unlock and try again. Nothing was signed.');
      return;
    }
    setState(() {
      _signing = true;
      _error = null;
    });

    try {
      // Returns signature ++ publicKey; the hot wallet splits it and rebuilds the
      // extrinsic via submitExtrinsicWithExternalSignature.
      final signed = signMessageWithPubkey(
        keypair: keypair,
        message: QuantusSigningPayload.signablePayload(widget.payload),
      );
      setState(() {
        _signing = false;
        _signed = signed;
      });
    } catch (e) {
      setState(() {
        _signing = false;
        _error = 'Signing failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_parseError != null) return _errorView(context, _parseError!);
    if (_signed != null) return _signatureView(context, _signed!);
    return _reviewView(context, _parsed!);
  }

  Widget _errorView(BuildContext context, String reason) {
    final colors = context.colors;
    final text = context.themeText;
    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Sign Transaction'),
      mainContent: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colors.error),
          const SizedBox(height: 24),
          Text('Could not read transaction', style: text.mediumTitle?.copyWith(color: colors.textPrimary)),
          const SizedBox(height: 12),
          Text(
            'This QR code is not a transaction this wallet can read in full, so it will not be signed. '
            'Nothing was signed.',
            style: text.smallParagraph?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            reason,
            style: text.detail?.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Back to home', onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ),
    );
  }

  Widget _reviewView(BuildContext context, ParsedPayload parsed) {
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Review & Sign'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            if (!parsed.specMatchesBundled) _specDriftBanner(context, parsed.extensions),
            // The headline is an opinionated human summary (SEND / REVERSIBLE
            // SEND / …) by design; the exact pallet · call chain is the Call
            // line in the Advanced sheet. See [DecodedCall.actionTitle].
            Text(
              parsed.call.actionTitle,
              style: text.mediumTitle?.copyWith(color: colors.accentOrange, letterSpacing: 1.2),
            ),
            ..._callBody(context, parsed.call),
            const SizedBox(height: 20),
            _advancedSection(context, parsed),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: text.detail?.copyWith(color: colors.error),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Row(
          children: [
            Expanded(
              child: QuantusButton.simple(
                label: 'Cancel',
                variant: ButtonVariant.secondary,
                onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: QuantusButton.simple(label: 'Sign', isLoading: _signing, onTap: _signing ? null : _sign),
            ),
          ],
        ),
      ),
    );
  }

  /// What is being authorised, then who is authorising it, then the parameters
  /// neither of those already showed.
  ///
  /// A call that dispatches another one — a multisig approval, a batch — leads
  /// with the boxed inner call: the amount and recipient inside it are what the
  /// signer is really approving, and the wrapper's own parameters (which
  /// multisig, which proposal) are context that follows.
  ///
  /// The signer's row claims `From` only when the summary shows a plain send
  /// and the call names no other account the funds could leave instead — a
  /// `force_transfer` moves its Source's funds, not the signer's. Anything
  /// else says no more than `Signed by`.
  List<Widget> _callBody(BuildContext context, DecodedCall call) {
    final signerAddress = ref.watch(addressProvider);
    final transfer = heroSummary(call);
    final fromSigner =
        transfer?.recipient != null &&
        !call.fields.any(
          (f) => f is ValueField && f.kind == ValueKind.address && !identical(f, transfer!.recipientField),
        );
    final signer = signerAddress == null
        ? null
        : AddressWithCheckphrase(label: fromSigner ? 'From' : 'Signed by', address: signerAddress);

    if (!call.isWrapper) return [...callSummaryBody(call), ?signer];

    return [
      for (final field in call.fields.whereType<NestedCallField>()) CallFieldView(field: field),
      ?signer,
      for (final field in call.fields.where((f) => f is! NestedCallField)) CallFieldView(field: field),
    ];
  }

  /// Everything a signer never verifies by eye: the signed extensions and the
  /// bytes themselves, listed plainly for the rare reader who wants them.
  Widget _advancedSection(BuildContext context, ParsedPayload parsed) {
    final colors = context.colors;
    final text = context.themeText;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showTitledSheet(
        context,
        title: 'Advanced',
        child: Text(
          _advancedLines(parsed).join('\n'),
          style: text.detail?.copyWith(color: colors.textMuted, fontFamily: AppTextTheme.fontFamilySecondary),
        ),
      ),
      child: Row(
        children: [
          Text('ADVANCED', style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 18, color: colors.textLabel),
        ],
      ),
    );
  }

  List<String> _advancedLines(ParsedPayload parsed) {
    final ext = parsed.extensions;
    return [
      // The one place the runtime's own naming appears, nested calls included —
      // the headlines above deliberately summarise it away.
      'Call: ${parsed.call.displayTitleChain}',
      'Network: ${parsed.network}',
      'Runtime: spec ${ext.specVersion}, tx version ${ext.transactionVersion}',
      'Nonce: ${ext.nonce}',
      'Era: ${ext.era}',
      'Tip: ${NumberFormattingService().formatAmount(ext.tip)} ${AppConstants.tokenSymbol}',
      'Genesis hash: 0x${hex.encode(ext.genesisHash)}',
      'Block hash: 0x${hex.encode(ext.blockHash)}',
      'Metadata hash: ${ext.metadataHash == null ? 'none (check disabled)' : '0x${hex.encode(ext.metadataHash!)}'}',
      'Raw payload (${parsed.raw.length} bytes): 0x${hex.encode(parsed.raw)}',
    ];
  }

  Widget _specDriftBanner(BuildContext context, SignedExtensions ext) {
    final colors = context.colors;
    final text = context.themeText;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.error, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Built for a different runtime',
                  style: text.smallParagraph?.copyWith(color: colors.error, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'This payload targets spec ${ext.specVersion} / tx version ${ext.transactionVersion}, but this '
                  'wallet decodes spec ${AppConstants.bundledSpecVersion} / tx version '
                  '${AppConstants.bundledTransactionVersion}. Across runtime versions the same index can mean a '
                  'different call, so the parameters below may be mislabelled. Update the cold wallet before signing '
                  'anything you cannot verify another way.',
                  style: text.detail?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pauses the animation and opens the tuning sheet; resumes when it closes.
  Future<void> _pauseAndTune() async {
    setState(() => _qrPaused = true);
    await showTitledSheet(context, title: 'QR display options', child: const QrTuningControls());
    if (mounted) setState(() => _qrPaused = false);
  }

  Widget _signatureView(BuildContext context, Uint8List signed) {
    final colors = context.colors;
    final text = context.themeText;
    final settings = ref.watch(coldSettingsProvider);

    if (_urParts == null || _urPartsBytes != settings.qrBytes) {
      _urParts = encodeUrForQr(data: signed, maxFragmentLength: settings.qrBytes);
      _urPartsBytes = settings.qrBytes;
    }
    final parts = _urParts!;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Signature', showBackButton: false),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            Text(
              'Scan this with your hot wallet to broadcast the transaction.',
              style: text.smallParagraph?.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Center(
              child: AnimatedUrQr(parts: parts, fps: settings.qrFps, paused: _qrPaused),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${parts.length} ${parts.length == 1 ? 'frame' : 'frames'} · ${settings.qrFps} FPS · '
                  '${settings.qrBytes} bytes',
                  style: text.detail?.copyWith(color: colors.textMuted),
                ),
                if (parts.length > 1) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _pauseAndTune,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: colors.surfaceDeep, shape: BoxShape.circle),
                      child: Icon(Icons.pause_rounded, size: 20, color: colors.textPrimary),
                    ),
                  ),
                ],
              ],
            ),
            if (parts.length > 1) ...[
              const SizedBox(height: 16),
              Text(
                'Animated QR — keep both devices steady until the hot wallet finishes scanning.',
                style: text.detail?.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Done', onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ),
    );
  }
}
