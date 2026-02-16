import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hex/hex.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
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
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:url_launcher/url_launcher.dart';

enum ReversibleTransactionMode { reversible, guardianIntercept }

class ReversibleTransactionActionSheet extends ConsumerStatefulWidget {
  final ReversibleTransferEvent transaction;
  final ReversibleTransactionMode mode;
  final EntrustedAccount? entrustedAccount;

  const ReversibleTransactionActionSheet({
    super.key,
    required this.transaction,
    this.mode = ReversibleTransactionMode.reversible,
    this.entrustedAccount,
  });

  @override
  ConsumerState<ReversibleTransactionActionSheet> createState() => _ReversibleTransactionActionSheetState();
}

enum _SheetState { initial, confirmCancel, cancelled }

class _ReversibleTransactionActionSheetState extends ConsumerState<ReversibleTransactionActionSheet> {
  late _SheetState _sheetState;
  bool _isCancelling = false;

  late Timer _timer;
  late Duration _remainingTime;

  final NumberFormattingService _formattingService = NumberFormattingService();
  final SettingsService _settingsService = SettingsService();
  final ReversibleTransfersService _reversibleTransfersService = ReversibleTransfersService();

  Future<String> get _checksumFuture {
    final address = widget.transaction.to;

    return HumanReadableChecksumService().getHumanReadableName(address);
  }

  bool get _isReverseDisabled => _remainingTime == Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.transaction.status == ReversibleTransferStatus.CANCELLED) {
      _sheetState = _SheetState.cancelled;
      _remainingTime = Duration.zero;
      _timer = Timer(const Duration(seconds: 1), () {
        // Timer for cancelled transactions - no action needed
      });
    } else {
      _sheetState = _SheetState.initial;
      _remainingTime = widget.transaction.scheduledAt.difference(DateTime.now());
      if (_remainingTime.isNegative) {
        _remainingTime = Duration.zero;
      }
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_remainingTime > Duration.zero) {
            _remainingTime = _remainingTime - const Duration(seconds: 1);
          } else {
            timer.cancel();
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _formatAmount(BigInt amount) {
    return _formattingService.formatBalance(amount, addSymbol: true);
  }

  Widget _buildActionButton({
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback? onPressed,
    bool isDisabled = false,
  }) {
    return GestureDetector(
      onTap: isDisabled ? null : onPressed,
      child: Opacity(
        opacity: isDisabled ? 0.6 : 1.0,
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: ShapeDecoration(
            color: backgroundColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
          ),
          child: Center(
            child: Text(
              label,
              style: context.themeText.smallTitle?.copyWith(color: textColor, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  bool get _isGuardianIntercept => widget.mode == ReversibleTransactionMode.guardianIntercept;

  String get _iconPath => _isGuardianIntercept ? 'assets/high_security/intercept_icon.svg' : 'assets/hourglass.svg';

  String get _title => _isGuardianIntercept ? 'Intercept Transaction' : 'Reversible Transaction';

  String get _subtitle =>
      _isGuardianIntercept ? 'Pull this transaction to your account' : 'Reverse or keep your transaction';

  Color get _titleColor => _isGuardianIntercept ? context.themeColors.yellow : context.themeColors.checksum;

  Color get _confirmationTextColor => _isGuardianIntercept ? context.themeColors.yellow : context.themeColors.textMuted;

  String get _confirmButtonLabel => _isGuardianIntercept ? 'Intercept' : 'Reverse';

  String get _confirmationText => _isGuardianIntercept
      ? 'Are you sure you want to intercept this transaction and pull it to your account?'
      : 'Are you sure you want to reverse this tx?';

  Color get _confirmButtonColor => _isGuardianIntercept ? context.themeColors.yellow : context.themeColors.buttonDanger;

  Color get _confirmButtonTextColor => _isGuardianIntercept ? const Color(0xFF0B0F14) : Colors.white;

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
        _buildHeader(_iconPath, _title, _subtitle, true),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: ShapeDecoration(
            color: context.themeColors.buttonGlass,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          child: ReversibleTimer(remainingTime: _remainingTime),
        ),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 15.0), child: _buildTransactionDetails()),
        const SizedBox(height: 29),
        buttons,
      ],
    );
  }

  Widget _buildCancelledView() {
    if (_isGuardianIntercept) {
      return _buildInterceptedView();
    }
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

  Widget _buildInterceptedView() {
    final hasExtrinsicHash = widget.transaction.extrinsicHash != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 305,
          padding: const EdgeInsets.only(top: 24, left: 15, right: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 16,
            children: [
              SvgPicture.asset('assets/high_security/intercept_icon.svg', width: 38, height: 35),
              SizedBox(
                width: 265,
                child: Text(
                  'Transaction Intercepted',
                  textAlign: TextAlign.center,
                  style: context.themeText.smallTitle?.copyWith(
                    color: context.themeColors.yellow,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              SizedBox(
                width: 275,
                child: Text(
                  'This amount has been pulled to your guardian account',
                  textAlign: TextAlign.center,
                  style: context.themeText.paragraph?.copyWith(
                    color: const Color(0xFFD4D3E0),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              _buildDetailRow('Amount', _formatAmount(widget.transaction.amount)),
            ],
          ),
        ),
        const SizedBox(height: 15),
        if (hasExtrinsicHash) _buildViewExplorerLink(),
      ],
    );
  }

  Widget _buildViewExplorerLink() {
    return GestureDetector(
      onTap: () async {
        final Uri url = Uri.parse(
          '${AppConstants.explorerEndpoint}/reversible-transactions/${widget.transaction.extrinsicHash}',
        );
        await launchUrl(url);
      },
      child: SizedBox(
        width: 136,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          spacing: 18,
          children: [
            Text(
              'View in Explorer',
              textAlign: TextAlign.center,
              style: context.themeText.detail?.copyWith(color: const Color(0xFF16CECE), fontWeight: FontWeight.w600),
            ),
            const Icon(Icons.open_in_new, size: 12, color: Color(0xFF16CECE)),
          ],
        ),
      ),
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
                  color: titleIsGreen ? _titleColor : context.themeColors.textPrimary,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(subtitle, style: context.themeText.detail?.copyWith(color: const Color(0xFFD4D3E0))),
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
          child: _buildActionButton(
            label: 'Keep',
            backgroundColor: context.themeColors.buttonNeutral,
            textColor: context.themeColors.textSecondary,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ),
        const SizedBox(width: 22),
        Expanded(
          child: _buildActionButton(
            label: _confirmButtonLabel,
            backgroundColor: _isGuardianIntercept ? _confirmButtonColor : context.themeColors.buttonDanger,
            textColor: _isGuardianIntercept ? _confirmButtonTextColor : Colors.white,
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
            _confirmationText,
            textAlign: TextAlign.center,
            style: context.themeText.paragraph?.copyWith(color: _confirmationTextColor, fontWeight: FontWeight.w400),
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
                child: _buildActionButton(
                  label: 'Keep',
                  backgroundColor: context.themeColors.buttonNeutral,
                  textColor: context.themeColors.textSecondary,
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ),
              const SizedBox(width: 22),
              Expanded(
                flex: 5,
                child: _buildActionButton(
                  label: _confirmButtonLabel,
                  backgroundColor: _isGuardianIntercept ? _confirmButtonColor : context.themeColors.buttonDanger,
                  textColor: _isGuardianIntercept ? _confirmButtonTextColor : Colors.white,
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

      if (_isGuardianIntercept) {
        final guardianAccount = widget.entrustedAccount != null
            ? await HighSecurityService().getGuardianAccount(widget.entrustedAccount!)
            : null;
        if (guardianAccount == null) {
          throw Exception(
            'Guardian account not found. Entrusted Account must be set! ${widget.entrustedAccount?.parentAccountId}',
          );
        }
        await _reversibleTransfersService.interceptTransaction(
          guardianAccount: guardianAccount,
          transactionId: transactionId,
        );
      } else {
        await _reversibleTransfersService.cancelReversibleTransfer(
          account: senderAccount.account as Account,
          transactionId: transactionId,
        );
      }

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

      _timer.cancel();
      setState(() {
        _remainingTime = Duration.zero;
        _sheetState = _SheetState.cancelled;
      });
    } catch (e, stackTrace) {
      debugPrint('Failed to cancel transaction: $e');
      debugPrint('Stack trace: $stackTrace');
      // ignore: use_build_context_synchronously
      if (mounted) context.showErrorToaster(message: 'Failed to cancel: $e');
    } finally {
      setState(() {
        _isCancelling = false;
      });
    }
  }
}
