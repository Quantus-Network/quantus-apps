import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/main/screens/send_progress_overlay.dart';
import 'package:resonance_network_wallet/features/main/screens/qr_scanner_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  SendScreenState createState() => SendScreenState();
}

class SendScreenState extends State<SendScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final NumberFormattingService _formattingService = NumberFormattingService();
  final SettingsService _settingsService = SettingsService();
  BigInt _maxBalance = BigInt.zero;
  BigInt _networkFee = BigInt.zero; // Actual network fee fetched from chain
  bool _isFetchingFee = false;
  BigInt _amount = BigInt.zero;
  bool _hasAddressError = false;
  bool _hasAmountError = false;
  String _savedAddressesLabel = '';
  Timer? _debounce;

  // Reversible time state
  int _reversibleTimeSeconds = 600; // Default: 10 minutes

  late Future<BigInt> _balanceFuture;

  @override
  void initState() {
    super.initState();
    _balanceFuture = _loadBalance();
    _loadReversibleTimeSetting();
    // Listen for changes in recipient and amount to update fee
    _recipientController.addListener(_debounceFetchFee);
    _amountController.addListener(_debounceFetchFee);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _loadReversibleTimeSetting() async {
    final savedTime = (await _settingsService.getReversibleTimeSeconds()) ?? AppConstants.defaultReversibleTimeSeconds;
    setState(() {
      _reversibleTimeSeconds = savedTime;
    });
  }

  Future<void> _saveReversibleTimeSetting(int seconds) async {
    try {
      await _settingsService.setReversibleTimeSeconds(seconds);
    } catch (e) {
      debugPrint('Error saving reversible time setting: $e');
    }
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
      final accountId = await _settingsService.getAccountId();

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
    if (!mounted) return; // Add early return if not mounted
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      if (!mounted) return; // Check mounted before setState
      setState(() {
        _savedAddressesLabel = '';
        _hasAddressError = false;
      });
      return;
    }

    try {
      final isValid = _isValidSS58Address(recipient);
      if (!mounted) return; // Check mounted before setState
      setState(() {
        _hasAddressError = !isValid;
      });

      if (isValid) {
        print('Starting wallet name lookup for: $recipient');
        final humanReadableName = await HumanReadableChecksumService().getHumanReadableName(recipient);
        print('Final humanReadableName: $humanReadableName');
        if (!mounted) return; // Check mounted before setState
        setState(() {
          _savedAddressesLabel = humanReadableName;
        });
        _debounceFetchFee();
      } else {
        if (!mounted) return; // Check mounted before setState
        setState(() {
          _savedAddressesLabel = '';
        });
      }
    } catch (e) {
      debugPrint('Error in identity lookup: $e');
      if (!mounted) return; // Check mounted before setState
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
        _networkFee = BigInt.zero;
      });
      return;
    }

    final parsedAmount = _formattingService.parseAmount(value);

    if (parsedAmount == null) {
      setState(() {
        _amount = BigInt.zero;
        _hasAmountError = true;
        _networkFee = BigInt.zero;
      });
    } else {
      setState(() {
        _amount = parsedAmount;
        // Simplified check; full check including fee happens after fetching fee
        _hasAmountError = _amount <= BigInt.zero || _amount > _maxBalance; // Basic validation
      });
      _debounceFetchFee(); // Trigger fee fetch after amount validation
    }
  }

  void _debounceFetchFee() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchNetworkFee();
    });
  }

  Future<void> _fetchNetworkFee() async {
    final recipient = _recipientController.text.trim();
    if (!_isValidSS58Address(recipient) || _amount <= BigInt.zero || (_networkFee > BigInt.zero)) {
      setState(() {
        _networkFee = _networkFee;
        _isFetchingFee = false;
        _hasAmountError = _amount > BigInt.zero && (_amount + _networkFee) > _maxBalance;
      });
      return;
    }

    try {
      final senderAccountId = await _settingsService.getAccountId();
      if (senderAccountId == null) {
        throw Exception('Sender account not found');
      }
      final dummyAmountForFee = BigInt.from(1) * NumberFormattingService.scaleFactorBigInt; // Use a minimal amount
      final estimatedFee = await SubstrateService().getFee(senderAccountId, recipient, dummyAmountForFee);

      setState(() {
        _networkFee = estimatedFee;
        _isFetchingFee = false;
        _hasAmountError = (_amount + _networkFee) > _maxBalance;
      });
    } catch (e) {
      debugPrint('Error fetching network fee: $e');
      setState(() {
        _networkFee = BigInt.zero;
        _isFetchingFee = false;
        _hasAmountError = _amount <= BigInt.zero || _amount > _maxBalance;
      });
      if (mounted) {
        showTopSnackBar(context, title: 'Error', message: 'Error fetching network fee: ${e.toString()}');
      }
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
        reversibleTimeSeconds: _reversibleTimeSeconds,
        onClose: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _scanQRCode() async {
    print('Scanning QR code');
    final scannedAddress = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen(), fullscreenDialog: true),
    );

    if (scannedAddress != null && mounted) {
      _recipientController.text = scannedAddress;
      // Add a small delay to ensure the text controller has updated
      // await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _lookupIdentity();
      }
    }
  }

  int get _reversibleTimeDays => _reversibleTimeSeconds ~/ 86400;
  int get _reversibleTimeHours => (_reversibleTimeSeconds % 86400) ~/ 3600;
  int get _reversibleTimeMinutes => (_reversibleTimeSeconds % 3600) ~/ 60;

  String _formatReversibleTime() {
    final days = _reversibleTimeDays;
    final hours = _reversibleTimeHours;
    final minutes = _reversibleTimeMinutes;

    if (days > 0) {
      return '$days day${days > 1 ? 's' : ''}, $hours hr${hours != 1 ? 's' : ''}, $minutes min${minutes != 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '$hours hr${hours != 1 ? 's' : ''}, $minutes min${minutes != 1 ? 's' : ''}';
    } else {
      return '$minutes min${minutes != 1 ? 's' : ''}';
    }
  }

  void _showTimePickerModal() {
    // Set initial values from current state
    var selectedDays = _reversibleTimeDays;
    var selectedHours = _reversibleTimeHours;
    var selectedMinutes = _reversibleTimeMinutes;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 632,
        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 60),
        decoration: const BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            const Column(
              children: [
                Icon(Icons.schedule, color: Color(0xFF16CECE), size: 29),
                SizedBox(height: 16),
                Text(
                  'Set Reverse Window',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF16CECE),
                    fontSize: 18,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your transaction is reversible during this time period',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),

            // Time picker labels
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    'Days',
                    style: TextStyle(color: Color(0xFFD9D9D9), fontSize: 16, fontFamily: 'Fira Code'),
                  ),
                  Text(
                    'Hours',
                    style: TextStyle(color: Color(0xFFD9D9D9), fontSize: 16, fontFamily: 'Fira Code'),
                  ),
                  Text(
                    'Minutes',
                    style: TextStyle(color: Color(0xFFD9D9D9), fontSize: 16, fontFamily: 'Fira Code'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Time pickers
            Expanded(
              child: Row(
                children: [
                  // Days picker
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: selectedDays),
                      itemExtent: 40,
                      onSelectedItemChanged: (index) => selectedDays = index,
                      children: List.generate(
                        8,
                        (index) => Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Text(':', style: TextStyle(color: Colors.white, fontSize: 20)),
                  // Hours picker
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: selectedHours),
                      itemExtent: 40,
                      onSelectedItemChanged: (index) => selectedHours = index,
                      children: List.generate(
                        24,
                        (index) => Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Text(':', style: TextStyle(color: Colors.white, fontSize: 20)),
                  // Minutes picker
                  Expanded(
                    child: CupertinoPicker(
                      scrollController: FixedExtentScrollController(initialItem: selectedMinutes),
                      itemExtent: 40,
                      onSelectedItemChanged: (index) => selectedMinutes = index,
                      children: List.generate(
                        60,
                        (index) => Center(
                          child: Text(
                            index.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: ShapeDecoration(
                        color: const Color(0xFFFF2D53),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text(
                        'Cancel',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      final newTimeSeconds = (selectedDays * 86400) + (selectedHours * 3600) + (selectedMinutes * 60);
                      setState(() {
                        _reversibleTimeSeconds = newTimeSeconds;
                      });
                      _saveReversibleTimeSetting(newTimeSeconds);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: ShapeDecoration(
                        color: const Color(0xFF5FE49E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      child: const Text(
                        'Set',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 14,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
              child: Image.asset('assets/light_leak_effect_background.jpg', fit: BoxFit.cover),
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
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Row(
                            children: [
                              Icon(Icons.arrow_back, color: Colors.white, size: 24),
                              SizedBox(width: 4),
                              Text(
                                'Send',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
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
                                  GestureDetector(onTap: _scanQRCode, child: _buildIconButton('assets/scan.svg')),
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
                                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                        child: GestureDetector(
                          onTap: _showTimePickerModal,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: ShapeDecoration(
                              color: const Color(0xFF313131),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  'Reversible for: ${_formatReversibleTime()}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontFamily: 'Fira Code',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const Icon(Icons.edit, color: Colors.white70, size: 14),
                              ],
                            ),
                          ),
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
                                Row(
                                  children: [
                                    Text(
                                      '${_formattingService.formatBalance(_networkFee)} ${AppConstants.tokenSymbol}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontFamily: 'Fira Code',
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_isFetchingFee)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8.0),
                                        child: SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                                        ),
                                      ),
                                  ],
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
                          onTap:
                              (_hasAddressError ||
                                  _hasAmountError ||
                                  _recipientController.text.isEmpty ||
                                  _amount <= BigInt.zero ||
                                  _isFetchingFee)
                              ? null
                              : _showSendConfirmation,
                          child: Opacity(
                            opacity:
                                (_hasAddressError ||
                                    _hasAmountError ||
                                    _recipientController.text.isEmpty ||
                                    _amount <= BigInt.zero ||
                                    _isFetchingFee)
                                ? 0.3
                                : 1.0,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: ShapeDecoration(
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              ),
                              child: Text(
                                (_hasAddressError || _recipientController.text.isEmpty)
                                    ? 'Enter Address'
                                    : (_amount <= BigInt.zero)
                                    ? 'Enter Amount'
                                    : _hasAmountError
                                    ? 'Insufficient Balance'
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: SvgPicture.asset(assetPath, width: 17, height: 17),
    );
  }
}
