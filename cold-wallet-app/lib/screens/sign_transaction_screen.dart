import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide CallFieldView;
import 'package:quantus_cold_wallet/app_version.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/call_detail_view.dart';
import 'package:quantus_cold_wallet/components/review_card.dart';
import 'package:quantus_cold_wallet/components/signature_qr_view.dart';
import 'package:quantus_cold_wallet/components/signer_row.dart';
import 'package:quantus_cold_wallet/components/signing_refusal_view.dart';
import 'package:quantus_cold_wallet/components/step_header.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/rejected_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

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
      setState(() => _signing = false);
      SignatureQrView.push(context, signed);
    } catch (e) {
      setState(() {
        _signing = false;
        _error = 'Signing failed: $e';
      });
    }
  }

  void _reject() => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RejectedScreen()));

  @override
  Widget build(BuildContext context) {
    final parseError = _parseError;
    if (parseError != null) return _parseErrorView(context, parseError);
    final account = ref.watch(addressesProvider)[widget.request.signer];
    if (account == null) {
      return _errorView(
        context,
        title: 'Account not in this wallet',
        message: 'The requested signer account does not exist in this cold wallet.',
        detail: AddressWithCheckphrase(label: 'Requested signer', address: widget.request.signer),
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
      SigningRefusalView(appBarTitle: 'Sign', title: title, message: message, detail: detail);

  Widget _reviewView(BuildContext context, ParsedPayload parsed) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Sign'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const StepHeader(
              step: 2,
              total: 3,
              title: "Check your phone's screen",
              subtitle: 'Before approving here, make sure your phone shows exactly this:',
            ),
            const SizedBox(height: 24),
            if (!parsed.specMatchesBundled) ...[_specDriftBanner(parsed.extensions), const SizedBox(height: 16)],
            ReviewCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The headline is an opinionated human summary (SEND / REVERSIBLE
                  // SEND / …) by design; the exact pallet · call chain is the Call
                  // line in the Advanced sheet. See [DecodedCall.actionTitle].
                  Text(parsed.call.actionTitle, style: text.titleScreen.copyWith(color: colors.accentFlare)),
                  ..._callBody(parsed.call),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const QuantusBanner(
              tone: BannerTone.ember,
              message:
                  "If the amount or address on your phone is different from what's shown here, reject it on this "
                  'device.',
            ),
            const SizedBox(height: 24),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuantusButton.simple(
              label: 'Approve and Sign',
              padding: coldButtonPadding,
              isLoading: _signing,
              onTap: _signing ? null : _sign,
            ),
            const SizedBox(height: 8),
            QuantusButton.simple(
              label: "It doesn't match",
              variant: ButtonVariant.underline,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: text.bodyEmphasis.copyWith(color: colors.semanticEmber),
              onTap: _reject,
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
    final signer = SignerRow(label: fromSigner ? 'From' : 'Signed by', address: signerAddress);

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
          QuantusIcon(QuantusIcons.chevronRight, size: 18, color: colors.textMuted),
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

  /// A warning only: a signer who verified the transaction another way must
  /// still be able to sign it.
  Widget _specDriftBanner(SignedExtensions ext) {
    return QuantusBanner(
      tone: BannerTone.ember,
      label: 'Built for a different runtime',
      message:
          'This payload targets spec ${ext.specVersion} / tx version ${ext.transactionVersion}, but this '
          'wallet decodes spec ${AppConstants.bundledSpecVersion} / tx version '
          '${AppConstants.bundledTransactionVersion}. Across runtime versions the same index can mean a '
          'different call, so the parameters below may be mislabelled. Update the cold wallet before signing '
          'anything you cannot verify another way.',
    );
  }

  Future<void> _showSheet({required String title, required Widget child}) {
    return BottomSheetContainer.show<void>(
      context,
      builder: (ctx) => BottomSheetContainer(title: title, child: child),
    );
  }
}
