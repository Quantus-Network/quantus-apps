import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/copy_icon.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/features/components/error_details_display.dart';
import 'package:resonance_network_wallet/features/components/reversible_timer.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/models/transaction_role.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionDetailsActionSheet extends ConsumerStatefulWidget {
  final TransactionEvent transaction;
  final TransactionRole role;

  const TransactionDetailsActionSheet({super.key, required this.transaction, required this.role});

  @override
  ConsumerState<TransactionDetailsActionSheet> createState() => _TransactionDetailsActionSheetState();
}

class _TransactionDetailsActionSheetState extends ConsumerState<TransactionDetailsActionSheet> {
  Timer? _timer;
  late Duration _remainingTime;

  Future<String> get _checksumFuture {
    // Miner reward does not have a real address as the counterpart
    if (widget.transaction is MinerRewardEvent) {
      return Future.value('');
    }

    final address = widget.role == TransactionRole.sender ? widget.transaction.to : widget.transaction.from;

    return HumanReadableChecksumService().getHumanReadableName(address);
  }

  String? get errorMsg {
    if (widget.transaction.isFailed) {
      final tx = widget.transaction;

      if (tx is PendingTransactionEvent) {
        final pending = tx;

        return pending.error;
      }
    }

    return null;
  }

  String get title {
    if (widget.transaction.isFailed) {
      final tx = widget.transaction;

      if (tx is PendingTransactionEvent) {
        final pending = tx;
        print('pending error: ${pending.error}');
      }
      return 'TRANSACTION\nFAILED';
    }
    if (widget.transaction.isReversibleCancelled) {
      return 'TRANSACTION\nCANCELLED';
    }
    if (widget.role == TransactionRole.receiver && widget.transaction.isReversibleScheduled) {
      return 'RECEIVING';
    }

    if (widget.transaction is PendingTransactionEvent) {
      return widget.role == TransactionRole.sender ? 'SENDING' : 'RECEIVING';
    }

    if (widget.role == TransactionRole.sender) {
      return 'SENT';
    }
    return 'RECEIVED';
  }

  String get detailText {
    if (widget.transaction.isFailed ||
        (widget.role == TransactionRole.sender && widget.transaction.isReversibleCancelled)) {
      return 'to';
    }
    if (widget.role == TransactionRole.receiver && widget.transaction.isReversibleScheduled) {
      return 'received in';
    }
    if (widget.transaction is MinerRewardEvent) {
      return '💰';
    }
    if (widget.role == TransactionRole.receiver && widget.transaction.isReversibleCancelled) {
      return 'from';
    }
    if (widget.role == TransactionRole.sender) {
      if (widget.transaction is PendingTransactionEvent) {
        return 'sending to';
      }
      return 'was successfully sent to';
    }
    if (widget.transaction is PendingTransactionEvent) {
      return 'receiving from';
    }
    return 'received from';
  }

  void _retryFailedTx() async {
    if (!mounted) return;

    final tx = widget.transaction as PendingTransactionEvent;

    final submissionService = ref.read(transactionSubmissionServiceProvider);
    final account = ref.read(accountsProvider.notifier).getAccountWithId(tx.from);
    if (account == null) {
      print("Couldn't find account ${tx.from}");
      return;
    }

    try {
      if (tx.delaySeconds <= 0) {
        await submissionService.balanceTransfer(account, tx.to, tx.amount, tx.fee!, tx.blockNumber);
      } else {
        await submissionService.scheduleReversibleTransferWithDelaySeconds(
          account: account,
          recipientAddress: tx.to,
          amount: tx.amount,
          delaySeconds: tx.delaySeconds,
          feeEstimate: tx.fee!,
          blockHeight: tx.blockNumber,
        );
      }

      // ignore: use_build_context_synchronously
      Navigator.of(context).pop();
    } catch (e) {
      print('Retrying failed: $e');
      // ignore: use_build_context_synchronously
      context.showErrorToaster(message: 'Retrying Failed: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.transaction.isReversibleScheduled) {
      _remainingTime = widget.transaction.timeRemaining;
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final remaining = widget.transaction.timeRemaining;
        if (remaining > Duration.zero) {
          setState(() {
            _remainingTime = remaining;
          });
        } else {
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

  @override
  Widget build(BuildContext context) {
    final String accountId = widget.role == TransactionRole.sender ? widget.transaction.to : widget.transaction.from;

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
            height: MediaQuery.of(context).size.height * AppConstants.sendingSheetHeightFraction,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 30),
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
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  const SizedBox(height: 50),

                  // Display transaction icon based on type and status
                  if (widget.transaction.isFailed)
                    SvgPicture.asset(
                      'assets/transaction/fail_icon.svg',
                      width: context.themeSize.txDetailsIconWidth,
                      height: context.themeSize.txDetailsIconHeight,
                    )
                  else if (widget.transaction.isReversibleCancelled)
                    SvgPicture.asset('assets/transaction/cancel_icon.svg', width: context.themeSize.txDetailsIconWidth)
                  else
                    widget.role == TransactionRole.sender
                        ? Image.asset('assets/transaction/send_icon.png', height: context.themeSize.txDetailsIconHeight)
                        : SvgPicture.asset(
                            'assets/transaction/receive_icon.svg',
                            height: context.themeSize.txDetailsIconHeight,
                          ),
                  const SizedBox(height: 17),
                  Text(title, textAlign: TextAlign.center, style: context.themeText.largeTitle),
                  if (widget.transaction.isFailed && errorMsg != null) ...[
                    const SizedBox(height: 8),
                    ErrorDetailsButton(error: errorMsg!),
                  ],
                  const SizedBox(height: 26),
                  _buildDetails(),

                  const SizedBox(height: 12),
                  // Copy address button
                  Opacity(
                    opacity: 0.80,
                    child: DottedBorder(
                      color: Colors.white.useOpacity(0.5),
                      strokeWidth: 2,
                      dashLength: 3,
                      gapLength: 3,
                      borderRadius: const Radius.circular(4),
                      child: InkWell(
                        onTap: () => context.copyTextWithToaster(accountId),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 8,
                            children: [
                              const CopyIcon(),
                              Text('Copy Address', style: context.themeText.smallParagraph),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (widget.transaction.isFailed) _buildRetryButton(),
                  if (!widget.transaction.isFailed) _buildViewExplorer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return Column(
      children: [
        const SizedBox(height: 26),

        Button(variant: ButtonVariant.glassOutline, label: 'Retry', onPressed: _retryFailedTx),
      ],
    );
  }

  Widget _buildViewExplorer() {
    final isMinerReward = widget.transaction.isMinerReward;
    final hasExtrinsicHash = widget.transaction.extrinsicHash != null;
    String transactionType = isMinerReward
        ? 'miner-rewards'
        : (widget.transaction.isReversibleScheduled ||
              widget.transaction.isReversibleExecuted ||
              widget.transaction.isReversibleCancelled)
        ? 'reversible-transactions'
        : 'immediate-transactions';

    return Column(
      children: [
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () async {
            if (hasExtrinsicHash) {
              final Uri url = Uri.parse(
                '${AppConstants.explorerEndpoint}/$transactionType/${widget.transaction.extrinsicHash}',
              );
              print('url: $url');
              await launchUrl(url);
            } else if (isMinerReward) {
              final Uri url = Uri.parse(
                '${AppConstants.explorerEndpoint}/$transactionType/${widget.transaction.blockHash}',
              );
              print('miner url: $url');
              await launchUrl(url);
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              Text(
                'View in Explorer',
                textAlign: TextAlign.center,
                style: context.themeText.detail?.copyWith(
                  color: hasExtrinsicHash ? context.themeColors.checksum : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: context.isTablet ? 20 : 12,
                color: hasExtrinsicHash ? context.themeColors.checksum : Colors.grey,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetails() {
    final NumberFormattingService formattingService = NumberFormattingService();
    final String formattedAmount = formattingService.formatBalance(widget.transaction.amount);

    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: formattedAmount, style: context.themeText.mediumTitle),
              TextSpan(text: ' ${AppConstants.tokenSymbol}', style: context.themeText.paragraph),
            ],
          ),
        ),
        Text(
          detailText,
          textAlign: TextAlign.center,
          style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.textMuted),
        ),
        if (widget.role == TransactionRole.receiver && widget.transaction.isReversibleScheduled)
          ReversibleTimer(remainingTime: _remainingTime),
        if (widget.transaction is! MinerRewardEvent) ...[
          // Normal Events
          FutureBuilder(
            future: _checksumFuture,
            builder: (context, snapshot) {
              String checkPhrase = snapshot.data ?? 'Loading checkphrase...';
              if (snapshot.hasError) checkPhrase = 'Error loading checkphrase';

              return Text(checkPhrase, textAlign: TextAlign.center, style: context.themeText.paragraph);
            },
          ),
          Text(
            widget.role == TransactionRole.sender ? widget.transaction.to : widget.transaction.from,
            textAlign: TextAlign.center,
            style: context.themeText.tiny,
          ),
        ] else ...[
          // Mining Reward Events
          Text('Mining Reward', textAlign: TextAlign.center, style: context.themeText.paragraph),
        ],
      ],
    );
  }
}
