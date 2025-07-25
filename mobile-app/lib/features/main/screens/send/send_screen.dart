import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/base_with_background.dart';
import 'package:resonance_network_wallet/features/components/recent_address_list.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/main/screens/send/qr_scanner/qr_scanner_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_progress/send_progress_overlay.dart';

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
    final savedTime =
        (await _settingsService.getReversibleTimeSeconds()) ??
        AppConstants.defaultReversibleTimeSeconds;
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
      final account = await _settingsService.getActiveAccount();
      final balance = await SubstrateService().queryBalance(account.accountId);
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
        final humanReadableName = await HumanReadableChecksumService()
            .getHumanReadableName(recipient);
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
    // Ignore single commas or dots
    if (value == ',' || value == '.') return;

    // Haptic feedback on each character input
    HapticFeedback.lightImpact();

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
        // if we don't have fee, we will need to load it
        _isFetchingFee = !_haveNetworkFee;
        _amount = parsedAmount;
        // Simplified check; full check including fee happens after fetching fee
        _hasAmountError =
            _amount <= BigInt.zero || _amount > _maxBalance; // Basic validation
      });
      _debounceFetchFee(); // Trigger fee fetch after amount validation
    }
  }

  bool get _haveNetworkFee => _networkFee > BigInt.zero;

  void _debounceFetchFee() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () {
      _fetchNetworkFee();
    });
  }

  Future<void> _fetchNetworkFee() async {
    final recipient = _recipientController.text.trim();
    if (!_isValidSS58Address(recipient) ||
        _amount <= BigInt.zero ||
        (_haveNetworkFee)) {
      setState(() {
        _networkFee = _networkFee;
        _isFetchingFee = false;
        _hasAmountError =
            _amount > BigInt.zero && (_amount + _networkFee) > _maxBalance;
      });
      return;
    }
    setState(() {
      _isFetchingFee = true;
    });

    try {
      final account = await _settingsService.getActiveAccount();
      final dummyAmountForFee =
          BigInt.from(1) *
          NumberFormattingService.scaleFactorBigInt; // Use a minimal amount
      final estimatedFee = await SubstrateService().getFee(
        account.accountId,
        recipient,
        dummyAmountForFee,
      );

      setState(() {
        _networkFee = estimatedFee;
        _isFetchingFee = false;
        _hasAmountError = (_amount + _networkFee) > _maxBalance;
      });
    } catch (e) {
      print('Error fetching network fee: $e');
      setState(() {
        _isFetchingFee = false;
        _hasAmountError = _amount <= BigInt.zero || _amount > _maxBalance;
      });
      if (mounted) {
        showTopSnackBar(
          context,
          title: 'Error',
          message: 'Error fetching network fee: ${e.toString()}',
        );
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

    // Keep a reference to the overlay's state
    final GlobalKey<SendConfirmationOverlayState> overlayKey =
        GlobalKey<SendConfirmationOverlayState>();

    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    const Color(0xFF312E6E).useOpacity(0.4),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SendConfirmationOverlay(
              key: overlayKey,
              amount: _amount,
              recipientName: _savedAddressesLabel,
              recipientAddress: _recipientController.text,
              fee: _networkFee,
              reversibleTimeSeconds: _reversibleTimeSeconds,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ).then((_) {
      // After the modal is dismissed, check its final state.
      final currentState = overlayKey.currentState?.currentState;
      if (currentState == SendOverlayState.complete ||
          currentState == SendOverlayState.progress) {
        // If the transaction was completed, navigate home.
        overlayKey.currentState?.goHome();
      }
    });
  }

  Future<void> _scanQRCode() async {
    print('Scanning QR code');
    final scannedAddress = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const QRScannerScreen(),
        fullscreenDialog: true,
      ),
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
      return '$days day${days > 1 ? 's' : ''}, '
          '$hours hr${hours != 1 ? 's' : ''}, '
          '$minutes min${minutes != 1 ? 's' : ''}';
    } else if (hours > 0) {
      return '$hours hr${hours != 1 ? 's' : ''}, '
          '$minutes min${minutes != 1 ? 's' : ''}';
    } else {
      return '$minutes min${minutes != 1 ? 's' : ''}';
    }
  }

  void _showTimePickerModal() {
    // Set initial values from current state
    var selectedDays = _reversibleTimeDays;
    var selectedHours = _reversibleTimeHours;
    var selectedMinutes = _reversibleTimeMinutes;

    showAppModalBottomSheet(
      context: context,
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

            // Time pickers
            Expanded(
              child: Row(
                children: [
                  // Days
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Days',
                          style: TextStyle(
                            color: Color(0xFFD9D9D9),
                            fontSize: 16,
                            fontFamily: 'Fira Code',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                    initialItem: selectedDays,
                                  ),
                                  itemExtent: 40,
                                  onSelectedItemChanged: (index) =>
                                      selectedDays = index,
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
                              const Text(
                                ':',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Hours
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Hours',
                          style: TextStyle(
                            color: Color(0xFFD9D9D9),
                            fontSize: 16,
                            fontFamily: 'Fira Code',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(
                                child: CupertinoPicker(
                                  scrollController: FixedExtentScrollController(
                                    initialItem: selectedHours,
                                  ),
                                  itemExtent: 40,
                                  onSelectedItemChanged: (index) =>
                                      selectedHours = index,
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
                              const Text(
                                ':',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Minutes
                  Expanded(
                    child: Column(
                      children: [
                        const Text(
                          'Minutes',
                          style: TextStyle(
                            color: Color(0xFFD9D9D9),
                            fontSize: 16,
                            fontFamily: 'Fira Code',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: CupertinoPicker(
                            scrollController: FixedExtentScrollController(
                              initialItem: selectedMinutes,
                            ),
                            itemExtent: 40,
                            onSelectedItemChanged: (index) =>
                                selectedMinutes = index,
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
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
                      final newTimeSeconds =
                          (selectedDays * 86400) +
                          (selectedHours * 3600) +
                          (selectedMinutes * 60);
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
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
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

  // NEW: Method to show the recent addresses modal bottom sheet
  void _showRecentAddresses() {
    showAppModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height:
            MediaQuery.of(context).size.height *
            0.8, // Adjustable height for scrollability
        padding: const EdgeInsets.fromLTRB(35, 16, 35, 16),
        decoration: const ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20),
            ), // Softer radius for modal
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top row with close button (replacing empty stack in Figma)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ],
            ),
            const SizedBox(height: 26), // Spacing from Figma
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(
                    width: 226,
                    child: Text(
                      'Recently Used',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20), // Spacing from Figma
                  Expanded(
                    child: RecentAddressList(
                      onAddressSelected: (address) {
                        _recipientController.text = address;
                        _lookupIdentity();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseWithBackground(
      child: FutureBuilder<BigInt>(
        future: _balanceFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 4),
                        Text(
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
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final data = await Clipboard.getData(
                                'text/plain',
                              );
                              if (data != null && data.text != null) {
                                _recipientController.text = data.text!;
                                _lookupIdentity();
                              }
                            },
                            child: _buildIconButton('assets/paste_icon_1.svg'),
                          ),
                          const SizedBox(width: 9),
                          GestureDetector(
                            onTap: _scanQRCode,
                            child: _buildIconButton('assets/scan_1.svg'),
                          ),
                          const SizedBox(width: 9),
                          GestureDetector(
                            onTap: _showRecentAddresses,
                            child: _buildHistoryIconButton(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
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
                                            borderSide: BorderSide(
                                              color: Colors.red,
                                              width: 1,
                                            ),
                                          )
                                        : InputBorder.none,
                                    focusedBorder: _hasAddressError
                                        ? const OutlineInputBorder(
                                            borderSide: BorderSide(
                                              color: Colors.red,
                                              width: 1,
                                            ),
                                          )
                                        : InputBorder.none,
                                    hintText:
                                        '${AppConstants.tokenSymbol} '
                                        'address',
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
                                    if (_debounce?.isActive ?? false) {
                                      _debounce?.cancel();
                                    }
                                    _debounce = Timer(
                                      const Duration(milliseconds: 300),
                                      () {
                                        _lookupIdentity();
                                      },
                                    );
                                  },
                                ),
                                if (_savedAddressesLabel.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      _savedAddressesLabel,
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
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        LimitedBox(
                          maxWidth: MediaQuery.of(context).size.width * 0.8,
                          child: IntrinsicWidth(
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
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(5),
                                      )
                                    : InputBorder.none,
                                focusedBorder: _hasAmountError
                                    ? OutlineInputBorder(
                                        borderSide: const BorderSide(
                                          color: Colors.red,
                                          width: 1.5,
                                        ),
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
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [DecimalInputFilter()],
                              onChanged: _validateAmount,
                            ),
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
                        'Available: '
                        // ignore: lines_longer_than_80_chars
                        '${_formattingService.formatBalance(_maxBalance)}',
                        style: const TextStyle(
                          color: Color(0xFF16CECE),
                          fontSize: 14,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
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
                  child: GestureDetector(
                    onTap: _showTimePickerModal,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: ShapeDecoration(
                        color: const Color(0xFF313131),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
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
                          const Icon(
                            Icons.edit,
                            color: Colors.white70,
                            size: 14,
                          ),
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
                                // ignore: lines_longer_than_80_chars
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
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white70,
                                    ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: Text(
                          (_hasAddressError ||
                                  _recipientController.text.isEmpty)
                              ? 'Enter Address'
                              : (_amount <= BigInt.zero)
                              ? 'Enter Amount'
                              : _hasAmountError
                              ? 'Insufficient Balance'
                              // ignore: lines_longer_than_80_chars
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
    );
  }

  static const iconSize = 21.0; // + 4 inset = 25 size
  Widget _buildIconButton(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Colors.white.useOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: SvgPicture.asset(assetPath, width: iconSize, height: iconSize),
    );
  }

  Widget _buildHistoryIconButton() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Colors.white.useOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: const Icon(Icons.history, color: Colors.white, size: iconSize),
    );
  }
}
