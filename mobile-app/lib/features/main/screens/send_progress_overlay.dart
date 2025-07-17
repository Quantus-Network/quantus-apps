import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart';
import 'package:url_launcher/url_launcher.dart';

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
  String? _transactionHash;

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
      final account = await _settingsService.getActiveAccount();

      // ignore: use_build_context_synchronously
      final walletStateManager = Provider.of<WalletStateManager>(
        context,
        listen: false,
      );

      debugPrint('Attempting balance transfer...');
      debugPrint('  Recipient: ${widget.recipientAddress}');
      debugPrint('  Amount (BigInt): ${widget.amount}');
      debugPrint('  Fee: ${widget.fee}');
      debugPrint('  Reversible time: ${widget.reversibleTimeSeconds}');

      if (widget.reversibleTimeSeconds <= 0) {
        await walletStateManager.balanceTransfer(
          account,
          widget.recipientAddress,
          widget.amount,
          widget.fee,
        );
      } else {
        await walletStateManager.scheduleReversibleTransferWithDelaySeconds(
          account: account,
          recipientAddress: widget.recipientAddress,
          amount: widget.amount,
          delaySeconds: widget.reversibleTimeSeconds,
          feeEstimate: widget.fee,
        );
      }

      debugPrint('Balance transfer successful.');
      RecentAddressesService().addAddress(widget.recipientAddress);

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
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
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
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/send_icon_1.svg',
                      width: 51,
                      height: 42,
                    ),
                  ),
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
                    decoration: const ShapeDecoration(
                      color: Color(0xFFE6E6E6),
                      shape: OvalBorder(),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/res_icon.svg',
                        width: 11,
                        height: 19,
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
                    AddressFormattingService.formatAddress(
                      widget.recipientAddress,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
                        fontSize: 14,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 21),

              // Reversible time information
              Container(
                width: 305,
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
                      width: 299,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Reversible for: ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(
                              text: _formatReversibleTime(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
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
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontFamily: 'Fira Code',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
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
                      spacing: 8,
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
                        SvgPicture.asset(
                          'assets/settings_icon.svg',
                          width: 14,
                          height: 13,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressState(BuildContext context) {
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
                  onTap: widget.onClose,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.close, color: Colors.white, size: 24),
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
                width: 85,
                height: 85,
                child: SvgPicture.asset('assets/res_icon.svg'),
              ),
              const Text(
                'TRANSACTION \nIN PROGRESS',
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
        ],
      ),
    );
  }

  Widget _buildCompleteState(BuildContext context) {
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
                  onTap: widget.onClose,
                  child: const SizedBox(
                    width: 24,
                    height: 24,
                    child: Icon(Icons.close, color: Colors.white, size: 24),
                  ),
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
                child: Center(
                  child: SvgPicture.asset(
                    'assets/send_icon_1.svg',
                    width: 51,
                    height: 42,
                  ),
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                'TRANSACTION INITIATED',
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
          const SizedBox(height: 28),

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
                    decoration: const ShapeDecoration(
                      color: Color(0xFFE6E6E6),
                      shape: OvalBorder(),
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        'assets/res_icon.svg',
                        width: 11,
                        height: 19,
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
              const SizedBox(height: 14),

              // Recipient information
              Text(
                'will be sent to',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.useOpacity(0.5),
                  fontSize: 12,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    AddressFormattingService.formatAddress(
                      widget.recipientAddress,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
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
                        fontSize: 14,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Reversible time information
              Container(
                width: 305,
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
                      width: 299,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(
                              text: 'Reversible for: ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            TextSpan(
                              text: _formatReversibleTime(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Explorer link
              InkWell(
                onTap: () async {
                  final Uri url = Uri.parse(
                    '${AppConstants.explorerEndpoint}/reversible-transactions${_transactionHash != null ? '/$_transactionHash' : ''}',
                  );

                  if (!await launchUrl(url)) {
                    throw Exception('Could not launch $url');
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
                    Icon(Icons.open_in_new, size: 12, color: Color(0xFF16CECE)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 46),

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
        ],
      ),
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
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.useOpacity(0.3)),
            ),
          ),
          Container(
            height:
                MediaQuery.of(context).size.height *
                AppConstants.sheetHeightFraction,
            width: MediaQuery.of(context).size.width,
            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
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
    );
  }
}
