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
        if (mounted) setState(() => _paidTransfer = tx);
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

  void _newCharge() {
    Navigator.of(context).popUntil((route) => route.isFirst);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PosAmountScreen()));
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
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: _isPaid ? 'Done' : 'New Charge',
          onTap: _newCharge,
          variant: ButtonVariant.primary,
        ),
      ),
    );
  }

  Widget _buildPaidContent(AppColorsV2 colors, AppTextTheme text, String amountDisplay) {
    return Column(
      children: [
        const Spacer(),
        Icon(Icons.check_circle_rounded, color: colors.accentGreen, size: 96),
        const SizedBox(height: 24),
        Text('Paid', style: text.extraLargeTitle?.copyWith(color: colors.accentGreen, fontSize: 48)),
        const SizedBox(height: 16),
        Text(amountDisplay, style: text.mediumTitle?.copyWith(color: colors.textSecondary)),
        const Spacer(),
      ],
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
}
