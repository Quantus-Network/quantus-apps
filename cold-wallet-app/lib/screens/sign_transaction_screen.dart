import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide CallFieldView;
import 'package:quantus_cold_wallet/app_version.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/call_detail_view.dart';
import 'package:quantus_cold_wallet/components/signature_qr_view.dart';
import 'package:quantus_cold_wallet/components/signing_refusal_view.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

/// Reviews a scanned signing payload and, on approval, produces the signature QR.
///
/// The two questions that decide whether a signature is safe — how much, and to
/// whom — are answered above the fold, in the largest type on the screen. Every
/// call parameter the summary does not already show is listed under it; only the
/// signed extensions and the raw bytes, which no signer verifies by eye, live
/// behind the Advanced disclosure.
class SignTransactionScreen extends ConsumerStatefulWidget {
  final SigningRequest request;
  const SignTransactionScreen({super.key, required this.request});

  @override
  ConsumerState<SignTransactionScreen> createState() => _SignTransactionScreenState();
}

class _SignTransactionScreenState extends ConsumerState<SignTransactionScreen> {
  ParsedPayload? _parsed;
  FormatException? _parseError;
  Uint8List? _signed;
  bool _signing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    try {
      _parsed = QuantusPayloadParser.parsePayload(widget.request.payload, policy: const FullCallPolicy());
    } on FormatException catch (e) {
      debugPrint('Rejected signing payload: $e');
      _parseError = e;
    }
  }

  void _sign() {
    final keypair = keypairFor(ref, widget.request.signer);
    if (keypair == null) {
      setState(() => _error = 'Wallet is locked — unlock and try again. Nothing was signed.');
      return;
    }
    setState(() {
      _signing = true;
      _error = null;
    });

    try {
      final parsed = _parsed;
      if (parsed == null) {
        setState(() {
          _signing = false;
          _error = 'Cannot sign an undecoded payload.';
        });
        return;
      }
      // Returns signature ++ publicKey; the hot wallet reads the scheme off its
      // length and rebuilds the extrinsic via submitExtrinsicWithExternalSignature.
      final signed = signMessageWithPubkey(
        keypair: keypair,
        message: QuantusSigningPayload.signablePayload(widget.request.payload),
        specVersion: parsed.extensions.specVersion,
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
    final parseError = _parseError;
    if (parseError != null) return _parseErrorView(context, parseError);
    if (!ref.watch(addressesProvider).containsKey(widget.request.signer)) {
      return _errorView(
        context,
        title: 'Account not in this wallet',
        message: 'The requested signer account does not exist in this cold wallet.',
        detail: AddressWithCheckphrase(label: 'Requested signer', address: widget.request.signer),
      );
    }
    if (_signed != null) {
      return SignatureQrView(
        signed: _signed!,
        instruction: 'Scan this with your hot wallet to broadcast the transaction.',
      );
    }
    return _reviewView(context, _parsed!);
  }

  Widget _parseErrorView(BuildContext context, FormatException error) {
    final text = context.themeTextV3;
    final muted = text.body.copyWith(color: context.colorsV3.textMuted);
    return switch (error) {
      UnknownCallException(:final pallet, :final call) => _errorView(
        context,
        title: 'Unsupported transaction',
        message: 'Pallet $pallet call $call not found. $updateAppHint',
        detail: Text(currentAppVersion, style: muted, textAlign: TextAlign.center),
      ),
      CallNestingLimitException() => _errorView(
        context,
        title: 'Transaction too complex',
        message: 'This transaction nests calls deeper than this wallet can show in full.',
        detail: Text(error.message, style: muted, textAlign: TextAlign.center),
      ),
      _ => _errorView(
        context,
        title: 'Could not read transaction',
        message: 'This QR code is not a transaction this wallet can read in full.',
        detail: Text(error.message, style: muted, textAlign: TextAlign.center),
      ),
    };
  }

  Widget _errorView(BuildContext context, {required String title, required String message, required Widget detail}) =>
      SigningRefusalView(appBarTitle: 'Sign Transaction', title: title, message: message, detail: detail);

  Widget _reviewView(BuildContext context, ParsedPayload parsed) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

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
            Text(parsed.call.actionTitle, style: text.titleScreen.copyWith(color: colors.accentFlare)),
            ..._callBody(parsed.call),
            const SizedBox(height: 20),
            _advancedSection(context, parsed),
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
        child: Row(
          children: [
            Expanded(
              child: QuantusButton.simple(
                label: 'Cancel',
                variant: ButtonVariant.staged,
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
  /// neither of those already showed. Wrappers lead with their nested calls.
  ///
  /// The signer's row claims `From` only when the summary shows a plain send
  /// and the call names no other account the funds could leave instead — a
  /// `force_transfer` moves its Source's funds, not the signer's. Anything
  /// else says no more than `Signed by`.
  List<Widget> _callBody(DecodedCall call) {
    final signerAddress = widget.request.signer;
    final transfer = heroSummary(call);
    final fromSigner =
        transfer?.recipient != null &&
        !call.fields.any(
          (f) => f is ValueField && f.kind == ValueKind.address && !identical(f, transfer!.recipientField),
        );
    final signer = AddressWithCheckphrase(label: fromSigner ? 'From' : 'Signed by', address: signerAddress);

    if (!call.isWrapper) return [...callSummaryBody(call), signer];

    return [
      for (final field in call.fields.whereType<NestedCallField>()) CallFieldView(field: field),
      signer,
      for (final field in call.fields.where((field) => field is! NestedCallField)) CallFieldView(field: field),
    ];
  }

  /// Everything a signer never verifies by eye: the signed extensions and the
  /// bytes themselves, listed plainly for the rare reader who wants them.
  Widget _advancedSection(BuildContext context, ParsedPayload parsed) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showSheet(
        title: 'Advanced',
        child: Text(_advancedLines(parsed).join('\n'), style: text.dataAddress.copyWith(color: colors.textMuted)),
      ),
      child: Row(
        children: [
          Text('ADVANCED', style: text.labelData.copyWith(color: colors.textMuted)),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
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
      'Network: ${parsed.network ?? 'Unknown'}',
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
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.semanticEmber.useOpacity(0.12),
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.semanticEmber),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.semanticEmber, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Built for a different runtime', style: text.bodyEmphasis.copyWith(color: colors.semanticEmber)),
                const SizedBox(height: 4),
                Text(
                  'This payload targets spec ${ext.specVersion} / tx version ${ext.transactionVersion}, but this '
                  'wallet decodes spec ${AppConstants.bundledSpecVersion} / tx version '
                  '${AppConstants.bundledTransactionVersion}. Across runtime versions the same index can mean a '
                  'different call, so the parameters below may be mislabelled. Update the cold wallet before signing '
                  'anything you cannot verify another way.',
                  style: text.caption.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showSheet({required String title, required Widget child}) {
    return BottomSheetContainer.show<void>(
      context,
      builder: (ctx) => BottomSheetContainer(title: title, child: child),
    );
  }
}
