import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

enum SendOverlayState { confirm, progress, complete }

class SendConfirmationOverlay extends ConsumerStatefulWidget {
  final BigInt amount;
  final String recipientName;
  final String recipientAddress;
  final VoidCallback onClose;
  final BigInt fee;
  final int reversibleTimeSeconds;
  final int blockHeight;

  const SendConfirmationOverlay({
    required this.amount,
    required this.recipientName,
    required this.recipientAddress,
    required this.onClose,
    required this.fee,
    required this.reversibleTimeSeconds,
    required this.blockHeight,
    super.key,
  });

  @override
  SendConfirmationOverlayState createState() => SendConfirmationOverlayState();
}

class SendConfirmationOverlayState
    extends ConsumerState<SendConfirmationOverlay> {
  SendOverlayState currentState = SendOverlayState.confirm;
  String? _errorMessage;
  bool _isSending = false;

  void goHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const Navbar()),
      (route) => false,
    );
  }

  void _handleDismiss() {
    switch (currentState) {
      case SendOverlayState.confirm:
        widget.onClose();
        break;
      case SendOverlayState.progress:
        // do nothing
        break;
      case SendOverlayState.complete:
        goHome();
        break;
    }
  }

  bool get _isReversible => widget.reversibleTimeSeconds > 0;

  final NumberFormattingService _formattingService = NumberFormattingService();
  final SettingsService _settingsService = SettingsService();

  String _formatReversibleTime() {
    final days = widget.reversibleTimeSeconds ~/ 86400;
    final hours = (widget.reversibleTimeSeconds % 86400) ~/ 3600;
    final minutes = (widget.reversibleTimeSeconds % 3600) ~/ 60;

    if (days > 0) {
      return '$days day${days > 1 ? 's' : ''}, '
          '$hours hr${hours != 1 ? 's' : ''}, '
          '$minutes min${minutes != 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '$hours hr${hours != 1 ? 's' : ''}, '
          '$minutes min${minutes != 1 ? 's' : ''}';
    } else {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    }
  }

  Future<void> _confirmSend() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      currentState = SendOverlayState.progress;
      _errorMessage = null;
    });

    try {
      final account = _settingsService.getActiveAccount()!;

      // ignore: use_build_context_synchronously
      if (!context.mounted) {
        return;
      }

      final submissionService = ref.read(transactionSubmissionServiceProvider);

      debugPrint('Attempting balance transfer...');
      debugPrint('  Recipient: ${widget.recipientAddress}');
      debugPrint('  Amount (BigInt): ${widget.amount}');
      debugPrint('  Fee: ${widget.fee}');
      debugPrint('  Reversible time: ${widget.reversibleTimeSeconds}');

      if (widget.reversibleTimeSeconds <= 0) {
        await submissionService.balanceTransfer(
          account,
          widget.recipientAddress,
          widget.amount,
          widget.fee,
          widget.blockHeight,
        );
      } else {
        await submissionService.scheduleReversibleTransferWithDelaySeconds(
          account: account,
          recipientAddress: widget.recipientAddress,
          amount: widget.amount,
          delaySeconds: widget.reversibleTimeSeconds,
          feeEstimate: widget.fee,
          blockHeight: widget.blockHeight,
        );
      }

      RecentAddressesService().addAddress(widget.recipientAddress);

      if (mounted) {
        setState(() {
          currentState = SendOverlayState.complete;
          _isSending = false;
        });
      }
    } catch (e) {
      print('Balance transfer failed: $e');
      if (mounted) {
        setState(() {
          currentState = SendOverlayState.confirm;
          _errorMessage = 'Transfer failed: ${e.toString()}';
          _isSending = false;
        });
      }
    }
  }

  Widget _buildConfirmState() {
    final formattedAmount = _formattingService.formatBalance(widget.amount);
    final formattedFee = _formattingService.formatBalance(widget.fee);

    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Close button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: widget.onClose,
                  child: SizedBox(
                    width: context.themeSize.overlayCloseIconSize,
                    height: context.themeSize.overlayCloseIconSize,
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: context.themeSize.overlayCloseIconSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Send icon and title
          Column(
            children: [
              Center(
                child: Image.asset(
                  'assets/transaction/send_icon.png',
                  width: context.isTablet ? 101 : 61,
                  height: context.isTablet ? 92 : 52,
                ),
              ),
              const SizedBox(height: 17),
              Text(
                'SEND',
                textAlign: TextAlign.center,
                style: context.themeText.largeTitle,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Transaction details
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formattedAmount,
                          style: context.themeText.mediumTitle,
                        ),
                        TextSpan(
                          text: ' ${AppConstants.tokenSymbol}',
                          style: context.themeText.paragraph,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 21),

              // Recipient information
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'To:',
                    style: context.themeText.smallParagraph?.copyWith(
                      color: context.themeColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.recipientName,
                    textAlign: TextAlign.center,
                    style: context.themeText.paragraph?.copyWith(
                      color: context.themeColors.checksum,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.recipientAddress, style: context.themeText.tiny),
                ],
              ),

              if (_isReversible) const SizedBox(height: 21),
              // Reversible time information
              if (_isReversible)
                Container(
                  width: context.themeSize.sendOverlayContainerWidth,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: ShapeDecoration(
                    color: const Color(0xFF313131),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 10,
                    children: [
                      SizedBox(
                        width: context.isTablet ? null : 299,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Reversible for: ',
                                style: context.themeText.smallParagraph,
                              ),
                              TextSpan(
                                text: _formatReversibleTime(),
                                style: context.themeText.detail,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),

          // Error message
          if (_errorMessage != null)
            SizedBox(
              height: 70,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: SingleChildScrollView(
                  child: Text(
                    _errorMessage!,
                    style: context.themeText.detail?.copyWith(
                      color: context.themeColors.textError,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          const Spacer(),
          // Network fee and confirm button
          SizedBox(
            width: context.themeSize.sendOverlayContainerWidth,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Network fee',
                      style: context.themeText.detail?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    Row(
                      spacing: 8,
                      children: [
                        Text(
                          '$formattedFee ${AppConstants.tokenSymbol}',
                          style: context.themeText.detail?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/settings_icon.svg',
                          width: context.isTablet ? 20 : 14,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Button(
                  variant: ButtonVariant.neutral,
                  label: 'Confirm',
                  onPressed: _isSending ? null : _confirmSend,
                ),
              ],
            ),
          ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }

  Widget _buildProgressState() {
    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: goHome,
                  child: SizedBox(
                    width: context.themeSize.overlayCloseIconSize,
                    height: context.themeSize.overlayCloseIconSize,
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: context.themeSize.overlayCloseIconSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 91),
          Column(
            spacing: 18,
            children: [
              SizedBox(
                width: context.isTablet ? 111 : 91,
                height: context.isTablet ? 105 : 85,
                child: SvgPicture.asset('assets/logo/logo.svg'),
              ),
              Text(
                'TRANSACTION \nIN PROGRESS',
                textAlign: TextAlign.center,
                style: context.themeText.largeTitle,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteState() {
    final formattedAmount = _formattingService.formatBalance(widget.amount);

    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Close button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: goHome,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: context.themeSize.overlayCloseIconSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Sent icon and title
          Column(
            children: [
              Center(
                child: Image.asset(
                  'assets/transaction/send_icon.png',
                  width: context.isTablet ? 101 : 61,
                  height: context.isTablet ? 92 : 52,
                ),
              ),
              const SizedBox(height: 17),
              Text(
                'SENDING',
                textAlign: TextAlign.center,
                style: context.themeText.largeTitle,
              ),
            ],
          ),
          const SizedBox(height: 28),

          // Transaction details
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Amount
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: formattedAmount,
                          style: context.themeText.mediumTitle,
                        ),
                        TextSpan(
                          text: ' ${AppConstants.tokenSymbol}',
                          style: context.themeText.paragraph,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Recipient information
              Text(
                'will be sent to',
                textAlign: TextAlign.center,
                style: context.themeText.smallParagraph?.copyWith(
                  color: context.themeColors.textMuted,
                ),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    child: Text(
                      widget.recipientName,
                      textAlign: TextAlign.center,
                      style: context.themeText.paragraph?.copyWith(
                        color: context.themeColors.checksum,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.recipientAddress, style: context.themeText.tiny),
                ],
              ),

              if (_isReversible) const SizedBox(height: 14),
              // Reversible time information
              if (_isReversible)
                Container(
                  width: context.themeSize.sendOverlayContainerWidth,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  decoration: ShapeDecoration(
                    color: const Color(0xFF313131),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 10,
                    children: [
                      SizedBox(
                        width: context.isTablet ? null : 299,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Reversible for: ',
                                style: context.themeText.smallParagraph,
                              ),
                              TextSpan(
                                text: _formatReversibleTime(),
                                style: context.themeText.detail,
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const Spacer(),
          // Done Button
          Button(
            variant: ButtonVariant.neutral,
            label: 'Done',
            onPressed: goHome,
          ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (currentState) {
      case SendOverlayState.confirm:
        content = _buildConfirmState();
        break;
      case SendOverlayState.progress:
        content = _buildProgressState();
        break;
      case SendOverlayState.complete:
        content = _buildCompleteState();
        break;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) return;
        _handleDismiss();
      },
      child: SafeArea(
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
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: ShapeDecoration(
                color: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}
