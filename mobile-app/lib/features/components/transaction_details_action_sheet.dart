import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class TransactionDetailsActionSheet extends StatelessWidget {
  final TransactionEvent transaction;

  const TransactionDetailsActionSheet({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final NumberFormattingService formattingService = NumberFormattingService();

    String formatAmount(BigInt amount) {
      return '${formattingService.formatBalance(amount)} QUAN';
    }

    String formatAddress(String address) {
      return address;
    }

    String formatTimestamp(DateTime timestamp) {
      return DateFormat('dd-MM-yyyy HH:mm:ss').format(timestamp.toLocal());
    }

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 30),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: Colors.black,
          boxShadow: [
            BoxShadow(color: Color(0x0A0A0D12), blurRadius: 8, offset: Offset(0, 8), spreadRadius: -4),
            BoxShadow(color: Color(0x190A0D12), blurRadius: 24, offset: Offset(0, 20), spreadRadius: -4),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transaction Details',
                    style: TextStyle(
                      color: Color(0xFF16CECE),
                      fontSize: 18,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildDetailRow('Amount:', formatAmount(transaction.amount)),
              const SizedBox(height: 12),
              _buildDetailRow('From:', formatAddress(transaction.from)),
              const SizedBox(height: 12),
              FutureBuilder<String>(
                future: HumanReadableChecksumService().getHumanReadableName(transaction.to),
                builder: (context, snapshot) {
                  String checkPhrase = snapshot.data ?? 'Loading checkphrase...';
                  if (snapshot.hasError) checkPhrase = 'Error loading checkphrase';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'To:',
                        style: TextStyle(
                          color: Color(0xFFD9D9D9),
                          fontSize: 16,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        checkPhrase,
                        style: const TextStyle(
                          color: Color(0xFF16CECE),
                          fontSize: 12,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatAddress(transaction.to),
                        style: const TextStyle(
                          color: Color(0xFFD9D9D9),
                          fontSize: 12,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _buildDetailRow('Date:', formatTimestamp(transaction.timestamp)),
              if (transaction.extrinsicHash != null) ...[
                const SizedBox(height: 12),
                _buildDetailRow('Hash:', formatAddress(transaction.extrinsicHash!)),
              ],
              if (transaction is ReversibleTransferEvent) ...[
                const SizedBox(height: 12),
                _buildDetailRow('Status:', (transaction as ReversibleTransferEvent).status.name),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFFD9D9D9),
            fontSize: 12,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
