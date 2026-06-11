import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/animated_ur_qr.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class SignTransactionScreen extends ConsumerStatefulWidget {
  final Uint8List payload;
  const SignTransactionScreen({super.key, required this.payload});

  @override
  ConsumerState<SignTransactionScreen> createState() => _SignTransactionScreenState();
}

class _SignTransactionScreenState extends ConsumerState<SignTransactionScreen> {
  TransactionInfo? _txInfo;
  bool _parseFailed = false;
  String? _toCheckphrase;
  List<String>? _signatureUr;
  bool _signing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final info = QuantusPayloadParser.parsePayload(widget.payload);
    if (info == null) {
      _parseFailed = true;
      return;
    }
    _txInfo = info;
    _loadCheckphrase(info.toAddress);
  }

  Future<void> _loadCheckphrase(String address) async {
    final phrase = await HumanReadableChecksumService().getHumanReadableName(address);
    if (!mounted) return;
    setState(() => _toCheckphrase = phrase);
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

  String _formatAmount(BigInt planck) {
    final divisor = BigInt.from(10).pow(AppConstants.decimals);
    final whole = planck ~/ divisor;
    final frac = (planck % divisor).toString().padLeft(AppConstants.decimals, '0').substring(0, 4);
    return '$whole.$frac';
  }

  @override
  Widget build(BuildContext context) {
    if (_parseFailed) return _errorView(context);
    if (_signatureUr != null) return _signatureView(context, _signatureUr!);
    return _reviewView(context, _txInfo!);
  }

  Widget _errorView(BuildContext context) {
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
            'This QR code is not a transaction this wallet can sign. Nothing was signed.',
            style: text.smallParagraph?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: 'Back to home', onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
      ),
    );
  }

  Widget _reviewView(BuildContext context, TransactionInfo info) {
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Review & Sign'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Center(
              child: Column(
                children: [
                  Text('You are signing', style: text.smallParagraph?.copyWith(color: colors.textSecondary)),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _formatAmount(info.amount),
                          style: text.transactionDetailAmountPrimary?.copyWith(color: colors.textPrimary),
                        ),
                        TextSpan(
                          text: ' ${AppConstants.tokenSymbol}',
                          style: text.transactionDetailAmountSymbol?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _detailRow(context, 'To', info.toAddress, monospace: true),
            if (_toCheckphrase != null && _toCheckphrase!.isNotEmpty)
              _detailRow(context, 'Checkphrase', _toCheckphrase!, valueColor: colors.checksum),
            _detailRow(context, 'Reversible', info.isReversible ? 'Yes' : 'No'),
            if (info.isReversible && info.reversibleTimeframe != null)
              _detailRow(context, 'Reversible window', '${info.reversibleTimeframe} blocks'),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: text.detail?.copyWith(color: colors.error),
                textAlign: TextAlign.center,
              ),
            ],
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

  Widget _detailRow(BuildContext context, String label, String value, {bool monospace = false, Color? valueColor}) {
    final colors = context.colors;
    final text = context.themeText;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
          const SizedBox(height: 6),
          Text(
            value,
            style: monospace
                ? text.transactionDetailRowValue?.copyWith(color: valueColor ?? colors.textPrimary)
                : text.smallParagraph?.copyWith(color: valueColor ?? colors.textPrimary),
          ),
        ],
      ),
    );
  }
}
