import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/core/services/human_readable_checksum_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:ui';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';

String formatAmount(BigInt amount) {
  return amount.toString();
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  SendScreenState createState() => SendScreenState();
}

class SendScreenState extends State<SendScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  BigInt _maxBalance = BigInt.from(0);
  BigInt _fee = BigInt.from(10); // TODO: get from SubstrateService
  bool _hasAddressError = false;
  bool _hasAmountError = false;
  BigInt _amount = BigInt.from(0);
  String _savedAddressesLabel = '';
  Timer? _debounce;
  static const int _networkFee = 10;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    super.dispose();
  }

  bool _isValidSS58Address(String address) {
    try {
      // Use SubstrateService to validate the address
      return SubstrateService().isValidSS58Address(address);
    } catch (e) {
      debugPrint('Error validating address: $e');
      return false;
    }
  }

  Future<void> _loadBalance() async {
    setState(() {});

    try {
      // Dev mode: Set fixed balance of 1000
      // setState(() {
      //   _maxBalance = BigInt.from(1000);
      // });

      // Comment out the actual balance loading for now

      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getString('account_id');

      if (accountId == null) {
        throw Exception('Wallet not found');
      }

      final balance = await SubstrateService().queryBalance(accountId);

      setState(() {
        _maxBalance = balance;
      });
    } catch (e) {
      debugPrint('Error loading balance: $e');
      setState(() {});
    }
  }

  Future<void> _lookupIdentity() async {
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      setState(() {
        _savedAddressesLabel = '';
      });
      return;
    }

    try {
      final isValid = _isValidSS58Address(recipient);
      setState(() {
        _hasAddressError = !isValid;
      });

      if (isValid) {
        final stopwatch = Stopwatch()..start();
        debugPrint('Starting wallet name lookup for: $recipient');
        final humanReadableName = await HumanReadableChecksumService().getHumanReadableName(recipient);
        stopwatch.stop();
        debugPrint('Wallet name lookup took: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('Final humanReadableName: $humanReadableName');
        setState(() {
          _savedAddressesLabel = humanReadableName;
        });
      } else {
        setState(() {
          _savedAddressesLabel = '';
        });
      }
    } catch (e) {
      debugPrint('Error in identity lookup: $e');
      setState(() {
        _savedAddressesLabel = '';
      });
    }
  }

  void _validateAmount(String value) {
    if (value.isEmpty) {
      setState(() {
        _hasAmountError = false;
      });
      return;
    }

    try {
      final amount = BigInt.parse(value);
      setState(() {
        _hasAmountError = amount + _fee > _maxBalance;
        _amount = amount;
      });
    } catch (e) {
      setState(() {
        _hasAmountError = true;
      });
    }
  }

  void _setMaxAmount() {
    final maxAmount = _maxBalance - BigInt.from(_networkFee);
    if (maxAmount > BigInt.zero) {
      _amountController.text = maxAmount.toString();
      _validateAmount(maxAmount.toString());
    }
  }

  void _showSendConfirmation() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SendConfirmationOverlay(
        amount: _amount.toString(),
        recipientName: _savedAddressesLabel,
        recipientAddress: _recipientController.text,
        fee: _fee,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0E0E),
        body: Stack(
          children: [
            // Background image with opacity
            Positioned.fill(
              child: Opacity(
                opacity: 0.54,
                child: Image.asset(
                  'assets/light-leak-effect-black-background 2.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Main content
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Recipient input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
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
                              Container(
                                width: 1,
                                height: 17,
                                color: Colors.white,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _recipientController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontFamily: 'Fira Code',
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: _hasAddressError
                                        ? OutlineInputBorder(
                                            borderSide: const BorderSide(color: Colors.red, width: 1),
                                          )
                                        : InputBorder.none,
                                    focusedBorder: _hasAddressError
                                        ? OutlineInputBorder(
                                            borderSide: const BorderSide(color: Colors.red, width: 1),
                                          )
                                        : InputBorder.none,
                                    hintText: 'RES Name or address',
                                    hintStyle: TextStyle(
                                      color: Colors.white.useOpacity(0.3),
                                      fontSize: 14,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: 0.5,
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    filled: true,
                                    fillColor: Colors.transparent,
                                  ),
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  enableInteractiveSelection: true,
                                  keyboardType: TextInputType.text,
                                  textCapitalization: TextCapitalization.none,
                                  onChanged: (value) {
                                    setState(() {
                                      _hasAddressError = false;
                                    });

                                    if (_debounce?.isActive ?? false) _debounce?.cancel();
                                    _debounce = Timer(const Duration(milliseconds: 300), () {
                                      _lookupIdentity();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildIconButton('assets/scan.svg'),
                            const SizedBox(width: 9),
                            GestureDetector(
                              onTap: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data != null && data.text != null) {
                                  _recipientController.text = data.text!;
                                  _lookupIdentity();
                                }
                              },
                              child: _buildIconButton('assets/Paste_icon.svg'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Saved addresses
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      _savedAddressesLabel,
                      style: TextStyle(
                        color: Colors.white.useOpacity(0.8),
                        fontSize: 13,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                // Amount input
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IntrinsicWidth(
                          child: TextField(
                            controller: _amountController,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 40,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              enabledBorder: _hasAmountError
                                  ? OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.red, width: 1),
                                    )
                                  : InputBorder.none,
                              focusedBorder: _hasAmountError
                                  ? OutlineInputBorder(
                                      borderSide: const BorderSide(color: Colors.red, width: 1),
                                    )
                                  : InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: Colors.white.useOpacity(0.5),
                                fontSize: 40,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w600,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: Colors.transparent,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            ],
                            onChanged: _validateAmount,
                          ),
                        ),
                        const Text(
                          ' RES',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Available balance and max button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available: ${SubstrateService().formatBalance(_maxBalance)}',
                        style: const TextStyle(
                          color: Color(0xFF16CECE),
                          fontSize: 14,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: ShapeDecoration(
                          color: Colors.white.useOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: GestureDetector(
                          onTap: _setMaxAmount,
                          child: const Text(
                            'Max',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Network fee
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Network fee',
                            style: TextStyle(
                              color: Colors.white.useOpacity(0.6),
                              fontSize: 12,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '$_networkFee RES',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      _buildIconButton('assets/settings_icon.svg'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Send button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: (_hasAddressError ||
                            _hasAmountError ||
                            _recipientController.text.isEmpty ||
                            _amountController.text.isEmpty ||
                            _amountController.text == '0' ||
                            _amount == BigInt.from(0))
                        ? null
                        : _showSendConfirmation,
                    child: Opacity(
                      opacity: _hasAddressError ||
                              _hasAmountError ||
                              _recipientController.text.isEmpty ||
                              _amountController.text.isEmpty ||
                              _amountController.text == '0' ||
                              _amount == BigInt.from(0)
                          ? 0.3
                          : 1.0,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: ShapeDecoration(
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: Text(
                          (_hasAddressError || _recipientController.text.isEmpty)
                              ? 'Enter Address'
                              : (_hasAmountError ||
                                      _amountController.text.isEmpty ||
                                      _amountController.text == '0' ||
                                      _amount == BigInt.from(0))
                                  ? 'Enter Amount'
                                  : 'Send ${formatAmount(_amount)} RES',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF0E0E0E),
                            fontSize: 18,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Colors.white.useOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: SvgPicture.asset(
        assetPath,
        width: 17,
        height: 17,
      ),
    );
  }
}

enum SendOverlayState { confirm, progress, complete }

class SendConfirmationOverlay extends StatefulWidget {
  final String amount;
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
  _SendConfirmationOverlayState createState() => _SendConfirmationOverlayState();
}

class _SendConfirmationOverlayState extends State<SendConfirmationOverlay> {
  SendOverlayState _currentState = SendOverlayState.confirm;

  void _confirmSend() {
    setState(() {
      _currentState = SendOverlayState.progress;
    });
    // TODO: Implement actual send transaction logic here
    // After transaction completes (or fails), update state to complete
    // For now, simulate a delay and move to complete
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _currentState = SendOverlayState.complete;
        });
      }
    });
  }

  Widget _buildConfirmState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
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
        // SEND title
        Row(
          children: [
            Container(
              width: 49,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
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
        // Amount and recipient info
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
                      'assets/RES icon.svg',
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: widget.amount,
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
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 10,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),
        // Network fee and confirm button
        Container(
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
                    '${widget.fee.toString()} RES',
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
                onTap: _confirmSend,
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
        // Close button (optional, maybe disable closing during progress?)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: widget.onClose, // Or null if closing not allowed
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
        Container(
          width: 126,
          height: 178,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 0,
                child: SizedBox(
                  width: 80, // Adjusted size for the icon
                  height: 80,
                  child: SvgPicture.asset(
                    'assets/send_icon.svg',
                    // Consider adding animation or progress indicator here
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
        const SizedBox(height: 91), // Adjust spacing as needed
      ],
    );
  }

  Widget _buildCompleteState(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Close button (optional, can keep or remove for complete state)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: widget.onClose, // Close button still just closes the modal
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
        const SizedBox(height: 91 - 24), // Adjust top spacing
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 126,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 80, // Match progress icon size
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
            Container(
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
                            text: '${widget.amount} RES ',
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
                              color: Colors.white.withOpacity(0.5), // Adjusted opacity
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
                          color: Color(0xFF16CECE), // other-blue
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
        const SizedBox(height: 46), // Spacing before Done button
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
        const SizedBox(height: 50), // Match bottom spacing from confirm state
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
        alignment: Alignment.center, // Center content for progress/complete
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.3),
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
