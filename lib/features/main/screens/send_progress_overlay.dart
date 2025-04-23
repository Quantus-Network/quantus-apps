import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/core/services/number_formatting_service.dart';

enum SendOverlayState { confirm, progress, complete }

class SendConfirmationOverlay extends StatefulWidget {
  final BigInt amount;
  final String recipientName;
  final String recipientAddress;
  final VoidCallback onClose;
  final BigInt fee;

  const SendConfirmationOverlay({
    required this.amount,
    required this.recipientName,
    required this.recipientAddress,
    required this.onClose,
    required this.fee,
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

  Future<void> _confirmSend() async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
      _currentState = SendOverlayState.progress;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final senderSeed = prefs.getString('mnemonic');

      if (senderSeed == null || senderSeed.isEmpty) {
        throw Exception('Sender mnemonic not found. Please re-import your wallet.');
      }

      debugPrint('Attempting balance transfer...');
      debugPrint('  Sender Seed: ${senderSeed.substring(0, 4)}...');
      debugPrint('  Recipient: ${widget.recipientAddress}');
      debugPrint('  Amount (BigInt): ${widget.amount}');

      await SubstrateService().balanceTransfer(senderSeed, widget.recipientAddress, widget.amount);

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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: OvalBorder(),
                  ),
                  child: const Icon(Icons.close, color: Colors.black, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Container(
              width: 49,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.useOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: SvgPicture.asset(
                'assets/send_icon.svg',
                width: 24,
                height: 24,
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'SEND',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w300,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 25,
                  height: 25,
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: OvalBorder(),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/res_icon.svg',
                    ),
                  ),
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
                        text: ' RES',
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
            const SizedBox(height: 13),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'To:',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 2),
                SizedBox(
                  width: 252,
                  child: Text(
                    widget.recipientName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  widget.recipientAddress,
                  style: TextStyle(
                    color: Colors.white.useOpacity(0.6),
                    fontSize: 10,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
            child: Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 12, fontFamily: 'Fira Code'),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
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
                  Text(
                    '$formattedFee RES',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 23),
              GestureDetector(
                onTap: _isSending ? null : _confirmSend,
                child: Opacity(
                  opacity: _isSending ? 0.5 : 1.0,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
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
              const SizedBox(height: 50),
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
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: OvalBorder(),
                  ),
                  child: const Icon(Icons.close, color: Colors.black, size: 18),
                ),
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
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: SvgPicture.asset(
                    'assets/send_icon.svg',
                  ),
                ),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const ShapeDecoration(
                    color: Colors.white,
                    shape: OvalBorder(),
                  ),
                  child: const Icon(Icons.close, color: Colors.black, size: 18),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 91 - 24),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 126,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: SvgPicture.asset('assets/send_icon.svg'),
                  ),
                  const SizedBox(height: 17),
                  const SizedBox(
                    width: 126,
                    child: Text(
                      'SENT',
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
            const SizedBox(height: 46),
            SizedBox(
              width: 305,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 305,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$formattedAmount RES ',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: 'was successfully sent to ',
                            style: TextStyle(
                              color: Colors.white.useOpacity(0.5),
                              fontSize: 12,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          TextSpan(
                            text: widget.recipientName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: 305,
                    child: GestureDetector(
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
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 46),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
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
              child: Container(
                color: Colors.black.useOpacity(0.3),
              ),
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
