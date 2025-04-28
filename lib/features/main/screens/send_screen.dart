import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/core/constants/app_constants.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/core/services/human_readable_checksum_service.dart';
import 'package:resonance_network_wallet/features/main/screens/send_progress_overlay.dart';
import 'package:resonance_network_wallet/features/main/screens/qr_scanner_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:resonance_network_wallet/core/services/number_formatting_service.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  SendScreenState createState() => SendScreenState();
}

class SendScreenState extends State<SendScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final NumberFormattingService _formattingService = NumberFormattingService();
  BigInt _maxBalance = BigInt.zero;
  static final BigInt _networkFee = BigInt.from(10) * NumberFormattingService.scaleFactorBigInt;
  BigInt _amount = BigInt.zero;
  bool _hasAddressError = false;
  bool _hasAmountError = false;
  String _savedAddressesLabel = '';
  Timer? _debounce;

  late Future<BigInt> _balanceFuture;

  @override
  void initState() {
    super.initState();
    _balanceFuture = _loadBalance();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  bool _isValidSS58Address(String address) {
    try {
      return SubstrateService().isValidSS58Address(address);
    } catch (e) {
      debugPrint('Error validating address: $e');
      return false;
    }
  }

  Future<BigInt> _loadBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getString('account_id');

      if (accountId == null) {
        throw Exception('Wallet not found');
      }

      final balance = await SubstrateService().queryBalance(accountId);
      return balance;
    } catch (e) {
      debugPrint('Error loading balance: $e');
      rethrow;
    }
  }

  Future<void> _lookupIdentity() async {
    print("lookupIdentity");
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      setState(() {
        _savedAddressesLabel = '';
        _hasAddressError = false;
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
        print('Starting wallet name lookup for: $recipient');
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
        _hasAddressError = true;
      });
    }
  }

  void _validateAmount(String value) {
    if (value.isEmpty) {
      setState(() {
        _amount = BigInt.zero;
        _hasAmountError = false;
      });
      return;
    }

    final parsedAmount = _formattingService.parseAmount(value);

    if (parsedAmount == null) {
      setState(() {
        _amount = BigInt.zero;
        _hasAmountError = true;
      });
    } else {
      setState(() {
        _amount = parsedAmount;
        _hasAmountError = _amount <= BigInt.zero || (_amount + _networkFee) > _maxBalance;
      });
    }
  }

  void _setMaxAmount() {
    final maxSendableAmount = _maxBalance - _networkFee;
    if (maxSendableAmount > BigInt.zero) {
      final formattedMax = _formattingService.formatBalance(maxSendableAmount);
      _amountController.text = formattedMax;
      _validateAmount(formattedMax);
    } else {
      _amountController.text = '0';
      _validateAmount('0');
    }
  }

  void _showSendConfirmation() {
    debugPrint('Showing confirmation for amount (BigInt): $_amount');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SendConfirmationOverlay(
        amount: _amount,
        recipientName: _savedAddressesLabel,
        recipientAddress: _recipientController.text,
        fee: _networkFee,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _scanQRCode() async {
    final scannedAddress = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
        fullscreenDialog: true,
      ),
    );

    if (scannedAddress != null && mounted) {
      setState(() {
        _recipientController.text = scannedAddress;
        _lookupIdentity(); // Trigger address validation and name lookup
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.54,
              child: Image.asset(
                'assets/light_leak_effect_background.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: FutureBuilder<BigInt>(
              future: _balanceFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Text(
                        'Error loading balance: ${snapshot.error}',
                        style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                if (snapshot.hasData) {
                  _maxBalance = snapshot.data!;

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Icon(
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
                                              ? const OutlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.red, width: 1),
                                                )
                                              : InputBorder.none,
                                          focusedBorder: _hasAddressError
                                              ? const OutlineInputBorder(
                                                  borderSide: BorderSide(color: Colors.red, width: 1),
                                                )
                                              : InputBorder.none,
                                          hintText: '${AppConstants.tokenSymbol} address',
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
                                  GestureDetector(
                                    onTap: _scanQRCode,
                                    child: _buildIconButton('assets/scan.svg'),
                                  ),
                                  const SizedBox(width: 9),
                                  GestureDetector(
                                    onTap: () async {
                                      final data = await Clipboard.getData('text/plain');
                                      if (data != null && data.text != null) {
                                        _recipientController.text = data.text!;
                                        _lookupIdentity();
                                      }
                                    },
                                    child: _buildIconButton('assets/paste_icon.svg'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
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
                                            borderRadius: BorderRadius.circular(5),
                                          )
                                        : InputBorder.none,
                                    focusedBorder: _hasAmountError
                                        ? OutlineInputBorder(
                                            borderSide: const BorderSide(color: Colors.red, width: 1.5),
                                            borderRadius: BorderRadius.circular(5),
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
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                  ],
                                  onChanged: _validateAmount,
                                ),
                              ),
                              const Text(
                                ' ${AppConstants.tokenSymbol}',
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Available: ${_formattingService.formatBalance(_maxBalance)}',
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
                                  '${_formattingService.formatBalance(_networkFee)} ${AppConstants.tokenSymbol}',
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GestureDetector(
                          onTap: (_hasAddressError ||
                                  _hasAmountError ||
                                  _recipientController.text.isEmpty ||
                                  _amount <= BigInt.zero)
                              ? null
                              : _showSendConfirmation,
                          child: Opacity(
                            opacity: (_hasAddressError ||
                                    _hasAmountError ||
                                    _recipientController.text.isEmpty ||
                                    _amount <= BigInt.zero)
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
                                    : (_hasAmountError || _amount <= BigInt.zero)
                                        ? 'Enter Amount'
                                        : 'Send ${_formattingService.formatBalance(_amount)} ${AppConstants.tokenSymbol}',
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
                  );
                }

                return const SizedBox();
              },
            ),
          ),
        ],
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
