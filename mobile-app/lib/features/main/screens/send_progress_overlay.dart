import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';

enum SendOverlayState { confirm, progress, complete }

class SendConfirmationOverlay extends StatefulWidget {
  final BigInt amount;
  final String recipientName;
  final String recipientAddress;
  final VoidCallback onClose;
  final BigInt fee;
  final int reversibleTimeSeconds;

  const SendConfirmationOverlay({
    required this.amount,
    required this.recipientName,
    required this.recipientAddress,
    required this.onClose,
    required this.fee,
    required this.reversibleTimeSeconds,
    super.key,
  });

  @override
  SendConfirmationOverlayState createState() => SendConfirmationOverlayState();
}

class SendConfirmationOverlayState extends State<SendConfirmationOverlay> {
  SendOverlayState _currentState = SendOverlayState.confirm;
  String? _errorMessage;
  bool _isSending = false;
  final NumberFormattingService _formattingService = NumberFormattingService();
  final SettingsService _settingsService = SettingsService();

  String _formatReversibleTime() {
    final days = widget.reversibleTimeSeconds ~/ 86400;
    final hours = (widget.reversibleTimeSeconds % 86400) ~/ 3600;
    final minutes = (widget.reversibleTimeSeconds % 3600) ~/ 60;

    if (days > 0) {
      return '$days day${days > 1 ? 's' : ''}, $hours hr${hours != 1 ? 's' : ''}, $minutes min${minutes != 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '$hours hr${hours != 1 ? 's' : ''}, $minutes min${minutes != 1 ? 's' : ''}';
    } else {
      return '$minutes minute${minutes != 1 ? 's' : ''}';
    }
  }

  Future<void> _confirmSend() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _currentState = SendOverlayState.progress;
      _errorMessage = null;
    });

    try {
      final senderSeed = await _settingsService.getMnemonic();

      if (senderSeed == null || senderSeed.isEmpty) {
        throw Exception('Sender mnemonic not found. Please re-import your wallet.');
      }

      debugPrint('Attempting balance transfer...');
      debugPrint('  Sender Seed: ${senderSeed.substring(0, 4)}...');
      debugPrint('  Recipient: ${widget.recipientAddress}');
      debugPrint('  Amount (BigInt): ${widget.amount}');
      debugPrint('  Fee: ${widget.fee}');
      debugPrint('  Reversible time: ${widget.reversibleTimeSeconds}');

      if (widget.reversibleTimeSeconds <= 0) {
        await BalancesService().balanceTransfer(senderSeed, widget.recipientAddress, widget.amount);
      } else {
        await ReversibleTransfersService().scheduleReversibleTransferWithDelaySeconds(
          senderSeed: senderSeed,
          recipientAddress: widget.recipientAddress,
          amount: widget.amount,
          delaySeconds: widget.reversibleTimeSeconds,
        );
      }

      debugPrint('Balance transfer successful.');

      if (mounted) {
        setState(() {
          _currentState = SendOverlayState.complete;
          _isSending = false;
        });
      }
    } catch (e) {
      debugPrint('Balance transfer failed: $e');
      if (mounted) {
        setState(() {
          _currentState = SendOverlayState.confirm;
          _errorMessage = 'Transfer failed: ${e.toString()}';
          _isSending = false;
        });
      }
    }
  }

  Widget _buildConfirmState(BuildContext context) {
    final formattedAmount = _formattingService.formatBalance(widget.amount);
    final formattedFee = _formattingService.formatBalance(widget.fee);

    return Column(
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
                child: const SizedBox(width: 24, height: 24, child: Icon(Icons.close, color: Colors.white, size: 24)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Send icon and title
        SizedBox(
          width: 126,
          child: Column(
            children: [
              SizedBox(
                width: 51,
                height: 42,
                // decoration: BoxDecoration(color: Colors.white.useOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                child: Center(child: SvgPicture.asset('assets/send_icon_1.svg', width: 51, height: 42)),
              ),
              const SizedBox(height: 17),
              const Text(
                'SEND',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Transaction details
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Amount with token icon
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 25,
                  height: 25,
                  decoration: const ShapeDecoration(color: Color(0xFFE6E6E6), shape: OvalBorder()),
                  child: Center(child: SvgPicture.asset('assets/res_icon.svg', width: 11, height: 19)),
                ),
                const SizedBox(width: 13),
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
                          fontSize: 12,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
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
                const Text(
                  'To:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.recipientAddress,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  width: 274,
                  child: Text(
                    widget.recipientName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF16CECE),
                      fontSize: 12,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 21),

            // Reversible time information
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Reversible for:\n',
                    style: TextStyle(
                      color: Color(0xFF8AF9A8),
                      fontSize: 14,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  TextSpan(
                    text: _formatReversibleTime(),
                    style: const TextStyle(
                      color: Color(0xFF8AF9A8),
                      fontSize: 12,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Error message
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'Fira Code'),
              textAlign: TextAlign.center,
            ),
          ),

        // Network fee and confirm button
        SizedBox(
          width: 305,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Network fee',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$formattedFee ${AppConstants.tokenSymbol}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const SizedBox(width: 24, height: 24, child: Icon(Icons.settings, color: Colors.white, size: 16)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _isSending ? null : _confirmSend,
                child: Opacity(
                  opacity: _isSending ? 0.5 : 1.0,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                    child: const Text(
                      'Confirm',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF0E0E0E),
                        fontSize: 18,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProgressState(BuildContext context) {
    return Column(
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
                onTap: widget.onClose,
                child: const SizedBox(width: 24, height: 24, child: Icon(Icons.close, color: Colors.white, size: 24)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 91),
        SizedBox(
          width: 126,
          height: 178,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: SizedBox(width: 85, height: 85, child: SvgPicture.asset('assets/res_icon.svg')),
              ),
              const Positioned(
                bottom: 0,
                child: Text(
                  'SENDING',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 91),
      ],
    );
  }

  Widget _buildCompleteState(BuildContext context) {
    final formattedAmount = _formattingService.formatBalance(widget.amount);

    return Column(
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
                child: const SizedBox(width: 24, height: 24, child: Icon(Icons.close, color: Colors.white, size: 24)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Sent icon and title
        Column(
          children: [
            SizedBox(
              width: 51,
              height: 42,
              child: Center(child: SvgPicture.asset('assets/send_icon_1.svg', width: 51, height: 42)),
            ),
            const SizedBox(height: 17),
            const Text(
              'SENT',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 30, fontFamily: 'Fira Code', fontWeight: FontWeight.w300),
            ),
          ],
        ),
        const SizedBox(height: 30),

        // Transaction details
        Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Amount
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 25,
                  height: 25,
                  decoration: const ShapeDecoration(color: Color(0xFFE6E6E6), shape: OvalBorder()),
                  child: Center(child: SvgPicture.asset('assets/res_icon.svg', width: 11, height: 19)),
                ),
                const SizedBox(width: 13),
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
                          fontSize: 12,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),

            // Recipient
            Text(
              'sent to',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.useOpacity(0.5),
                fontSize: 12,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              widget.recipientName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              widget.recipientAddress,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),

            // Reversible for
            Text(
              'Reversible for: ${_formatReversibleTime()}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 16),

            // View Transaction
            GestureDetector(
              onTap: () {
                // TODO: Implement view transaction logic
              },
              child: const Text(
                'View Transaction',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF16CECE),
                  fontSize: 12,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: Color(0xFF16CECE),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 30),

        // Done Button
        GestureDetector(
          onTap: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const WalletMain()),
              (route) => false,
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            child: const Text(
              'Done',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF0E0E0E),
                fontSize: 18,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(height: 50),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    switch (_currentState) {
      case SendOverlayState.confirm:
        content = _buildConfirmState(context);
        break;
      case SendOverlayState.progress:
        content = _buildProgressState(context);
        break;
      case SendOverlayState.complete:
        content = _buildCompleteState(context);
        break;
    }

    return SafeArea(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.black.useOpacity(0.3)),
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
            decoration: ShapeDecoration(
              color: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            child: content,
          ),
        ],
      ),
    );
  }
}
