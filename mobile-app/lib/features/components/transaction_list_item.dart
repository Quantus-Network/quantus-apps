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

class _TransactionListItem extends StatelessWidget {
  final TransactionEvent transaction;
  final String currentWalletAddress;

  _TransactionListItem({required this.transaction, required this.currentWalletAddress});

  final NumberFormattingService _formattingService = NumberFormattingService();

  String _formatAmount(BigInt amount) {
    // This should be replaced with a proper formatting service
    return '${_formattingService.formatBalance(amount)} QUAN';
  }

  String _formatAddress(String address) {
    return address.shortenedCryptoAddress(prefix: 5, ellipses: '...', postFix: 5);
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('dd-MM-yyyy HH:mm:ss').format(timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final isSent = transaction.from == currentWalletAddress;

    return Container(
      width: double.infinity,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 21,
            height: 17,
            child: SvgPicture.asset(
              isSent ? 'assets/send_icon.svg' : 'assets/receive_icon.svg',
              width: 21,
              height: 17,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Container(
              height: 38.50,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: isSent ? 'Sent' : 'Receive',
                            style: const TextStyle(
                              color: Color(0xFF16CECE),
                              fontSize: 14,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          TextSpan(
                            text: ' ${_formatAmount(transaction.amount)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 23.50,
                    child: Text(
                      '${isSent ? 'to' : 'from'} ${_formatAddress(isSent ? transaction.to : transaction.from)} | ${_formatTimestamp(transaction.timestamp)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
