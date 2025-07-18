import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hex/hex.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class TransactionActionSheet extends StatefulWidget {
  final ReversibleTransferEvent transaction;
  final String currentWalletAddress;

  const TransactionActionSheet({
    super.key,
    required this.transaction,
    required this.currentWalletAddress,
  });

  @override
  State<TransactionActionSheet> createState() => _TransactionActionSheetState();
}

enum _SheetState { initial, confirmCancel, cancelled }

class _TransactionActionSheetState extends State<TransactionActionSheet> {
  _SheetState _sheetState = _SheetState.initial;
  Timer? _timer;
  Duration? _remainingTime;
  bool _isCancelling = false;
  String? _errorMessage;

  final NumberFormattingService _formattingService = NumberFormattingService();
  final SettingsService _settingsService = SettingsService();
  final ReversibleTransfersService _reversibleTransfersService =
      ReversibleTransfersService();

  @override
  void initState() {
    super.initState();
    _remainingTime = widget.transaction.scheduledAt.difference(DateTime.now());
    if (_remainingTime!.isNegative) {
      _remainingTime = Duration.zero;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_remainingTime! > Duration.zero) {
          _remainingTime = _remainingTime! - const Duration(seconds: 1);
        } else {
          _timer?.cancel();
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  String _formatAmount(BigInt amount) {
    return '${_formattingService.formatBalance(amount)} QUAN';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 18),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(
              color: Color(0x0A0A0D12),
              blurRadius: 8,
              offset: Offset(0, 8),
              spreadRadius: -4,
            ),
            BoxShadow(
              color: Color(0x190A0D12),
              blurRadius: 24,
              offset: Offset(0, 20),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            // const SizedBox(height: 20.0),
            _buildContent(),
          ],
        ),
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

  // basic view with different buttons at the bottom - for initial and confirm cancel views
  Widget _buildBaseBlockView(Widget buttons, double verticalPadding) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          'assets/hourglass.svg',
          'Reversible\nTransaction',
          'Cancel or keep your send',
          true,
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white, thickness: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Column(
            children: [
              const SizedBox(height: 12),
              _buildTimer(),
              const SizedBox(height: 12),
              const Divider(color: Colors.white, thickness: 1),
              const SizedBox(height: 12),
              _buildTransactionDetails(),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Divider(color: Colors.white, thickness: 1),
        SizedBox(height: verticalPadding),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: buttons,
        ),
      ],
    );
  }

  Widget _buildCancelledView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          'assets/stop_icon.svg',
          'Transaction\nCancelled',
          '',
          false,
        ),
        const SizedBox(height: 20),
        const Divider(color: Colors.white, thickness: 1),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: _buildTransactionDetails(),
        ),
        const SizedBox(height: 22),
        const Divider(color: Colors.white, thickness: 1),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Center(
            child: _buildButton(
              'Done',
              const Color(0xFF5FE49E),
              Colors.black,
              () {
                Navigator.of(context).pop();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitialView() {
    return _buildBaseBlockView(_buildInitialButtons(), 18);
  }

  Widget _buildConfirmCancelView() {
    return _buildBaseBlockView(_buildConfirmCancelButtons(), 6);
  }

  Widget _buildHeader(
    String iconName,
    String title,
    String subtitle,
    bool titleIsGreen,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(iconName, width: 34, height: 34),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Color(titleIsGreen ? 0xFF16CECE : 0xFFD9D9D9),
                  fontSize: 18,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFD9D9D9),
                    fontSize: 12,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimer() {
    if (_remainingTime == null || _remainingTime!.isNegative) {
      return const SizedBox.shrink();
    }
    final timeParts = _formatDuration(_remainingTime!).split(':');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTimePart(timeParts[0]),
        _buildTimeSeparator(),
        _buildTimePart(timeParts[1]),
        _buildTimeSeparator(),
        _buildTimePart(timeParts[2]),
      ],
    );
  }

  Widget _buildTimePart(String part) {
    return Text(
      part,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontFamily: 'Fira Code',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.44,
      ),
    );
  }

  Widget _buildTimeSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0),
      child: Text(
        ':',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontFamily: 'Fira Code',
          fontWeight: FontWeight.w600,
          letterSpacing: -0.44,
        ),
      ),
    );
  }

  Widget _buildTransactionDetails() {
    return Column(
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
          style: const TextStyle(
            color: Color(0xFFD9D9D9),
            fontSize: 16,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: const Color(0xFFD9D9D9),
            fontSize: title == 'Recipient' ? 10 : 16,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildRecipientRow(String address) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 5,
      children: [
        const SizedBox(
          width: 269,
          child: Text(
            'Recipient',
            style: TextStyle(
              color: Color(0xFFD9D9D9),
              fontSize: 16,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          address,
          style: const TextStyle(
            color: Color(0xFFD9D9D9),
            fontSize: 10,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildInitialButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildButton(
          'Keep Transaction',
          const Color(0xFF5FE49E),
          Colors.black,
          () {
            Navigator.of(context).pop();
          },
        ),
        const SizedBox(height: 17),
        _buildButton(
          'Reverse Transaction',
          const Color(0xFFFF2D53),
          Colors.black,
          () {
            setState(() {
              _sheetState = _SheetState.confirmCancel;
            });
          },
        ),
      ],
    );
  }

  Widget _buildButton(
    String text,
    Color bgColor,
    Color textColor,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: ShapeDecoration(
          color: bgColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmCancelButtons() {
    Widget buttons = Column(
      children: [
        const Text(
          'Are you sure you want to cancel this tx?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFD9D9D9),
            fontSize: 16,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        if (_isCancelling)
          const CircularProgressIndicator()
        else ...[
          _buildButton(
            'Yes Cancel',
            const Color(0xFFFF2D53),
            Colors.white,
            _cancelTransaction,
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _sheetState = _SheetState.initial),
            child: Container(
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 1,
                    color: Colors.white.useOpacity(0.50),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: const Text(
                'Keep transaction',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD9D9D9),
                  fontSize: 14,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
    return buttons;
  }

  Future<void> _cancelTransaction() async {
    setState(() {
      _isCancelling = true;
      _errorMessage = null;
    });

    try {
      final senderAccount = await _settingsService.getActiveAccount();

      var txId = widget.transaction.txId;
      if (txId.startsWith('0x')) {
        txId = txId.substring(2);
      }
      final transactionId = HEX.decode(txId);

      await _reversibleTransfersService.cancelReversibleTransfer(
        account: senderAccount,
        transactionId: transactionId,
      );

      setState(() {
        _sheetState = _SheetState.cancelled;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to cancel: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isCancelling = false;
      });
    }
  }
}
