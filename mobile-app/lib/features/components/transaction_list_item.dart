import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/features/components/reversible_transaction_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/transaction_details_action_sheet.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/models/transaction_role.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';

class TransactionListItem extends StatefulWidget {
  final TransactionEvent transaction;
  final TransactionRole role;
  final bool showFromAndTo;

  const TransactionListItem({super.key, required this.transaction, required this.role, this.showFromAndTo = true});

  @override
  TransactionListItemState createState() => TransactionListItemState();
}

class TransactionListItemState extends State<TransactionListItem> {
  Timer? _timer;
  Duration? _remainingTime;

  bool get isPendingOrScheduled => widget.transaction.isPendingOrScheduled;
  TransactionRole get role => widget.role;

  String get title {
    if (widget.transaction.isReversibleCancelled) return 'Cancelled';

    switch (role) {
      case TransactionRole.sender:
        if (isPendingOrScheduled) {
          return 'Sending';
        }
        return 'Sent';
      case TransactionRole.receiver:
        if (isPendingOrScheduled) {
          return 'Receiving';
        }
        return 'Received';
      case TransactionRole.both:
        if (isPendingOrScheduled) {
          return 'Sending/Receiving';
        }
        return 'Sent/Received';
    }
  }

  Color get titleColor => context.themeColors.textPrimary;

  Color get amountColor {
    if (widget.transaction.isReversibleCancelled) {
      return context.themeColors.textPrimary;
    }
    if (role == TransactionRole.sender && isPendingOrScheduled) {
      return context.themeColors.textPrimary;
    }
    if (role == TransactionRole.receiver && isPendingOrScheduled) {
      return context.themeColors.textPrimary;
    }
    if (role == TransactionRole.sender) {
      return context.themeColors.checksumDarker;
    } else {
      // default - receiver
      return context.themeColors.pink;
    }
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
    return _formattingService.formatBalance(amount, addSymbol: true);
  }

  String _formatAddress(String address) {
    if (context.isTablet) return address;

    return AddressFormattingService.formatAddress(address, prefix: 5, ellipses: '...', postFix: 5);
  }

  String _getSubtitle() {
    // Special handling for mining rewards
    if (widget.transaction is MinerRewardEvent) {
      return 'Mining Reward';
    }

    String senderAddress = _formatAddress(widget.transaction.from);
    String receiverAddress = _formatAddress(widget.transaction.to);
    if (widget.showFromAndTo) {
      return 'from $senderAddress \nto $receiverAddress';
    } else {
      return role == TransactionRole.sender ? 'to $receiverAddress' : 'from $senderAddress';
    }
  }

  String _getTimestampString() {
    return DatetimeFormattingService.formatTimestamp(widget.transaction.timestamp);
  }

  @override
  Widget build(BuildContext context) {
    final isFailed =
        widget.transaction is PendingTransactionEvent &&
        (widget.transaction as PendingTransactionEvent).transactionState == TransactionState.failed;

    return InkWell(
      onTap: () {
        showTransactionActionSheet(context, transaction: widget.transaction, role: widget.role);
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
                  SvgPicture.asset('assets/transaction/cancel_icon.svg', width: context.themeSize.txListItemIconWidth)
                else if (isFailed)
                  SvgPicture.asset('assets/transaction/fail_icon.svg', width: context.themeSize.txListItemIconWidth)
                else
                  role == TransactionRole.sender
                      ? Image.asset('assets/transaction/send_icon.png', width: context.themeSize.txListItemIconWidth)
                      : SvgPicture.asset(
                          'assets/transaction/receive_icon.svg',
                          width: context.themeSize.txListItemIconWidth,
                        ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(title, style: context.themeText.smallParagraph?.copyWith(color: titleColor)),
                          Text(
                            _formatAmount(widget.transaction.amount),
                            style: context.themeText.smallParagraph?.copyWith(color: amountColor),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_getSubtitle(), style: context.themeText.tiny),
                          _buildStatusOrTimer(),
                        ],
                      ),
                      if (!widget.transaction.isReversibleScheduled)
                        Text(
                          _getTimestampString(),
                          style: context.themeText.tiny?.copyWith(color: Colors.white.withValues(alpha: 0.60)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusOrTimer() {
    if (widget.transaction is PendingTransactionEvent) {
      return _PendingStatusDisplay(transaction: widget.transaction as PendingTransactionEvent);
    }

    if (widget.transaction is ReversibleTransferEvent) {
      final tx = widget.transaction as ReversibleTransferEvent;
      switch (tx.status) {
        case ReversibleTransferStatus.SCHEDULED:
          if (_remainingTime != null && _remainingTime! > Duration.zero) {
            return _TimerDisplay(
              duration: DatetimeFormattingService.formatDuration(_remainingTime!).formatted,
              isSending: role == TransactionRole.sender,
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

void showTransactionActionSheet(BuildContext context, {required TransactionEvent transaction, required role}) {
  final container = ProviderScope.containerOf(context, listen: false);
  final activeDisplayAccount = container.read(activeAccountProvider).value;
  EntrustedAccount? entrustedAccount;
  if (activeDisplayAccount is EntrustedDisplayAccount) {
    entrustedAccount = activeDisplayAccount.account;
  }
  final isEntrustedAccount = entrustedAccount != null;

  Widget sheet;

  if (transaction is ReversibleTransferEvent) {
    final reversibleTx = transaction;
    if ((reversibleTx.isReversibleScheduled || reversibleTx.isReversibleCancelled) &&
        (role == TransactionRole.sender || role == TransactionRole.both)) {
      sheet = ReversibleTransactionActionSheet(
        transaction: reversibleTx,
        mode: isEntrustedAccount ? ReversibleTransactionMode.guardianIntercept : ReversibleTransactionMode.reversible,
        entrustedAccount: entrustedAccount,
      );
    } else {
      sheet = TransactionDetailsActionSheet(transaction: transaction, role: role);
    }
  } else {
    sheet = TransactionDetailsActionSheet(transaction: transaction, role: role);
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
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
                colors: [Colors.black, const Color(0xFF312E6E).useOpacity(0.4), Colors.black],
              ),
            ),
          ),
        ),
        Positioned(bottom: 0, left: 0, right: 0, child: sheet),
      ],
    ),
  );
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
          side: const BorderSide(width: 1, color: Color(0x26FFFFFF)), // white w/ alpha
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Text(duration, textAlign: TextAlign.center, style: context.themeText.detail),
          if (isSending) const SizedBox(width: 10),
          if (isSending) SvgPicture.asset('assets/transaction/cancel_icon.svg', width: context.isTablet ? 16 : 13),
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
    return Text(status, style: context.themeText.detail);
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
          width: context.isTablet ? 12 : 8,
          height: context.isTablet ? 12 : 8,
          decoration: const ShapeDecoration(color: Colors.yellow, shape: OvalBorder()),
        ),
        const SizedBox(width: 8),
        Text(transaction.transactionState.name, style: context.themeText.detail),
      ],
    );
  }
}

class TransactionSkeleton extends StatelessWidget {
  const TransactionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      spacing: 8,
      children: [
        Row(
          children: [
            Expanded(child: Skeleton(height: 16)),
            SizedBox(width: 24),
            Spacer(),
            Skeleton(width: 60, height: 16),
          ],
        ),
        Skeleton(height: 16),
        Skeleton(height: 16),
      ],
    );
  }
}
