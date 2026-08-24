import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/pending_transaction_polling_service.dart';
import 'package:resonance_network_wallet/services/pos_service.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/shared/utils/url_utils.dart';
import 'package:resonance_network_wallet/services/tx_watch_service.dart';
import 'package:resonance_network_wallet/v2/components/explorer_link.dart';
import 'package:resonance_network_wallet/v2/screens/pos/pos_amount_screen.dart';

class PosQrScreen extends ConsumerStatefulWidget {
  final BigInt amountToken;
  const PosQrScreen({super.key, required this.amountToken});

  @override
  ConsumerState<PosQrScreen> createState() => _PosQrScreenState();
}

class _PosQrScreenState extends ConsumerState<PosQrScreen> {
  PosPaymentRequest? _request;

  final _txWatch = TxWatchService();
  Timer? _startTimer;
  Timer? _timeoutTimer;
  TxWatchTransfer? _paidTransfer;
  DateTime? _paidAt;
  String? _senderCheckphrase;
  bool _watching = false;
  String? _watchError;
  bool get _isPaid => _paidTransfer != null;

  @override
  void initState() {
    super.initState();
    _startTimer = Timer(const Duration(milliseconds: 500), _startWatching);
  }

  void _startWatching() {
    final l10n = ref.read(l10nProvider);
    final active = ref.read(activeAccountProvider).value;
    if (active == null) return;

    if (widget.amountToken <= BigInt.zero) {
      quantusPrint('[PosQr] ERROR: invalid token amount ${widget.amountToken}');
      if (mounted) setState(() => _watchError = l10n.posQrInvalidAmount);
      return;
    }

    setState(() {
      _watching = true;
      _watchError = null;
    });

    quantusPrint('[PosQr] watching address=${active.account.accountId} expected=${widget.amountToken} token units');
    _txWatch.watch(
      address: active.account.accountId,
      onTransfer: (tx) {
        quantusPrint('[PosQr] onTransfer from=${tx.from} amount=${tx.amount} hash=${tx.txHash}');
        if (_isPaid) return;
        final received = BigInt.tryParse(tx.amount);
        if (received != widget.amountToken) {
          quantusPrint('[PosQr] amount mismatch (received=$received expected=${widget.amountToken}), ignoring');
          return;
        }

        _timeoutTimer?.cancel();
        final pendingTx = PendingTransactionEvent(
          tempId: 'pending_recv_${DateTime.now().millisecondsSinceEpoch}',
          from: tx.from,
          to: active.account.accountId,
          amount: widget.amountToken,
          timestamp: DateTime.now(),
          transactionState: TransactionState.pending,
          isReversible: false,
          fee: null,
          extrinsicHash: tx.txHash,
        );
        ref.read(pendingTransactionsProvider.notifier).add(pendingTx);
        ref.read(pendingTransactionPollingServiceProvider).startPolling(pendingTx);
        if (mounted) {
          setState(() {
            _paidTransfer = tx;
            _paidAt = DateTime.now();
          });
          _loadSenderCheckphrase(tx.from);
        }
      },
      onError: (e) {
        quantusPrint('[PosQr] watch error: $e');
        _txWatch.dispose();
        _timeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _watching = false;
            _watchError = ref.read(l10nProvider).posQrConnectionLost;
          });
        }
      },
    );

    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      _txWatch.dispose();
      if (mounted) {
        setState(() {
          _watching = false;
          _watchError = ref.read(l10nProvider).posQrTimedOut;
        });
      }
    });
  }

  Future<void> _loadSenderCheckphrase(String address) async {
    final checksumService = ref.read(humanReadableChecksumServiceProvider);
    final checkphrase = await checksumService.getHumanReadableName(address);
    if (mounted) setState(() => _senderCheckphrase = checkphrase);
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _timeoutTimer?.cancel();
    _txWatch.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    ref.read(isCurrencyFlippedProvider.notifier).toggle();
  }

  void _done() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _newCharge() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosAmountScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final appLocale = ref.watch(selectedAppLocaleProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final accountAsync = ref.watch(activeAccountProvider);
    final formattingService = ref.watch(numberFormattingServiceProvider);
    final display = ref.watch(txAmountDisplayProvider)(
      widget.amountToken,
      withSignPrefix: false,
      isSend: false,
      tokenDecimals: 4,
    );

    return ScaffoldBase(
      appBar: V2AppBar(title: _isPaid ? l10n.posQrTitlePaymentReceived : l10n.posQrTitleScanToPay),
      mainContent: accountAsync.when(
        loading: () => const Center(child: Loader()),
        error: (e, _) => Center(
          child: Text(l10n.posQrError('$e'), style: text.caption.copyWith(color: colors.semanticEmber)),
        ),
        data: (active) {
          if (active == null) {
            return Center(
              child: Text(l10n.posQrNoActiveAccount, style: text.body.copyWith(color: colors.textMuted)),
            );
          }
          _request ??= PosService(
            formattingService: formattingService,
          ).createPaymentRequest(accountId: active.account.accountId, amountToken: widget.amountToken);
          if (_isPaid) {
            return _buildPaidContent(l10n, appLocale.numberFormatLocale, colors, text, display.primaryAmount);
          }
          return _buildQrContent(l10n, _request!, colors, text, display);
        },
      ),
      bottomContent: ScaffoldBaseBottomContent(child: _isPaid ? _buildPaidButtons(l10n) : _buildQrButton(l10n)),
    );
  }

  Widget _buildQrButton(AppLocalizations l10n) {
    return QuantusButton.simple(label: l10n.posQrNewCharge, onTap: _newCharge, variant: ButtonVariant.primary);
  }

  Widget _buildPaidButtons(AppLocalizations l10n) {
    final padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 20);

    return Row(
      spacing: 16,
      children: [
        Expanded(
          child: QuantusButton.simple(
            padding: padding,
            label: l10n.posQrDone,
            onTap: _done,
            variant: ButtonVariant.secondary,
          ),
        ),
        Expanded(
          child: QuantusButton.simple(
            padding: padding,
            label: l10n.posQrNewCharge,
            onTap: _newCharge,
            variant: ButtonVariant.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaidContent(
    AppLocalizations l10n,
    String localeName,
    AppColorsV3 colors,
    AppTextThemeV3 text,
    String amountDisplay,
  ) {
    final transfer = _paidTransfer!;
    final formattedAddress = AddressFormattingService.formatAddress(transfer.from.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        _buildSuccessCircle(colors),
        const SizedBox(height: 32),
        Text(
          l10n.posQrAmountReceived(amountDisplay),
          style: text.titleSuccess.copyWith(color: colors.textContent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        if (_paidAt != null)
          Text(
            _formatPaidAt(_paidAt!, localeName, l10n),
            style: text.body.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 32),
        _buildFromSection(l10n, colors, text, formattedAddress),
        const Spacer(),
        ExplorerLink(
          url: _paidTransfer?.txHash == null ? null : explorerImmediateTransactionUrl(_paidTransfer!.txHash),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuccessCircle(AppColorsV3 colors) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.semanticSage, width: 2),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.check_rounded, color: colors.semanticSage, size: 32),
    );
  }

  Widget _buildFromSection(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text, String formattedAddress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n.posQrFrom,
          style: text.bodyEmphasis.copyWith(color: colors.textContent),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          _senderCheckphrase ?? '…',
          style: text.body.copyWith(color: colors.semanticLilac),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          formattedAddress.toLowerCase(),
          style: text.dataAddressLarge.copyWith(color: colors.textContent),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildQrContent(
    AppLocalizations l10n,
    PosPaymentRequest request,
    AppColorsV3 colors,
    AppTextThemeV3 text,
    CurrencyDisplayState display,
  ) {
    return Column(
      children: [
        _buildAmountSection(colors, text, display),
        const SizedBox(height: 16),
        QuantusQr(accountId: request.paymentUrl),
        const Spacer(),
        if (!_watching && _watchError != null) _buildErrorSection(l10n, colors, text),
        if (_watching) _buildWaitingPill(l10n, colors, text),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAmountSection(AppColorsV3 colors, AppTextThemeV3 text, CurrencyDisplayState display) {
    return Column(
      children: [
        Text(display.primaryAmount, style: text.displayCharge.copyWith(color: colors.textContent)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('≈ ${display.secondaryAmount}', style: text.body.copyWith(color: colors.textMuted)),
            const SizedBox(width: 8),
            QuantusIconButton.circular(
              icon: Icons.swap_vert,
              onTap: _toggleFlip,
              isActive: display.isFlipped,
              size: IconButtonSize.small,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWaitingPill(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 9),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        border: Border.all(color: colors.borderHairline),
        borderRadius: context.radiusV3.pillBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Loader(size: 14, color: colors.textMuted),
          const SizedBox(width: 9),
          Text(l10n.posQrWaitingForPayment, style: text.caption.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildErrorSection(AppLocalizations l10n, AppColorsV3 colors, AppTextThemeV3 text) {
    return Column(
      children: [
        Text(l10n.posQrNetworkError, style: text.caption.copyWith(color: colors.semanticEmber)),
        const SizedBox(height: 8),
        QuantusButton.simple(
          label: l10n.posQrTryAgain,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          onTap: _startWatching,
          variant: ButtonVariant.secondary,
        ),
      ],
    );
  }

  String _formatPaidAt(DateTime dt, String localeName, AppLocalizations l10n) {
    final dateTime = DatetimeFormattingService.formatPaidAt(dt, localeName);
    return l10n.posQrPaidAt(dateTime);
  }
}
