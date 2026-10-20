import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_desktop_wallet/providers/account_providers.dart';
import 'package:quantus_desktop_wallet/providers/balance_providers.dart';
import 'package:quantus_desktop_wallet/providers/controllers/cold_sign_flow.dart';
import 'package:quantus_desktop_wallet/providers/controllers/transaction_submission.dart';
import 'package:quantus_desktop_wallet/providers/l10n_provider.dart';
import 'package:quantus_desktop_wallet/providers/settings_providers.dart';
import 'package:quantus_desktop_wallet/router.dart';
import 'package:quantus_desktop_wallet/ui/components/camera_scanner_panel.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_card.dart';
import 'package:quantus_desktop_wallet/ui/components/scan_strings.dart';
import 'package:quantus_desktop_wallet/ui/screens/sign/sign_flow_dialog.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_page.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_sdk/quantus_sdk_riverpod.dart';

enum _AmountUnit { token, fiat }

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  ConsumerState<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends ConsumerState<SendScreen> {
  static const _feeDebounce = Duration(milliseconds: 500);

  final TextEditingController _recipient = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  _AmountUnit _unit = _AmountUnit.token;
  bool _sendAll = false;
  AsyncValue<BigInt>? _fee;
  Timer? _feeTimer;
  int _feeGeneration = 0;

  @override
  void initState() {
    super.initState();
    _recipient.addListener(_onInput);
    _amount.addListener(_onInput);
  }

  @override
  void dispose() {
    _feeTimer?.cancel();
    _recipient.dispose();
    _amount.dispose();
    super.dispose();
  }

  String get _recipientText => _recipient.text.trim();

  bool get _recipientValid => _recipientText.isNotEmpty && SubstrateService().isValidSS58Address(_recipientText);

  bool get _recipientIsSelf => _recipientText == ref.read(currentAccountProvider)?.accountId;

  BigInt? get _tokenAmount {
    final text = _amount.text.trim();
    if (text.isEmpty) return null;
    if (_unit == _AmountUnit.token) return ref.read(numberFormattingServiceProvider).parseAmount(text);
    final fiat = Decimal.tryParse(text);
    final rates = ref.read(exchangeRateServiceProvider);
    if (fiat == null || !rates.hasTokenPrice) return null;
    return rates.fiatToToken(fiat, ref.read(selectedFiatCurrencyProvider), AppConstants.decimals);
  }

  void _onInput() {
    if (_sendAll && _unit == _AmountUnit.token) {
      _sendAll = false;
    }
    _feeTimer?.cancel();
    _feeTimer = Timer(_feeDebounce, _estimateFee);
    setState(() => _fee = null);
  }

  RuntimeCall _call(String recipient, BigInt amount) {
    final balances = ref.read(balancesServiceProvider);
    return _sendAll ? balances.getTransferAllCall(recipient) : balances.getBalanceTransferCall(recipient, amount);
  }

  Future<void> _estimateFee() async {
    final account = ref.read(currentAccountProvider);
    final amount = _tokenAmount;
    if (account == null || !_recipientValid || _recipientIsSelf || amount == null || amount <= BigInt.zero) return;
    final generation = ++_feeGeneration;
    setState(() => _fee = const AsyncValue.loading());
    try {
      final data = await ref.read(substrateServiceProvider).getFeeForCall(account, _call(_recipientText, amount));
      if (mounted && generation == _feeGeneration) setState(() => _fee = AsyncValue.data(data.fee));
    } catch (e, st) {
      if (mounted && generation == _feeGeneration) setState(() => _fee = AsyncValue.error(e, st));
    }
  }

  void _useMax() {
    final spendable = ref.read(spendableBalanceProvider).value;
    if (spendable == null) return;
    final fee = _fee?.value ?? BigInt.zero;
    final amount = spendable - fee;
    _sendAll = true;
    _unit = _AmountUnit.token;
    _amount.text = ref
        .read(numberFormattingServiceProvider)
        .formatExactAmount(amount > BigInt.zero ? amount : BigInt.zero);
    _sendAll = true;
    _feeTimer?.cancel();
    _feeTimer = Timer(_feeDebounce, _estimateFee);
    setState(() {});
  }

  Future<void> _scanRecipient() async {
    final l10n = ref.read(l10nProvider);
    final collector = SingleQrCollector(validator: (value) => SubstrateService().isValidSS58Address(value.trim()));
    final address = await showDialog<String>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(48),
        child: QuantusDialogFrame(
          maxWidth: 720,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CameraScannerPanel(
                collector: collector,
                onComplete: (parts) async => Navigator.pop(context, parts.first.trim()),
                strings: scanStringsFor(l10n, idleHint: l10n.onboardingScanHint),
                showFrameMap: false,
              ),
              const SizedBox(height: 16),
              QuantusButton.simple(
                label: l10n.commonCancel,
                variant: ButtonVariant.staged,
                width: 160,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
    if (address != null) _recipient.text = address;
  }

  Future<void> _review() async {
    final account = ref.read(currentAccountProvider);
    final amount = _tokenAmount;
    final fee = _fee?.value;
    if (account == null || amount == null || fee == null) return;
    final l10n = ref.read(l10nProvider);
    final recipient = _recipientText;
    final formatter = ref.read(numberFormattingServiceProvider);
    final flow = ColdSignFlow(
      read: ref.read,
      account: account,
      buildCall: () => _call(recipient, amount),
      key: _sendAll
          ? ColdSignRequestKey.forExtrinsic(accountId: account.accountId, identity: 'transfer_all|$recipient')
          : ColdSignRequestKey.fromSendParams(
              accountId: account.accountId,
              recipientAddress: recipient,
              amount: amount,
            ),
      bytesPerFrame: ref.read(qrDisplaySettingsProvider).bytesPerFrame,
      onSubmitted: (hash, blockNumber) => trackSubmittedTransfer(
        ref,
        account: account,
        recipient: recipient,
        amount: amount,
        fee: fee,
        extrinsicHash: hash,
        blockNumber: blockNumber,
      ),
    );
    final hash = await showSignFlowDialog(
      context,
      flow: flow,
      details: ColdSignDetails(
        amount: l10n.commonQtcAmount(formatter.formatExactAmount(amount)),
        recipient: recipient,
        recipientCheckphrase: ref.read(checksumNameProvider(recipient)).value,
      ),
    );
    flow.dispose();
    if (hash == null || !mounted) return;
    _recipient.clear();
    _amount.clear();
    _sendAll = false;
    context.go(AppRoutes.account);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final formatter = ref.watch(numberFormattingServiceProvider);
    final rates = ref.watch(exchangeRateServiceProvider);
    final fiat = ref.watch(selectedFiatCurrencyProvider);
    final spendable = ref.watch(spendableBalanceProvider).value;
    final amount = _tokenAmount;
    final fee = _fee?.value;
    final recipientError = _recipientText.isEmpty
        ? null
        : !_recipientValid
        ? l10n.sendRecipientInvalid
        : _recipientIsSelf
        ? l10n.sendRecipientSelf
        : null;
    final checkphrase = recipientError == null && _recipientValid
        ? ref.watch(checksumNameProvider(_recipientText)).value
        : null;
    final insufficient = amount != null && fee != null && spendable != null && !_sendAll && amount + fee > spendable;
    final ready =
        recipientError == null &&
        _recipientValid &&
        amount != null &&
        amount > BigInt.zero &&
        fee != null &&
        !insufficient;
    final conversion = amount == null
        ? null
        : _unit == _AmountUnit.token
        ? (rates.hasTokenPrice
              ? fiat.format(rates.tokenToFiat(amount, fiat, AppConstants.decimals).toStringAsFixed(fiat.decimals))
              : null)
        : l10n.commonQtcAmount(formatter.formatBalance(amount));

    return DesktopPage(
      title: l10n.sendTitle,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: DesktopCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.sendRecipientLabel, style: text.labelMonogram.copyWith(color: colors.textMuted)),
                const SizedBox(height: 8),
                QuantusTextField(
                  controller: _recipient,
                  hint: l10n.sendRecipientHint,
                  showClearButton: true,
                  error: recipientError,
                  trailing: QuantusIconButton.ghost(
                    icon: Icons.qr_code_scanner_rounded,
                    size: IconButtonSize.small,
                    onTap: _scanRecipient,
                  ),
                ),
                if (checkphrase != null && checkphrase.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(checkphrase, style: text.body.copyWith(color: colors.semanticLilac)),
                ],
                const SizedBox(height: 24),
                Text(l10n.sendAmountLabel, style: text.labelMonogram.copyWith(color: colors.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: QuantusTextField(
                        controller: _amount,
                        hint: l10n.sendAmountHint,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [DecimalInputFilter(localeConfig: LocaleNumberConfig.dotDecimal)],
                        trailing: QuantusButton.simple(
                          label: l10n.sendMax,
                          variant: ButtonVariant.ghost,
                          width: null,
                          onTap: _useMax,
                        ),
                        trailingWidth: 72,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 160,
                      child: SegmentedControls<_AmountUnit>(
                        items: [
                          SegmentedControlItem(value: _AmountUnit.token, label: l10n.sendUnitQtc),
                          SegmentedControlItem(value: _AmountUnit.fiat, label: fiat.code),
                        ],
                        selectedValue: _unit,
                        onChanged: rates.hasTokenPrice
                            ? (unit) => setState(() {
                                _unit = unit;
                                _sendAll = false;
                              })
                            : (_) => context.showInfoToaster(message: l10n.sendNoPrice),
                      ),
                    ),
                  ],
                ),
                if (conversion != null) ...[
                  const SizedBox(height: 6),
                  Text(l10n.commonApproximately(conversion), style: text.caption.copyWith(color: colors.textMuted)),
                ],
                const SizedBox(height: 24),
                QuantusDataRow(
                  label: l10n.sendFee,
                  value: switch (_fee) {
                    null => '—',
                    AsyncLoading() => '…',
                    AsyncError() => l10n.sendFeeError,
                    AsyncData(:final value) => l10n.commonQtcAmount(formatter.formatExactAmount(value)),
                  },
                ),
                QuantusDataRow(
                  label: l10n.sendTotal,
                  value: amount != null && fee != null
                      ? l10n.commonQtcAmount(formatter.formatExactAmount(amount + fee))
                      : '—',
                ),
                if (insufficient) ...[
                  const SizedBox(height: 12),
                  QuantusBanner(tone: BannerTone.ember, message: l10n.sendInsufficient),
                ],
                const SizedBox(height: 24),
                QuantusButton.simple(label: l10n.sendReview, isDisabled: !ready, onTap: _review),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
