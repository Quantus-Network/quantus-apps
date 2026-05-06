import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/currency_display_provider.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/pending_transaction_polling_service.dart';
import 'package:resonance_network_wallet/services/pos_service.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/v2/components/loader.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_icon_button.dart';
import 'package:resonance_network_wallet/v2/components/quantus_qr.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/services/tx_watch_service.dart';
import 'package:resonance_network_wallet/v2/screens/pos/pos_amount_screen.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class PosQrScreen extends ConsumerStatefulWidget {
  final String amount;
  const PosQrScreen({super.key, required this.amount});

  @override
  ConsumerState<PosQrScreen> createState() => _PosQrScreenState();
}

class _PosQrScreenState extends ConsumerState<PosQrScreen> {
  final _posService = PosService();
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
    final formattingService = ref.watch(numberFormattingServiceProvider);
    final active = ref.read(activeAccountProvider).value;
    if (active == null) return;

    final expectedPlanck = formattingService.parseAmount(widget.amount);
    if (expectedPlanck == null) {
      print('[PosQr] ERROR: failed to parse amount "${widget.amount}"');
      if (mounted) setState(() => _watchError = 'Invalid amount. Tap to retry.');
      return;
    }

    setState(() {
      _watching = true;
      _watchError = null;
    });

    print('[PosQr] watching address=${active.account.accountId} expected=$expectedPlanck planck');
    _txWatch.watch(
      address: active.account.accountId,
      onTransfer: (tx) {
        print('[PosQr] onTransfer from=${tx.from} amount=${tx.amount} hash=${tx.txHash}');
        if (_isPaid) return;
        final received = BigInt.tryParse(tx.amount);
        if (received != expectedPlanck) {
          print('[PosQr] amount mismatch (received=$received expected=$expectedPlanck), ignoring');
          return;
        }

        _timeoutTimer?.cancel();
        final pendingTx = PendingTransactionEvent(
          tempId: 'pending_recv_${DateTime.now().millisecondsSinceEpoch}',
          from: tx.from,
          to: active.account.accountId,
          amount: expectedPlanck,
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
        _txWatch.dispose();
        _timeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _watching = false;
            _watchError = 'Connection lost. Tap to retry.';
          });
        }
      },
    );

    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      _txWatch.dispose();
      if (mounted) {
        setState(() {
          _watching = false;
          _watchError = 'Timed out. Tap to retry.';
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

  void _openExplorer() {
    final txHash = _paidTransfer?.txHash;
    if (txHash == null) return;
    openUrl('${AppConstants.explorerEndpoint}/immediate-transactions/$txHash');
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final accountAsync = ref.watch(activeAccountProvider);
    final formattingService = ref.watch(numberFormattingServiceProvider);
    final planck = formattingService.parseAmount(widget.amount) ?? BigInt.zero;
    final display = ref.watch(txAmountDisplayProvider)(planck, withSignPrefix: false, isSend: false, quanDecimals: 4);

    return ScaffoldBase(
      appBar: V2AppBar(title: _isPaid ? 'Payment Received' : 'Scan to Pay'),
      mainContent: accountAsync.when(
        loading: () => const Center(child: Loader()),
        error: (e, _) => Center(
          child: Text('Error: $e', style: text.detail?.copyWith(color: colors.textError)),
        ),
        data: (active) {
          if (active == null) return const Center(child: Text('No active account'));
          _request ??= _posService.createPaymentRequest(accountId: active.account.accountId, amount: widget.amount);
          if (_isPaid) return _buildPaidContent(colors, text, display.primaryAmount);
          return _buildQrContent(_request!, colors, text, display);
        },
      ),
      bottomContent: ScaffoldBaseBottomContent(child: _isPaid ? _buildPaidButtons() : _buildQrButton()),
    );
  }

  Widget _buildQrButton() {
    return QuantusButton.simple(label: 'New Charge', onTap: _newCharge, variant: ButtonVariant.primary);
  }

  Widget _buildPaidButtons() {
    final padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 20);

    return Row(
      spacing: 16,
      children: [
        Expanded(
          child: QuantusButton.simple(padding: padding, label: 'Done', onTap: _done, variant: ButtonVariant.secondary),
        ),
        Expanded(
          child: QuantusButton.simple(
            padding: padding,
            label: 'New Charge',
            onTap: _newCharge,
            variant: ButtonVariant.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildPaidContent(AppColorsV2 colors, AppTextTheme text, String amountDisplay) {
    final transfer = _paidTransfer!;
    final formattedAddress = AddressFormattingService.formatAddress(transfer.from.trim());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        _buildSuccessCircle(colors),
        const SizedBox(height: 32),
        Text(
          '$amountDisplay received',
          style: text.smallTitle?.copyWith(color: colors.textLightGray, fontSize: 32, fontWeight: FontWeight.w400),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        if (_paidAt != null)
          Text(
            _formatPaidAt(_paidAt!),
            style: text.smallParagraph?.copyWith(color: colors.textTertiary, letterSpacing: 0.7),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 32),
        _buildFromSection(colors, text, formattedAddress),
        const Spacer(),
        _buildExplorerLink(colors, text),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSuccessCircle(AppColorsV2 colors) {
    return Container(
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.success, width: 1.8),
      ),
      child: Center(child: Icon(Icons.check, color: colors.success, size: 32)),
    );
  }

  Widget _buildFromSection(AppColorsV2 colors, AppTextTheme text, String formattedAddress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'From:',
          style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_senderCheckphrase != null)
          Text(
            _senderCheckphrase!,
            style: text.smallParagraph?.copyWith(color: colors.checksum),
            textAlign: TextAlign.center,
          )
        else
          Text(
            '...',
            style: text.smallParagraph?.copyWith(color: colors.checksum),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 4),
        Text(
          formattedAddress.toLowerCase(),
          style: text.smallParagraph?.copyWith(
            color: colors.textPrimary,
            fontFamily: AppTextTheme.fontFamilySecondary,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildExplorerLink(AppColorsV2 colors, AppTextTheme text) {
    return GestureDetector(
      onTap: _openExplorer,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.textTertiary, width: 1)),
        ),
        padding: const EdgeInsets.only(bottom: 3),
        child: Text('View in Explorer ↗', style: text.smallParagraph?.copyWith(color: colors.textTertiary)),
      ),
    );
  }

  Widget _buildQrContent(
    PosPaymentRequest request,
    AppColorsV2 colors,
    AppTextTheme text,
    CurrencyDisplayState display,
  ) {
    return Column(
      children: [
        _buildAmountSection(colors, text, display),
        const SizedBox(height: 16),
        QuantusQr(accountId: request.paymentUrl),
        const Spacer(),
        if (!_watching && _watchError != null) _buildErrorSection(colors, text),
        if (_watching) _buildWaitingPill(colors, text),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAmountSection(AppColorsV2 colors, AppTextTheme text, CurrencyDisplayState display) {
    return Column(
      children: [
        Text(
          display.primaryAmount,
          style: text.totalMinedBlocks?.copyWith(color: colors.textPrimary, letterSpacing: -2.77),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '≈ ${display.secondaryAmount}',
              style: text.paragraph?.copyWith(color: colors.textTertiary, fontFamily: AppTextTheme.fontFamilySecondary),
            ),
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

  Widget _buildWaitingPill(AppColorsV2 colors, AppTextTheme text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 9),
      decoration: BoxDecoration(
        color: colors.toasterBackground,
        border: Border.all(color: colors.toasterBorder),
        borderRadius: BorderRadius.circular(35),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Loader(size: 14, color: colors.textMuted),
          const SizedBox(width: 9),
          Text('Waiting for payment', style: text.detail?.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }

  Widget _buildErrorSection(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        Text('Network Error', style: text.detail?.copyWith(color: colors.textError)),
        const SizedBox(height: 8),
        QuantusButton.simple(
          label: 'Try Again',
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          onTap: _startWatching,
          variant: ButtonVariant.secondary,
        ),
      ],
    );
  }

  String _formatPaidAt(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'pm' : 'am';
    final ordinal = _ordinalSuffix(dt.day);
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[dt.month - 1];
    final year = dt.year.toString().substring(2);
    return "At $hour:$minute$ampm, ${dt.day}$ordinal $month'$year";
  }

  String _ordinalSuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}
