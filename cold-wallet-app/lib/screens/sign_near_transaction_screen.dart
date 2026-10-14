import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/review_card.dart';
import 'package:quantus_cold_wallet/components/signature_qr_view.dart';
import 'package:quantus_cold_wallet/components/signing_refusal_view.dart';
import 'package:quantus_cold_wallet/components/step_header.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/rejected_screen.dart';
import 'package:quantus_cold_wallet/services/near_display.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// Reviews a NEAR transaction a hot wallet asked this device to sign, and on
/// approval produces the `signature ‖ public key` QR.
///
/// A NEAR transaction names the key that must sign it rather than a Quantus
/// address, so the screen first finds which account here holds that key. The
/// receiver and every action are listed in full: a NEAR transaction can carry
/// several, and the dangerous ones — key and account changes, code
/// deployment — are marked so they are not mistaken for a plain send.
class SignNearTransactionScreen extends ConsumerStatefulWidget {
  final NearSigningRequest request;

  /// [request]'s transaction, decoded by whoever scanned it; undecodable
  /// bytes never reach this screen.
  final NearTransaction transaction;

  const SignNearTransactionScreen({super.key, required this.request, required this.transaction});

  @override
  ConsumerState<SignNearTransactionScreen> createState() => _SignNearTransactionScreenState();
}

class _SignNearTransactionScreenState extends ConsumerState<SignNearTransactionScreen> {
  bool _signing = false;
  String? _error;

  NearTransaction get tx => widget.transaction;

  bool get _soleTransfer => tx.actions.length == 1 && tx.actions.single.kind == NearActionKind.transfer;

  String _near(BigInt? yocto) => '${NearDisplay.formatNear(yocto ?? BigInt.zero)} NEAR';

  void _sign(String owner) {
    final keypair = keypairFor(ref, owner);
    if (keypair == null) {
      setState(() => _error = 'Wallet is locked — unlock and try again. Nothing was signed.');
      return;
    }
    setState(() {
      _signing = true;
      _error = null;
    });
    try {
      // Pure ML-DSA-65 over SHA-256 of the transaction, no Quantus context:
      // this is what the NEAR runtime verifies. Returns signature ++ public key.
      final signed = keypair.signNear(widget.request.transaction);
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
    final muted = context.themeTextV3.body.copyWith(color: context.colorsV3.textMuted);
    if (!tx.signsWithMlDsa65) {
      return _errorView(
        context,
        title: 'Not a Quantus key',
        message:
            'This transaction names a key of type ${_keyKind(tx.publicKey)}. This wallet holds only ML-DSA-65 '
            'keys, so it cannot sign it.',
        detail: Text(tx.publicKey, style: muted, textAlign: TextAlign.center),
      );
    }
    if (ref.watch(walletControllerProvider).status != WalletStatus.unlocked) {
      return _errorView(
        context,
        title: 'Wallet is locked',
        message: 'Unlock the wallet and scan the request again.',
        detail: Text(tx.publicKey, style: muted, textAlign: TextAlign.center),
      );
    }
    final owner = ref.watch(nearKeyOwnerProvider(hex.encode(tx.publicKeyBytes)));
    if (owner == null) {
      return _errorView(
        context,
        title: 'Key not in this wallet',
        message: 'No ML-DSA-65 account in this cold wallet holds the key this transaction names.',
        detail: DetailSummaryRow.stacked(label: 'Requested key', value: tx.publicKey, monospace: true),
      );
    }
    return _reviewView(context, owner);
  }

  static String _keyKind(String publicKey) {
    final colon = publicKey.indexOf(':');
    return colon < 0 ? 'different' : publicKey.substring(0, colon);
  }

  Widget _errorView(BuildContext context, {required String title, required String message, required Widget detail}) =>
      SigningRefusalView(appBarTitle: 'Sign', title: title, message: message, detail: detail);

  Widget _reviewView(BuildContext context, String owner) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final accountChange = NearDisplay.accountChangeTitle(tx);
    final dangerous = accountChange != null;
    final mismatch = NearDisplay.networkMismatch(tx, widget.request.network);

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
            _networkChip(context),
            if (mismatch != null) ...[
              const SizedBox(height: 16),
              QuantusBanner(tone: BannerTone.ember, label: 'Check the network', message: mismatch),
            ],
            if (accountChange != null) ...[
              const SizedBox(height: 16),
              QuantusBanner(
                tone: BannerTone.ember,
                label: accountChange,
                message:
                    'An account, its keys or its code are being changed, not just funds moved. Only sign this if '
                    'you asked for exactly these actions.',
              ),
            ],
            const SizedBox(height: 24),
            ReviewCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    NearDisplay.headline(tx),
                    style: text.titleScreen.copyWith(color: dangerous ? colors.semanticEmber : colors.accentFlare),
                  ),
                  if (_soleTransfer) ...[
                    _amountHero(context, tx.actions.single.amount ?? BigInt.zero),
                    DetailSummaryRow.stacked(label: 'To', value: tx.receiverId, monospace: true),
                    DetailSummaryRow.stacked(label: 'From', value: tx.signerId, monospace: true),
                  ] else ...[
                    DetailSummaryRow.stacked(label: 'Receiver', value: tx.receiverId, monospace: true),
                    DetailSummaryRow.stacked(label: 'Signed by', value: tx.signerId, monospace: true),
                    for (final (i, action) in tx.actions.indexed) ..._actionBody(context, action, i),
                  ],
                  AddressWithCheckphrase(label: 'Signing key held by', address: owner),
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
            _advancedSection(context),
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
              onTap: _signing ? null : () => _sign(owner),
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

  /// The network label with its provenance. It is never shown bare: a
  /// signer must not read it as something this device established.
  Widget _networkChip(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final network = widget.request.network;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgSurface2,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.textMuted.useOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'NEAR · ${network.toUpperCase()}',
                style: text.labelMonogram.copyWith(color: colors.textContent, letterSpacing: 1.2),
              ),
              const SizedBox(width: 8),
              Text('UNVERIFIED', style: text.labelMonogram.copyWith(color: colors.semanticEmber, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 6),
          Text(NearDisplay.networkDisclaimer(network), style: text.caption.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }

  Widget _amountHero(BuildContext context, BigInt yocto) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: NearDisplay.formatNear(yocto),
                style: text.amountHero.copyWith(color: colors.textContent),
              ),
              TextSpan(
                text: ' NEAR',
                style: text.amountInline.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Every parameter of one action, under a heading that names it. Nothing is
  /// summarised away: a function-call key's method list or a stake's validator
  /// key is exactly what a signer has to check.
  List<Widget> _actionBody(BuildContext context, NearAction action, int index) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final danger = NearDisplay.isDangerous(action);
    final heading = Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        '${index + 1}. ${NearDisplay.actionTitle(action)}',
        style: text.headingRow.copyWith(color: danger ? colors.semanticEmber : colors.semanticLilac),
      ),
    );

    final rows = switch (action.kind) {
      NearActionKind.transfer => [DetailSummaryRow.stacked(label: 'Amount', value: _near(action.amount))],
      NearActionKind.functionCall => [
        DetailSummaryRow.stacked(label: 'Method', value: NearDisplay.safeText(action.target ?? ''), monospace: true),
        DetailSummaryRow.stacked(label: 'Attached deposit', value: _near(action.amount)),
        DetailSummaryRow.stacked(label: 'Gas', value: NearDisplay.formatGas(action.gas ?? BigInt.zero)),
        DetailSummaryRow.stacked(
          label: 'Arguments',
          value: NearDisplay.argsText(action.args ?? Uint8List(0)),
          monospace: true,
        ),
      ],
      NearActionKind.createAccount => [
        DetailSummaryRow.stacked(label: 'New account', value: tx.receiverId, monospace: true),
      ],
      NearActionKind.deployContract => [
        DetailSummaryRow.stacked(label: 'Deploys to', value: tx.receiverId, monospace: true),
        DetailSummaryRow.stacked(label: 'Code size', value: '${action.codeLen ?? 0} bytes'),
        DetailSummaryRow.stacked(
          label: 'Code SHA-256',
          value: hex.encode(action.codeHash ?? Uint8List(0)),
          monospace: true,
          note: 'Compare with the hash of the contract you meant to deploy; the code itself cannot be shown here.',
        ),
      ],
      NearActionKind.stake => [
        DetailSummaryRow.stacked(label: 'Amount', value: _near(action.amount)),
        DetailSummaryRow.stacked(label: 'Validator key', value: action.publicKey ?? '', monospace: true),
      ],
      NearActionKind.addKey => [
        DetailSummaryRow.stacked(label: 'Key', value: action.publicKey ?? '', monospace: true),
        if (action.fullAccess)
          DetailSummaryRow.stacked(
            label: 'Access',
            value: 'Full access',
            valueColor: colors.semanticEmber,
            note: 'This key can do anything the account can, including removing your key.',
          )
        else ...[
          DetailSummaryRow.stacked(label: 'May call', value: action.target ?? '', monospace: true),
          DetailSummaryRow.stacked(
            label: 'Methods',
            value: action.methodNames.isEmpty ? 'Any method' : action.methodNames.map(NearDisplay.safeText).join(', '),
            monospace: action.methodNames.isNotEmpty,
          ),
          DetailSummaryRow.stacked(
            label: 'Gas allowance',
            value: action.amount == null ? 'Unlimited' : _near(action.amount),
          ),
        ],
      ],
      NearActionKind.deleteKey => [
        DetailSummaryRow.stacked(label: 'Key', value: action.publicKey ?? '', monospace: true),
      ],
      NearActionKind.deleteAccount => [
        DetailSummaryRow.stacked(label: 'Deletes', value: tx.receiverId, monospace: true),
        DetailSummaryRow.stacked(label: 'Balance goes to', value: action.target ?? '', monospace: true),
      ],
    };
    return [heading, ...rows];
  }

  Widget _advancedSection(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => BottomSheetContainer.show<void>(
        context,
        builder: (ctx) => BottomSheetContainer(
          title: 'Advanced',
          child: Text(_advancedLines().join('\n'), style: text.dataAddress.copyWith(color: colors.textMuted)),
        ),
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

  List<String> _advancedLines() => [
    'Network: ${widget.request.network}',
    'Nonce: ${tx.nonce}',
    'Block hash: ${tx.blockHash}',
    'Public key: ${tx.publicKey}',
    'Transaction hash: ${hex.encode(tx.hash)}',
    'Raw transaction (${widget.request.transaction.length} bytes): 0x${hex.encode(widget.request.transaction)}',
  ];
}
