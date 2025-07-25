import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/dotted_border.dart';
import 'package:resonance_network_wallet/features/components/reversible_timer.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/shared/extensions/transaction_event_extension.dart';
import 'package:url_launcher/url_launcher.dart';

class TransactionDetailsActionSheet extends StatefulWidget {
  final TransactionEvent transaction;
  final String currentWalletAddress;

  const TransactionDetailsActionSheet({
    super.key,
    required this.transaction,
    required this.currentWalletAddress,
  });

  @override
  State<TransactionDetailsActionSheet> createState() =>
      _TransactionDetailsActionSheetState();
}

class _TransactionDetailsActionSheetState
    extends State<TransactionDetailsActionSheet> {
  Timer? _timer;
  Duration? _remainingTime;
  Future<String> get _checksumFuture {
    final address = isSender ? widget.transaction.to : widget.transaction.from;

    return HumanReadableChecksumService().getHumanReadableName(address);
  }

  bool get isSender => widget.transaction.from == widget.currentWalletAddress;

  String get title {
    if (widget.transaction.isFailed) return 'TRANSACTION\nFAILED';
    if (widget.transaction.isReversibleCancelled) {
      return 'TRANSACTION\nCANCELLED';
    }
    if (!isSender && widget.transaction.isReversibleScheduled) {
      return 'RECEIVING';
    }
    if (isSender) {
      return 'SENT';
    }
    return 'RECEIVED';
  }

  String get detailText {
    if (widget.transaction.isFailed ||
        (isSender && widget.transaction.isReversibleCancelled)) {
      return 'to';
    }
    if (!isSender && widget.transaction.isReversibleScheduled) {
      return 'received in';
    }
    if (!isSender && widget.transaction.isReversibleCancelled) {
      return 'from';
    }
    if (isSender) {
      return 'was successfully sent to';
    }
    return 'received from';
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
    final String accountId = isSender
        ? widget.transaction.to
        : widget.transaction.from;

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
            height:
                MediaQuery.of(context).size.height *
                AppConstants.sendingSheetHeightFraction,
            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 30),
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
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
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
                  const SizedBox(height: 50),

                  // Display transaction icon based on type and status
                  if (widget.transaction.isFailed)
                    SvgPicture.asset(
                      'assets/send_failed_icon.svg',
                      width: 51,
                      height: 42,
                    )
                  else if (widget.transaction.isReversibleCancelled)
                    SvgPicture.asset(
                      'assets/stop_icon.svg',
                      width: 51,
                      height: 42,
                    )
                  else
                    Image.asset(
                      isSender
                          ? 'assets/send_icon.png'
                          : 'assets/receive_icon_sm.png',
                      width: 51,
                      height: 42,
                    ),
                  const SizedBox(height: 17),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
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
                        onTap: () async {
                          if (!context.mounted) return;

                          Clipboard.setData(ClipboardData(text: accountId));
                          if (!context.mounted) {
                            return;
                          }
                          showTopSnackBar(
                            context,
                            icon: Container(
                              width: 36,
                              height: 36,
                              decoration: const ShapeDecoration(
                                color: Color(
                                  0xFF494949,
                                ), // Default grey background
                                shape:
                                    OvalBorder(), // Use OvalBorder for circle
                              ),
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                'assets/copy_icon.svg',
                                width: 16,
                                height: 16,
                              ),
                            ),
                            title: 'Copied!',
                            message: 'Address copied to clipboard',
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            spacing: 8,
                            children: [
                              SvgPicture.asset(
                                'assets/copy_icon.svg',
                                width: 20,
                                height: 20,
                              ),
                              const Text(
                                'Copy Address',
                                style: TextStyle(
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
        GestureDetector(
          onTap: () {
            // TO DO: Implement retry logic
          },
          child: Container(
            width: 130,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 10,
              children: [
                Text(
                  'Retry',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewExplorer() {
    String transactionType =
        (widget.transaction.isReversibleScheduled ||
            widget.transaction.isReversibleExecuted ||
            widget.transaction.isReversibleCancelled)
        ? 'reversible-transactions'
        : 'immediate-transactions';

    return Column(
      children: [
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () async {
            if (widget.transaction.extrinsicHash != null) {
              final Uri url = Uri.parse(
                '${AppConstants.explorerEndpoint}/$transactionType/${widget.transaction.extrinsicHash}',
              );
              await launchUrl(url);
            }
          },
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 8,
            children: [
              Text(
                'View in Explorer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF16CECE) /* other-blue */,
                  fontSize: 12,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(
                Icons.open_in_new,
                size: 12,
                color: Color(0xFF16CECE) /* other-blue */,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetails() {
    final NumberFormattingService formattingService = NumberFormattingService();
    final String formattedAmount = formattingService.formatBalance(
      widget.transaction.amount,
    );

    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: formattedAmount,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const TextSpan(
                text: ' ${AppConstants.tokenSymbol}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Text(
          detailText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 12,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
        if (!isSender && widget.transaction.isReversibleScheduled)
          ReversibleTimer(remainingTime: _remainingTime ?? Duration.zero),
        FutureBuilder(
          future: _checksumFuture,
          builder: (context, snapshot) {
            String checkPhrase = snapshot.data ?? 'Loading checkphrase...';
            if (snapshot.hasError) checkPhrase = 'Error loading checkphrase';

            return Text(
              checkPhrase,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            );
          },
        ),
        Text(
          isSender ? widget.transaction.to : widget.transaction.from,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
