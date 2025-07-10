import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class RecentTransactionsList extends StatelessWidget {
  final List<TransactionEvent> transactions;
  final String currentWalletAddress;
  final bool Function(TransactionEvent)? filter;

  const RecentTransactionsList({
    super.key,
    required this.transactions,
    required this.currentWalletAddress,
    this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final transactionsToShow = filter == null ? transactions : transactions.where(filter!).toList();

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: ShapeDecoration(
        color: const Color(0x3F000000), // black w/ alpha
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (transactionsToShow.isEmpty)
            const Text(
              'No transactions yet.',
              style: TextStyle(color: Colors.white, fontFamily: 'Fira Code'),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactionsToShow.length,
              itemBuilder: (context, index) {
                return _TransactionListItem(
                  transaction: transactionsToShow[index],
                  currentWalletAddress: currentWalletAddress,
                );
              },
              separatorBuilder: (context, index) => const _Divider(),
            ),
        ],
      ),
    );
  }
}

class _TransactionListItem extends StatefulWidget {
  final TransactionEvent transaction;
  final String currentWalletAddress;

  const _TransactionListItem({required this.transaction, required this.currentWalletAddress});

  @override
  _TransactionListItemState createState() => _TransactionListItemState();
}

class _TransactionListItemState extends State<_TransactionListItem> {
  Timer? _timer;
  Duration? _remainingTime;

  @override
  void initState() {
    super.initState();
    if (widget.transaction is ReversibleTransferEvent) {
      final tx = widget.transaction as ReversibleTransferEvent;
      if (tx.status == ReversibleTransferStatus.SCHEDULED) {
        _remainingTime = tx.scheduledAt.difference(DateTime.now());
        if (_remainingTime!.isNegative) {
          _remainingTime = Duration.zero;
        }
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            if (_remainingTime! > Duration.zero) {
              _remainingTime = _remainingTime! - const Duration(seconds: 1);
            } else {
              _timer?.cancel();
            }
          });
        });
      }
    }
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

  final NumberFormattingService _formattingService = NumberFormattingService();

  String _formatAmount(BigInt amount) {
    return '${_formattingService.formatBalance(amount)} QUAN';
  }

  String _formatAddress(String address) {
    return address.shortenedCryptoAddress(prefix: 5, ellipses: '...', postFix: 5);
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(timestamp.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final isSent = widget.transaction.from == widget.currentWalletAddress;
    const textStyle = TextStyle(fontFamily: 'Fira Code', color: Colors.white);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(isSent ? 'assets/send_icon.png' : 'assets/receive_icon_sm.png', width: 21, height: 17),
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
                            text: isSent ? 'Sent' : 'Receive',
                            style: textStyle.copyWith(
                              color: const Color(0xFF16CECE),
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          TextSpan(
                            text: ' ${_formatAmount(widget.transaction.amount)}',
                            style: textStyle.copyWith(fontSize: 14, fontWeight: FontWeight.w400),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${isSent ? 'to' : 'from'} ${_formatAddress(isSent ? widget.transaction.to : widget.transaction.from)} | ${_formatTimestamp(widget.transaction.timestamp)}',
                      style: textStyle.copyWith(fontSize: 11, fontWeight: FontWeight.w300),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _buildStatusOrTimer(),
      ],
    );
  }

  Widget _buildStatusOrTimer() {
    if (widget.transaction is ReversibleTransferEvent) {
      final tx = widget.transaction as ReversibleTransferEvent;
      switch (tx.status) {
        case ReversibleTransferStatus.SCHEDULED:
          if (_remainingTime != null && _remainingTime! > Duration.zero) {
            return _TimerDisplay(
              duration: _remainingTime!,
              formatDuration: _formatDuration,
              isSending: widget.transaction.from == widget.currentWalletAddress,
            );
          }
          return const _StatusDisplay(status: 'Pending');
        case ReversibleTransferStatus.EXECUTED:
          return const SizedBox.shrink();
        case ReversibleTransferStatus.CANCELLED:
          return const _StatusDisplay(status: 'Cancelled');
      }
    }
    return const SizedBox.shrink();
  }
}

class _TimerDisplay extends StatelessWidget {
  final Duration duration;
  final String Function(Duration) formatDuration;
  final bool isSending;

  const _TimerDisplay({required this.duration, required this.formatDuration, required this.isSending});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      decoration: ShapeDecoration(
        color: const Color(0x3F000000), // black w/ alpha
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0x26FFFFFF)), // white w/ alpha
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Text(
            formatDuration(duration),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w400,
            ),
          ),
          if (isSending) const SizedBox(width: 10),
          if (isSending) SvgPicture.asset('assets/stop_icon.svg', width: 13, height: 13),
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
      style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Fira Code'),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 7.0),
      child: Divider(
        color: Color(0x26FFFFFF), // white w/ alpha
        height: 1,
      ),
    );
  }
}
