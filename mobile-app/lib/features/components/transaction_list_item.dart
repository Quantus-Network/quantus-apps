import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/transaction_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/transaction_details_action_sheet.dart';
import 'package:resonance_network_wallet/models/pending_transfer_event.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';

class TransactionListItem extends StatefulWidget {
  final TransactionEvent transaction;
  final String currentWalletAddress;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.currentWalletAddress,
  });

  @override
  TransactionListItemState createState() => TransactionListItemState();
}

class TransactionListItemState extends State<TransactionListItem> {
  Timer? _timer;
  Duration? _remainingTime;
  bool get isSent => widget.transaction.from == widget.currentWalletAddress;
  bool get isPending =>
      widget.transaction is PendingTransactionEvent ||
      widget.transaction.isReversibleScheduled;

  String get title {
    if (widget.transaction.isReversibleCancelled) return 'Cancelled';
    if (isSent && isPending) return 'Sending';
    if (!isSent && isPending) return 'Receiving';
    if (isSent) return 'Sent';
    return 'Received';
  }

  Color get titleColor {
    if (widget.transaction.isReversibleCancelled) {
      return const Color(0xFFFF2D53);
    }
    if (isSent && isPending) return const Color(0xFF16CECE);
    if (!isSent && isPending) return const Color(0xFFB259F2);
    if (isSent) return const Color(0xFF16CECE);
    return const Color(0xFFB259F2);
  }

  @override
  void initState() {
    super.initState();
    if (widget.transaction.isReversibleScheduled) {
      final tx = widget.transaction as ReversibleTransferEvent;
      _remainingTime = tx.remainingTime;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final tx = widget.transaction as ReversibleTransferEvent;
        final remaining = tx.remainingTime;
        if (remaining >= const Duration(seconds: 1)) {
          setState(() {
            _remainingTime = remaining;
          });
        } else {
          setState(() {
            _remainingTime = Duration.zero;
          });
          timer.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  final NumberFormattingService _formattingService = NumberFormattingService();

  String _formatAmount(BigInt amount) {
    return '${_formattingService.formatBalance(amount)} QUAN';
  }

  String _formatAddress(String address) {
    return AddressFormattingService.formatAddress(
      address,
      prefix: 5,
      ellipses: '...',
      postFix: 5,
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(timestamp.toLocal());
  }

  String _getSubtitle(TransactionEvent transaction) {
    String address = isSent ? widget.transaction.to : widget.transaction.from;
    String prefix =
        '${isSent ? 'to' : 'from'} '
        '${_formatAddress(address)}';
    if (widget.transaction.isReversibleScheduled) {
      return prefix;
    }
    return '$prefix | ${_formatTimestamp(widget.transaction.timestamp)}';
  }

  void _showActionSheet(BuildContext context) {
    Widget sheet;

    if (widget.transaction.isReversibleScheduled && isSent) {
      sheet = TransactionActionSheet(
        transaction: widget.transaction as ReversibleTransferEvent,
        currentWalletAddress: widget.currentWalletAddress,
      );
    } else {
      sheet = TransactionDetailsActionSheet(
        transaction: widget.transaction,
        currentWalletAddress: widget.currentWalletAddress,
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    const Color(0xFF312E6E).useOpacity(0.4),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: sheet),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSent = widget.transaction.from == widget.currentWalletAddress;
    final isFailed =
        widget.transaction is PendingTransactionEvent &&
        (widget.transaction as PendingTransactionEvent).transactionState ==
            TransactionState.failed;

    const textStyle = TextStyle(fontFamily: 'Fira Code', color: Colors.white);

    return InkWell(
      onTap: () {
        _showActionSheet(context);
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (widget.transaction.isReversibleCancelled)
                  SvgPicture.asset('assets/stop_icon.svg', width: 21)
                else if (isFailed)
                  SvgPicture.asset('assets/send_failed_icon.svg', width: 21)
                else
                  Image.asset(
                    isSent
                        ? 'assets/send_icon.png'
                        : 'assets/receive_icon_sm.png',
                    width: 21,
                  ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: title,
                              style: textStyle.copyWith(
                                color: titleColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(
                              text:
                                  // ignore: lines_longer_than_80_chars
                                  ' ${_formatAmount(widget.transaction.amount)}',
                              style: textStyle.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: widget.transaction.isReversibleCancelled
                                    ? const Color(0xFFD9D9D9)
                                    : textStyle.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _getSubtitle(widget.transaction),
                        style: textStyle.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildStatusOrTimer(),
        ],
      ),
    );
  }

  Widget _buildStatusOrTimer() {
    if (widget.transaction is PendingTransactionEvent) {
      return _PendingStatusDisplay(
        transaction: widget.transaction as PendingTransactionEvent,
      );
    }

    if (widget.transaction is ReversibleTransferEvent) {
      final tx = widget.transaction as ReversibleTransferEvent;
      switch (tx.status) {
        case ReversibleTransferStatus.SCHEDULED:
          if (_remainingTime != null && _remainingTime! > Duration.zero) {
            return _TimerDisplay(
              duration: DatetimeFormattingService.formatDuration(
                _remainingTime!,
              ).formatted,
              isSending: widget.transaction.from == widget.currentWalletAddress,
            );
          } else {
            return const _StatusDisplay(status: 'Pending');
          }
        case ReversibleTransferStatus.EXECUTED:
          return const SizedBox.shrink();
        case ReversibleTransferStatus.CANCELLED:
          return const SizedBox.shrink();
      }
    }
    return const SizedBox.shrink();
  }
}

class _TimerDisplay extends StatelessWidget {
  final String duration;
  final bool isSending;

  const _TimerDisplay({required this.duration, required this.isSending});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: ShapeDecoration(
        color: const Color(0x3F000000), // black w/ alpha
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: Color(0x26FFFFFF),
          ), // white w/ alpha
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Text(
            duration,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w400,
            ),
          ),
          if (isSending) const SizedBox(width: 10),
          if (isSending)
            SvgPicture.asset('assets/stop_icon.svg', width: 13, height: 13),
        ],
      ),
    );
  }
}

class _StatusDisplay extends StatelessWidget {
  final String status;
  const _StatusDisplay({required this.status});

  @override
  Widget build(BuildContext context) {
    return Text(
      status,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontFamily: 'Fira Code',
      ),
    );
  }
}

class _PendingStatusDisplay extends StatelessWidget {
  final PendingTransactionEvent transaction;
  const _PendingStatusDisplay({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const ShapeDecoration(
            color: Colors.yellow,
            shape: OvalBorder(),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          transaction.transactionState.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontFamily: 'Fira Code',
          ),
        ),
      ],
    );
  }
}
