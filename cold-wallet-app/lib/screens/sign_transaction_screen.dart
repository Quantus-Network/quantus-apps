import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide DecodedCallView;
import 'package:quantus_cold_wallet/components/decoded_call_view.dart';
import 'package:quantus_cold_wallet/components/qr_tuning_controls.dart';
import 'package:quantus_cold_wallet/providers/settings_providers.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

/// Reviews a scanned signing payload and, on approval, produces the signature QR.
///
/// Every parameter of the call — nested calls included — is on screen before the
/// Sign button becomes usable. There is no summarised or collapsed view: if a
/// byte is being signed, it is displayed. The Sign button stays disabled until
/// the parameter list has been scrolled to the end, so "I read it" is an action
/// rather than an assumption.
class SignTransactionScreen extends ConsumerStatefulWidget {
  final Uint8List payload;
  const SignTransactionScreen({super.key, required this.payload});

  @override
  ConsumerState<SignTransactionScreen> createState() => _SignTransactionScreenState();
}

class _SignTransactionScreenState extends ConsumerState<SignTransactionScreen> {
  final ScrollController _scrollController = ScrollController();

  ParsedPayload? _parsed;
  String? _parseError;
  Uint8List? _signed;
  List<String>? _urParts;
  int? _urPartsBytes;
  bool _qrPaused = false;
  bool _signing = false;
  bool _reviewedToEnd = false;
  bool _showRawPayload = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _parsed = QuantusPayloadParser.parsePayload(widget.payload);
    } catch (e) {
      debugPrint('Rejected signing payload: $e');
      _parseError = e is FormatException ? e.message : e.toString();
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_reviewedToEnd || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    if (position.pixels >= position.maxScrollExtent - 16) {
      setState(() => _reviewedToEnd = true);
    }
  }

  /// A payload short enough to fit on one screen has nothing to scroll, so the
  /// gate would never open — release it once layout confirms there is no overflow.
  ///
  /// Runs after the frame: during build the scroll position exists but has no
  /// content dimensions yet, and asking for its extent then throws.
  void _scheduleReviewGateCheck() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _reviewedToEnd || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (!position.hasContentDimensions) return;
      if (position.maxScrollExtent <= 0) setState(() => _reviewedToEnd = true);
    });
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Sign Transaction'),
      mainContent: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colors.semanticEmber),
          const SizedBox(height: 24),
          Text('Could not read transaction', style: text.titleScreen.copyWith(color: colors.textContent)),
          const SizedBox(height: 12),
          Text(
            'This QR code is not a transaction this wallet can read in full, so it will not be signed. '
            'Nothing was signed.',
            style: text.body.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            reason,
            style: text.caption.copyWith(color: colors.textMuted),
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final ext = parsed.extensions;
    final signerAddress = ref.watch(addressProvider);
    final signerCheckphrase = ref.watch(checkphraseProvider);

    _scheduleReviewGateCheck();

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Review & Sign'),
      mainContent: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            if (!parsed.specMatchesBundled) _specDriftBanner(ext),
            _hero(context, parsed),
            const SizedBox(height: 24),

            if (signerAddress != null)
              DetailSummaryRow.stacked(label: 'Signing as', value: signerAddress, monospace: true),
            signerCheckphrase.maybeWhen(
              data: (phrase) => phrase.isEmpty
                  ? const SizedBox.shrink()
                  : DetailSummaryRow.stacked(
                      label: 'Signing as checkphrase',
                      value: phrase,
                      valueColor: colors.semanticLilac,
                    ),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 8),
            Divider(color: colors.borderHairline),
            const SizedBox(height: 8),
            Text('CALL', style: _sectionLabel(text, colors)),
            const SizedBox(height: 8),
            DecodedCallView(call: parsed.call),

            const SizedBox(height: 16),
            Divider(color: colors.borderHairline),
            const SizedBox(height: 8),
            Text('SIGNED EXTENSIONS', style: _sectionLabel(text, colors)),
            DetailSummaryRow.stacked(label: 'Network', value: parsed.network),
            DetailSummaryRow.stacked(
              label: 'Runtime',
              value: 'spec ${ext.specVersion}, tx version ${ext.transactionVersion}',
            ),
            DetailSummaryRow.stacked(label: 'Nonce', value: '${ext.nonce}'),
            DetailSummaryRow.stacked(label: 'Era', value: '${ext.era}'),
            DetailSummaryRow.stacked(
              label: 'Tip',
              value: '${NumberFormattingService().formatAmount(ext.tip)} ${AppConstants.tokenSymbol}',
            ),
            DetailSummaryRow.stacked(label: 'Genesis hash', value: '0x${hex.encode(ext.genesisHash)}', monospace: true),
            DetailSummaryRow.stacked(label: 'Block hash', value: '0x${hex.encode(ext.blockHash)}', monospace: true),
            DetailSummaryRow.stacked(
              label: 'Metadata hash',
              value: ext.metadataHash == null ? 'None (check disabled)' : '0x${hex.encode(ext.metadataHash!)}',
              monospace: ext.metadataHash != null,
            ),

            const SizedBox(height: 16),
            _rawPayloadSection(context, parsed),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: text.caption.copyWith(color: colors.semanticEmber),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: Column(
          children: [
            if (!_reviewedToEnd)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Scroll through every parameter to enable signing.',
                  style: text.caption.copyWith(color: colors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            Row(
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
                  child: QuantusButton.simple(
                    label: 'Sign',
                    isLoading: _signing,
                    isDisabled: !_reviewedToEnd,
                    onTap: (_signing || !_reviewedToEnd) ? null : _sign,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _specDriftBanner(SignedExtensions ext) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: QuantusBanner(
        tone: BannerTone.ember,
        message:
            'Built for a different runtime. This payload targets spec ${ext.specVersion} / tx version '
            '${ext.transactionVersion}, but this wallet decodes spec ${AppConstants.bundledSpecVersion} / tx version '
            '${AppConstants.bundledTransactionVersion}. Across runtime versions the same index can mean a different '
            'call, so the parameters below may be mislabelled. Update the cold wallet before signing anything you '
            'cannot verify another way.',
      ),
    );
  }

  Widget _hero(BuildContext context, ParsedPayload parsed) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final summary = parsed.call.summary;

    return Center(
      child: Column(
        children: [
          Text('You are signing', style: text.caption.copyWith(color: colors.textMuted)),
          const SizedBox(height: 8),
          if (summary != null && summary.assetId == null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: NumberFormattingService().formatAmount(summary.amount),
                    style: text.amountHero.copyWith(color: colors.textContent),
                  ),
                  TextSpan(
                    text: ' ${AppConstants.tokenSymbol}',
                    style: text.amountInline.copyWith(color: colors.textMuted),
                  ),
                ],
              ),
            )
          else if (summary != null)
            Text(
              '${summary.amount} of asset #${summary.assetId}',
              style: text.titleScreen.copyWith(color: colors.textContent),
              textAlign: TextAlign.center,
            )
          else
            Text(
              parsed.call.humanCall,
              style: text.titleScreen.copyWith(color: colors.textContent),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 6),
          Text(
            parsed.call.displayTitle,
            style: text.caption.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _rawPayloadSection(BuildContext context, ParsedPayload parsed) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showRawPayload = !_showRawPayload),
          child: Row(
            children: [
              Text('RAW PAYLOAD (${parsed.raw.length} BYTES)', style: _sectionLabel(text, colors)),
              const SizedBox(width: 6),
              Icon(_showRawPayload ? Icons.expand_less : Icons.expand_more, size: 18, color: colors.textMuted),
            ],
          ),
        ),
        if (_showRawPayload) ...[
          const SizedBox(height: 8),
          Text('0x${hex.encode(parsed.raw)}', style: text.dataAddress.copyWith(color: colors.textMuted)),
        ],
      ],
    );
  }

  /// Pauses the animation and opens the tuning sheet; resumes when it closes.
  Future<void> _pauseAndTune() async {
    setState(() => _qrPaused = true);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.bgSurface,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('QR display options', style: text.titleScreen.copyWith(color: colors.textContent)),
            const SizedBox(height: 16),
            const QrTuningControls(),
          ],
        ),
      ),
    );
    if (mounted) setState(() => _qrPaused = false);
  }

  Widget _signatureView(BuildContext context, Uint8List signed) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
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
              style: text.body.copyWith(color: colors.textMuted),
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
                  style: text.caption.copyWith(color: colors.textMuted),
                ),
                if (parts.length > 1) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _pauseAndTune,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: colors.bgSurface2, shape: BoxShape.circle),
                      child: Icon(Icons.pause_rounded, size: 20, color: colors.textContent),
                    ),
                  ),
                ],
              ],
            ),
            if (parts.length > 1) ...[
              const SizedBox(height: 16),
              Text(
                'Animated QR — keep both devices steady until the hot wallet finishes scanning.',
                style: text.caption.copyWith(color: colors.textMuted),
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

TextStyle _sectionLabel(AppTextThemeV3 text, AppColorsV3 colors) {
  return text.labelMonogram.copyWith(fontSize: 10, letterSpacing: 1, color: colors.textMuted);
}
