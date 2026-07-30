import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/animated_ur_qr.dart';
import 'package:quantus_cold_wallet/components/call_detail_view.dart';
import 'package:quantus_cold_wallet/components/detail_row.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

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
  List<String>? _signatureUr;
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
      final parts = encodeUr(data: signed);
      setState(() {
        _signing = false;
        _signatureUr = parts;
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
    if (_signatureUr != null) return _signatureView(context, _signatureUr!);
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
            if (!parsed.specMatchesBundled) _specDriftBanner(context, ext),
            _hero(context, parsed),
            const SizedBox(height: 24),

            if (signerAddress != null) DetailRow(label: 'Signing as', value: signerAddress, monospace: true),
            signerCheckphrase.maybeWhen(
              data: (phrase) => phrase.isEmpty
                  ? const SizedBox.shrink()
                  : DetailRow(label: 'Signing as checkphrase', value: phrase, valueColor: colors.checksum),
              orElse: () => const SizedBox.shrink(),
            ),

            const SizedBox(height: 8),
            Divider(color: colors.borderButton),
            const SizedBox(height: 8),
            Text('CALL', style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
            const SizedBox(height: 8),
            CallDetailView(call: parsed.call),

            const SizedBox(height: 16),
            Divider(color: colors.borderButton),
            const SizedBox(height: 8),
            Text('SIGNED EXTENSIONS', style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
            DetailRow(label: 'Network', value: parsed.network),
            DetailRow(label: 'Runtime', value: 'spec ${ext.specVersion}, tx version ${ext.transactionVersion}'),
            DetailRow(label: 'Nonce', value: '${ext.nonce}'),
            DetailRow(label: 'Era', value: '${ext.era}'),
            DetailRow(label: 'Tip', value: '${NumberFormattingService().formatAmount(ext.tip)} ${AppConstants.tokenSymbol}'),
            DetailRow(label: 'Genesis hash', value: '0x${hex.encode(ext.genesisHash)}', monospace: true),
            DetailRow(label: 'Block hash', value: '0x${hex.encode(ext.blockHash)}', monospace: true),
            DetailRow(
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
                style: text.detail?.copyWith(color: colors.error),
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
                  style: text.detail?.copyWith(color: colors.textMuted),
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

  Widget _hero(BuildContext context, ParsedPayload parsed) {
    final colors = context.colors;
    final text = context.themeText;
    final summary = parsed.call.summary;

    return Center(
      child: Column(
        children: [
          Text('You are signing', style: text.smallParagraph?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 8),
          if (summary != null && summary.assetId == null)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: NumberFormattingService().formatAmount(summary.amount),
                    style: text.transactionDetailAmountPrimary?.copyWith(color: colors.textPrimary),
                  ),
                  TextSpan(
                    text: ' ${AppConstants.tokenSymbol}',
                    style: text.transactionDetailAmountSymbol?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            )
          else if (summary != null)
            Text(
              '${summary.amount} of asset #${summary.assetId}',
              style: text.mediumTitle?.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            )
          else
            Text(
              parsed.call.humanCall,
              style: text.mediumTitle?.copyWith(color: colors.textPrimary),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 6),
          Text(
            parsed.call.displayTitle,
            style: text.detail?.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _rawPayloadSection(BuildContext context, ParsedPayload parsed) {
    final colors = context.colors;
    final text = context.themeText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => setState(() => _showRawPayload = !_showRawPayload),
          child: Row(
            children: [
              Text(
                'RAW PAYLOAD (${parsed.raw.length} BYTES)',
                style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel),
              ),
              const SizedBox(width: 6),
              Icon(_showRawPayload ? Icons.expand_less : Icons.expand_more, size: 18, color: colors.textLabel),
            ],
          ),
        ),
        if (_showRawPayload) ...[
          const SizedBox(height: 8),
          Text(
            '0x${hex.encode(parsed.raw)}',
            style: text.detail?.copyWith(color: colors.textMuted, fontFamily: AppTextTheme.fontFamilySecondary),
          ),
        ],
      ],
    );
  }

  Widget _signatureView(BuildContext context, List<String> parts) {
    final colors = context.colors;
    final text = context.themeText;

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
            Center(child: AnimatedUrQr(parts: parts)),
            const SizedBox(height: 16),
            if (parts.length > 1)
              Text(
                'Animated QR — keep both devices steady until the hot wallet finishes scanning.',
                style: text.detail?.copyWith(color: colors.textMuted),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Done', onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ),
    );
  }
}
