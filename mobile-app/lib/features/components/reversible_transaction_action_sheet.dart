import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hex/hex.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/reversible_timer.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/pending_cancellations_provider.dart';
import 'package:resonance_network_wallet/services/reversible_transfer_monitoring_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/snackbar_extensions.dart';

class ReversibleTransactionActionSheet extends ConsumerStatefulWidget {
  final ReversibleTransferEvent transaction;

  const ReversibleTransactionActionSheet({super.key, required this.transaction});

  @override
  ConsumerState<ReversibleTransactionActionSheet> createState() => _ReversibleTransactionActionSheetState();
}

enum _SheetState { initial, confirmCancel, cancelled }

class _ReversibleTransactionActionSheetState extends ConsumerState<ReversibleTransactionActionSheet> {
  _SheetState _sheetState = _SheetState.initial;
  Timer? _timer;
  Duration? _remainingTime;
  bool _isCancelling = false;

  final NumberFormattingService _formattingService = NumberFormattingService();
  final SettingsService _settingsService = SettingsService();
  final ReversibleTransfersService _reversibleTransfersService = ReversibleTransfersService();

  Future<String> get _checksumFuture {
    final address = widget.transaction.to;

    return HumanReadableChecksumService().getHumanReadableName(address);
  }

  bool get _isReverseDisabled => _remainingTime == null || _remainingTime == Duration.zero;

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.transaction.scheduledAt.difference(DateTime.now());
    if (_remainingTime != null && _remainingTime!.isNegative) {
      _remainingTime = Duration.zero;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingTime != null && _remainingTime! > Duration.zero) {
          _remainingTime = _remainingTime! - const Duration(seconds: 1);
        } else {
          timer.cancel();
          // Maybe close the sheet or show a different state when timer ends.
          // For now, just stopping the timer.
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatAmount(BigInt amount) {
    return _formattingService.formatBalance(amount, addSymbol: true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(color: Colors.black.useOpacity(0.3)),
            ),
          ),
          Container(
            height: MediaQuery.of(context).size.height * 0.83,
            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 18),
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(color: Colors.black),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close, size: context.themeSize.overlayCloseIconSize),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                _buildContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_sheetState) {
      case _SheetState.initial:
        return _buildInitialView();
      case _SheetState.confirmCancel:
        return _buildConfirmCancelView();
      case _SheetState.cancelled:
        return _buildCancelledView();
    }
  }

  // basic view with different buttons at the bottom - for initial and confirm
  // cancel views
  Widget _buildBaseBlockView(Widget buttons, double verticalPadding) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('assets/hourglass.svg', 'Reversible Transaction', 'Reverse or keep your transaction', true),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: ShapeDecoration(
            color: context.themeColors.buttonGlass,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: ReversibleTimer(remainingTime: _remainingTime ?? Duration.zero),
        ),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 15.0), child: _buildTransactionDetails()),
        const SizedBox(height: 29),
        buttons,
      ],
    );
  }

  Widget _buildCancelledView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('assets/transaction/cancel_icon.svg', 'Transaction Reversed', '', false),
        const SizedBox(height: 20),
        const Divider(color: Colors.white, thickness: 1),
        const SizedBox(height: 20),
        _buildTransactionDetails(),
      ],
    );
  }

  Widget _buildInitialView() {
    return _buildBaseBlockView(_buildInitialButtons(), 18);
  }

  Widget _buildConfirmCancelView() {
    return _buildBaseBlockView(_buildConfirmCancelButtons(), 6);
  }

  Widget _buildHeader(String iconName, String title, String subtitle, bool titleIsGreen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(iconName, width: context.isTablet ? 54 : 34, height: context.isTablet ? 54 : 34),
              const SizedBox(height: 16),
              Text(
                title,
                style: context.themeText.smallTitle?.copyWith(
                  color: titleIsGreen ? context.themeColors.checksum : context.themeColors.textPrimary,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: context.themeText.detail?.copyWith(color: const Color(0xFFD9D9D9))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildRecipientRow(widget.transaction.to),
        const SizedBox(height: 12),
        _buildDetailRow('Amount', _formatAmount(widget.transaction.amount)),
      ],
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: context.themeText.paragraph?.copyWith(color: const Color(0xFFD9D9D9), fontWeight: FontWeight.w600),
        ),
        Text(value, style: context.themeText.largeTag?.copyWith(color: const Color(0xFFD9D9D9))),
      ],
    );
  }

  Widget _buildRecipientRow(String address) {
    final formattedAddress = AddressFormattingService.formatAddress(address);

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5,
      children: [
        SizedBox(
          width: 269,
          child: Text(
            'Recipient',
            style: context.themeText.paragraph?.copyWith(color: const Color(0xFFD9D9D9), fontWeight: FontWeight.w600),
          ),
        ),
        FutureBuilder(
          future: _checksumFuture,
          builder: (context, snapshot) {
            String checkPhrase = snapshot.data ?? 'Loading checkphrase...';
            if (snapshot.hasError) checkPhrase = 'Error loading checkphrase';

            return Text(
              checkPhrase,
              style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.checksum),
            );
          },
        ),
        Text(
          context.isTablet ? address : formattedAddress,
          style: context.themeText.detail?.copyWith(color: const Color(0xFFD9D9D9)),
        ),
      ],
    );
  }

  Widget _buildInitialButtons() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Button(
            variant: ButtonVariant.neutral,
            label: 'Keep',
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Button(
            variant: ButtonVariant.danger,
            label: 'Reverse',
            onPressed: () {
              setState(() {
                _sheetState = _SheetState.confirmCancel;
              });
            },
            isDisabled: _isReverseDisabled,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmCancelButtons() {
    Widget buttons = Column(
      children: [
        SizedBox(
          width: 305,
          child: Text(
            'Are you sure you want to reverse this tx?',
            textAlign: TextAlign.center,
            style: context.themeText.paragraph?.copyWith(
              color: context.themeColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 29),
        if (_isCancelling)
          const CircularProgressIndicator()
        else
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Button(
                  variant: ButtonVariant.neutral,
                  label: 'Keep',
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                flex: 5,
                child: Button(
                  variant: ButtonVariant.danger,
                  label: 'Reverse',
                  onPressed: _cancelTransaction,
                  isDisabled: _isReverseDisabled,
                ),
              ),
            ],
          ),
      ],
    );
    return buttons;
  }

  Future<void> _cancelTransaction() async {
    setState(() {
      _isCancelling = true;
    });

    try {
      final senderAccount = (await _settingsService.getActiveAccount())!;

      var txId = widget.transaction.txId;
      if (txId.startsWith('0x')) {
        txId = txId.substring(2);
      }
      final transactionId = HEX.decode(txId);

      await _reversibleTransfersService.cancelReversibleTransfer(account: senderAccount, transactionId: transactionId);

      // Update providers/UI and start polling to reflect cancellation quickly
      try {
        // 1) Optimistically update lists using extrinsic hash (always present)
        final extrinsicHash = widget.transaction.extrinsicHash!;
        // Global (all-accounts) controller
        ref
            .read(paginationControllerProvider.notifier)
            .updateReversibleTransferToExecuted(extrinsicHash, ReversibleTransferStatus.CANCELLED);
        ref.read(pendingCancellationsProvider.notifier).addPendingCancellation(widget.transaction.id);

        // Filtered controllers for involved accounts
        final affectedAccounts = <String>{widget.transaction.from, widget.transaction.to};
        for (final accountId in affectedAccounts) {
          ref
              .read(filteredPaginationControllerProviderFamily(AccountIdListCache.get([accountId])).notifier)
              .updateReversibleTransferToExecuted(extrinsicHash, ReversibleTransferStatus.CANCELLED);
        }

        // 2) Start the aggressive poller to confirm final status promptly
        ref.read(reversibleTransferMonitoringServiceProvider).startImmediatePollingForTransfer(widget.transaction);
      } catch (_) {
        // Swallow provider update errors; UI will still show cancelled state below
      }

      _timer?.cancel();
      setState(() {
        _remainingTime = Duration.zero;
        _sheetState = _SheetState.cancelled;
      });
    } catch (e) {
      // ignore: use_build_context_synchronously
      if (mounted) context.showErrorSnackbar(title: 'Failed to cancel', message: e.toString());
    } finally {
      setState(() {
        _isCancelling = false;
      });
    }
  }
}
