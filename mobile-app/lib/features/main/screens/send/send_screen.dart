import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/segmented_control.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/send/qr_scanner_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/send/recent_addresses.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_progress_overlay.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_providers.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_screen_logic.dart';
import 'package:resonance_network_wallet/features/main/screens/send/time_picker_sheet.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

enum SendMode { immediate, reversible }

extension SendModeExtension on SendMode {
  bool get isImmediate => this == SendMode.immediate;
  bool get isReversible => this == SendMode.reversible;
}

class SendScreen extends ConsumerStatefulWidget {
  const SendScreen({super.key});

  @override
  SendScreenState createState() => SendScreenState();
}

class SendScreenState extends ConsumerState<SendScreen> {
  bool _isInit = true;

  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  Account? activeAccount;

  BigInt _maxBalance = BigInt.zero;
  BigInt _networkFee = BigInt.zero; // Actual network fee fetched from chain
  bool _isFetchingFee = false;
  BigInt _amount = BigInt.zero;
  bool _hasAddressError = false;
  bool _hasAmountError = false;
  String _humanReadableCheckphrase = '';
  SendMode _sendMode = SendMode.reversible;
  Timer? _debounce;
  int? _blockHeight;

  // Reversible time state
  int _reversibleTimeSeconds = 600; // Default: 10 minutes

  int get _reversibleTimeDays => SendScreenLogic.getReversibleTimeComponents(_reversibleTimeSeconds).days;
  int get _reversibleTimeHours => SendScreenLogic.getReversibleTimeComponents(_reversibleTimeSeconds).hours;
  int get _reversibleTimeMinutes => SendScreenLogic.getReversibleTimeComponents(_reversibleTimeSeconds).minutes;

  String get getButtonText {
    final formattingService = ref.watch(numberFormattingServiceProvider);
    final amountStatus = SendScreenLogic.getAmountStatus(_amount, _maxBalance, _networkFee);

    return SendScreenLogic.getButtonText(
      hasAddressError: _hasAddressError,
      recipientText: _recipientController.text,
      amountStatus: amountStatus,
      amount: _amount,
      activeAccountId: activeAccount?.accountId ?? '',
      formattingService: formattingService,
    );
  }

  bool get isButtonDisabled => SendScreenLogic.isButtonDisabled(
    hasAddressError: _hasAddressError,
    amountStatus: SendScreenLogic.getAmountStatus(_amount, _maxBalance, _networkFee),
    recipientText: _recipientController.text,
    activeAccountId: activeAccount?.accountId ?? '',
    isFetchingFee: _isFetchingFee,
  );

  @override
  void initState() {
    super.initState();
    _loadReversibleTimeSetting();
    // Listen for changes in recipient and amount to update fee
    _recipientController.addListener(_debounceFetchFee);
    _amountController.addListener(_debounceFetchFee);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_isInit) {
      _loadActiveAccount();

      final String? address = ModalRoute.of(context)?.settings.arguments as String?;
      if (address != null) {
        _recipientController.text = address;
        _lookupIdentity();
      }

      // Set the flag to false so this doesn't run again
      setState(() {
        _isInit = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amountController.dispose();
    _recipientController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveAccount() async {
    final settingService = ref.read(settingsServiceProvider);
    activeAccount = await settingService.getActiveAccount();
  }

  Future<void> _loadReversibleTimeSetting() async {
    final settingService = ref.read(settingsServiceProvider);
    final savedTime = (await settingService.getReversibleTimeSeconds()) ?? AppConstants.defaultReversibleTimeSeconds;
    _setReversibleTimeSeconds(savedTime);
  }

  void _setReversibleTimeSeconds(int seconds) {
    setState(() {
      _reversibleTimeSeconds = seconds;
    });
    _toggleExistentialDeposit(isReversible);
  }

  bool get isReversible => SendScreenLogic.isReversible(_reversibleTimeSeconds);

  Future<void> _saveReversibleTimeSetting(int seconds) async {
    final settingService = ref.read(settingsServiceProvider);

    try {
      if (seconds > 0) {
        // if reversibility is off, we don't store that.
        await settingService.setReversibleTimeSeconds(seconds);
      }
      _fetchNetworkFee();
    } catch (e) {
      debugPrint('Error saving reversible time setting: $e');
    }
  }

  void _toggleExistentialDeposit(bool includeExistentialDeposit) {
    ref.read(existentialDepositToggleProvider.notifier).state = includeExistentialDeposit;
  }

  bool _isValidSS58Address(String address) {
    try {
      final substrateService = ref.read(substrateServiceProvider);
      return substrateService.isValidSS58Address(address);
    } catch (e) {
      debugPrint('Error validating address: $e');
      return false;
    }
  }

  String? _getValidRecipient() {
    final recipient = _recipientController.text.trim();
    return _isValidSS58Address(recipient) ? recipient : null;
  }

  Future<void> _lookupIdentity() async {
    if (!mounted) return;
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      if (!mounted) return;
      setState(() {
        _humanReadableCheckphrase = '';
        _hasAddressError = false;
      });
      return;
    }

    try {
      final isValid = _isValidSS58Address(recipient);
      if (!mounted) return;
      setState(() {
        _hasAddressError = !isValid;
      });

      if (isValid) {
        print('Starting wallet name lookup for: $recipient');
        final humanReadableService = ref.read(humanReadableChecksumServiceProvider);
        final humanReadableName = await humanReadableService.getHumanReadableName(recipient);
        print('Final humanReadableName: $humanReadableName');
        if (!mounted) return;
        setState(() {
          _humanReadableCheckphrase = humanReadableName;
        });
        _debounceFetchFee();
      } else {
        if (!mounted) return;
        setState(() {
          _humanReadableCheckphrase = '';
        });
      }
    } catch (e) {
      debugPrint('Error in identity lookup: $e');
      if (!mounted) return;
      setState(() {
        _humanReadableCheckphrase = '';
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

    final formattingService = ref.read(numberFormattingServiceProvider);
    final parsedAmount = formattingService.parseAmount(value);

    _setSendAmount(parsedAmount);
  }

  void _setSendAmount(BigInt? parsedAmount) {
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
        // Use the validation logic
        _hasAmountError = SendScreenLogic.hasAmountError(
          amount: _amount,
          balance: _maxBalance,
          networkFee: _networkFee,
        );
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
    if (!_isValidSS58Address(recipient) || _amount <= BigInt.zero) {
      setState(() {
        _networkFee = _networkFee;
        _isFetchingFee = false;
        _hasAmountError = SendScreenLogic.hasAmountError(
          amount: _amount,
          balance: _maxBalance,
          networkFee: _networkFee,
        );
      });
      return;
    }
    setState(() {
      _isFetchingFee = true;
    });

    try {
      ExtrinsicFeeData estimatedFee = await getNetworkFeeForAmount(recipient, _amount);

      setState(() {
        _networkFee = estimatedFee.fee;
        _blockHeight = estimatedFee.extrinsicData.blockNumber;
        _isFetchingFee = false;
        _hasAmountError = SendScreenLogic.hasAmountError(
          amount: _amount,
          balance: _maxBalance,
          networkFee: _networkFee,
        );
      });
    } catch (e) {
      print('Error fetching network fee: $e');
      setState(() {
        _isFetchingFee = false;
        _hasAmountError = SendScreenLogic.hasAmountError(
          amount: _amount,
          balance: _maxBalance,
          networkFee: BigInt.zero,
        );
      });
      if (mounted) {
        showTopSnackBar(context, title: 'Error', message: 'Error fetching network fee: ${e.toString()}');
      }
    }
  }

  Future<ExtrinsicFeeData> getNetworkFeeForAmount(String recipient, BigInt amount) async {
    ExtrinsicFeeData estimatedFee;
    if (isReversible) {
      final reversibleTransfersService = ref.read(reversibleTransfersServiceProvider);
      estimatedFee = await reversibleTransfersService.getReversibleTransferWithDelayFeeEstimate(
        account: activeAccount!,
        recipientAddress: recipient,
        amount: amount,
        delaySeconds: _reversibleTimeSeconds,
      );
    } else {
      final balanceService = ref.read(balancesServiceProvider);
      estimatedFee = await balanceService.getBalanceTransferFee(activeAccount!, recipient, amount);
    }
    return estimatedFee;
  }

  Future<void> _setMaxAmount() async {
    String? recipient = _getValidRecipient();
    if (recipient == null) {
      showTopSnackBar(context, title: 'Error', message: 'Invalid recipient address');
      return;
    }

    try {
      ExtrinsicFeeData estimatedFee = await getNetworkFeeForAmount(recipient, _maxBalance);

      // we keep track of block number so we can set it on pending transactions
      setState(() {
        _blockHeight = estimatedFee.extrinsicData.blockNumber;
      });

      final maxSendableAmount = SendScreenLogic.calculateMaxSendableAmount(
        balance: _maxBalance,
        networkFee: estimatedFee.fee,
      );

      print('max sendable amount: $maxSendableAmount');

      if (maxSendableAmount > BigInt.zero) {
        final formattingService = ref.read(numberFormattingServiceProvider);
        final formattedMax = formattingService.formatBalance(maxSendableAmount, addThousandsSeparators: false);
        _amountController.text = formattedMax;
        _setSendAmount(maxSendableAmount);
      } else {
        _amountController.text = '0';
        _setSendAmount(BigInt.zero);
      }
    } catch (e, s) {
      print('Error setting max amount: $e');
      print('Error setting max amount stack trace: $s');
      showTopSnackBar(
        // ignore: use_build_context_synchronously
        context,
        title: 'Error',
        message: 'Error setting max amount: $e',
      );
    }
  }

  void _showSendConfirmation() {
    debugPrint('Showing confirmation for amount (BigInt): $_amount');

    // Keep a reference to the overlay's state
    final GlobalKey<SendConfirmationOverlayState> overlayKey = GlobalKey<SendConfirmationOverlayState>();

    showModalBottomSheet(
      context: context,
      barrierColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width),
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black, const Color(0xFF312E6E).useOpacity(0.4), Colors.black],
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
              recipientName: _humanReadableCheckphrase,
              recipientAddress: _recipientController.text,
              fee: _networkFee,
              reversibleTimeSeconds: _sendMode.isReversible ? _reversibleTimeSeconds : 0,
              blockHeight: _blockHeight ?? 0,
              onClose: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    ).then((_) {
      // After the modal is dismissed, check its final state.
      final currentState = overlayKey.currentState?.currentState;
      if (currentState == SendOverlayState.complete || currentState == SendOverlayState.progress) {
        // If the transaction was completed, navigate home.
        overlayKey.currentState?.goHome();
      }
    });
  }

  Future<void> _scanQRCode() async {
    print('Scanning QR code');
    final scannedAddress = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen(), fullscreenDialog: true),
    );

    if (scannedAddress != null && mounted) {
      _recipientController.text = scannedAddress;
      if (mounted) {
        _lookupIdentity();
      }
    }
  }

  String _formatReversibleTime() {
    return SendScreenLogic.formatReversibleTime(_reversibleTimeSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      appBar: WalletAppBar(title: 'Send'),
      child: Consumer(
        builder: (context, ref, child) {
          final balanceAsyncValue = ref.watch(effectiveMaxBalanceProvider);
          final includeExistentialDeposit = ref.watch(existentialDepositToggleProvider);

          return balanceAsyncValue.when(
            data: (balance) {
              _maxBalance = balance;

              return _buildSendContent(context, ref, includeExistentialDeposit);
            },
            loading: () => Center(child: CircularProgressIndicator(color: context.themeColors.circularLoader)),
            error: (error, stack) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Error loading balance: $error',
                  style: context.themeText.paragraph?.copyWith(color: context.themeColors.textError),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSendContent(BuildContext context, WidgetRef ref, bool includeExistentialDeposit) {
    final formattingService = ref.read(numberFormattingServiceProvider);

    return Column(
      children: [
        Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () async {
                    final data = await Clipboard.getData('text/plain');
                    if (data != null && data.text != null) {
                      _recipientController.text = data.text!;
                      _lookupIdentity();
                    }
                  },
                  child: _buildIconButton('assets/paste_icon_1.svg'),
                ),
                const SizedBox(width: 11.5),
                GestureDetector(onTap: _scanQRCode, child: _buildIconButton('assets/scan_1.svg')),
                const SizedBox(width: 11.5),
                GestureDetector(
                  onTap: () {
                    showRecentAddresses(
                      context,
                      activeAccount: activeAccount!,
                      recipientController: _recipientController,
                      lookupIdentity: _lookupIdentity,
                    );
                  },
                  child: _buildHistoryIconButton(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: context.themeColors.surface),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.only(left: 5.0),
                    height: context.isTablet ? 42 : 38,
                    decoration: BoxDecoration(color: context.themeColors.surface),
                    child: Row(children: [Text('To:', style: context.themeText.smallParagraph)]),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomTextField(
                          leftPadding: 0,
                          controller: _recipientController,
                          textStyle: context.themeText.detail,
                          hintText:
                              '${AppConstants.tokenSymbol} '
                              'address',
                          hintStyle: context.themeText.detail?.copyWith(color: context.themeColors.textMuted),
                          onChanged: (value) {
                            if (_debounce?.isActive ?? false) {
                              _debounce?.cancel();
                            }
                            _debounce = Timer(const Duration(milliseconds: 300), () {
                              _lookupIdentity();
                            });
                          },
                        ),
                        if (_humanReadableCheckphrase.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: InkWell(
                              onTap: () async {
                                ClipboardExtensions.copyTextWithSnackbar(
                                  context,
                                  _humanReadableCheckphrase,
                                  title: 'Copied',
                                  message: 'Check phrase copied to clipboard',
                                );
                                HapticFeedback.lightImpact();
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _humanReadableCheckphrase,
                                      style: context.themeText.detail?.copyWith(color: context.themeColors.checksum),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 1.0),
                                    child: Icon(
                                      Icons.copy,
                                      size: context.themeSize.settingMenuShareIconSize,
                                      color: context.themeColors.checksum.useOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Expanded(
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                LimitedBox(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                  child: IntrinsicWidth(
                    child: TextField(
                      controller: _amountController,
                      textAlign: TextAlign.end,
                      style: context.themeText.extraLargeTitle,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        enabledBorder: _hasAmountError
                            ? OutlineInputBorder(
                                borderSide: BorderSide(color: context.themeColors.error, width: 1),
                                borderRadius: BorderRadius.circular(5),
                              )
                            : InputBorder.none,
                        focusedBorder: _hasAmountError
                            ? OutlineInputBorder(
                                borderSide: BorderSide(color: context.themeColors.error, width: 1.5),
                                borderRadius: BorderRadius.circular(5),
                              )
                            : InputBorder.none,
                        hintText: '0',
                        hintStyle: context.themeText.extraLargeTitle?.copyWith(color: context.themeColors.textMuted),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        filled: true,
                        fillColor: Colors.transparent,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [DecimalInputFilter()],
                      onChanged: _validateAmount,
                    ),
                  ),
                ),
                Text(' ${AppConstants.tokenSymbol}', style: context.themeText.smallTitle),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available: '
              // ignore: lines_longer_than_80_chars
              '${formattingService.formatBalance(_maxBalance)}',
              style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.checksum),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: ShapeDecoration(
                color: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              child: GestureDetector(
                onTap: _setMaxAmount,
                child: Text('Max', style: context.themeText.detail),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SegmentedControl<SendMode>(
          widthMode: SegmentWidthMode.custom,
          selectedValue: _sendMode,
          onSelectionChanged: (value) {
            setState(() {
              _sendMode = value;
            });
          },
          items: [
            SegmentedControlItem(
              value: SendMode.reversible,
              child: InkWell(
                onTap: _sendMode == SendMode.reversible
                    ? () {
                        showTimePickerSheet(
                          context,
                          reversibleTimeDays: _reversibleTimeDays,
                          reversibleTimeHours: _reversibleTimeHours,
                          reversibleTimeMinutes: _reversibleTimeMinutes,
                          setReversibleTimeSeconds: _setReversibleTimeSeconds,
                          saveReversibleTimeSetting: _saveReversibleTimeSetting,
                        );
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          SvgPicture.asset('assets/set_reversible.svg'),
                          Text(_formatReversibleTime(), style: context.themeText.smallParagraph),
                        ],
                      ),
                      if (_sendMode.isReversible)
                        Icon(Icons.edit, color: const Color(0x75000000), size: context.isTablet ? 22 : 14),
                    ],
                  ),
                ),
              ),
            ),
            SegmentedControlItem(
              customWidth: 76.0,
              value: SendMode.immediate,
              child: Text('Now', style: context.themeText.smallParagraph),
            ),
          ],
        ),
        const SizedBox(height: 37),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Network fee: ',
                  style: context.themeText.detail?.copyWith(
                    color: context.themeColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  formattingService.formatBalance(_networkFee, addSymbol: true),
                  style: context.themeText.detail?.copyWith(
                    color: context.themeColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isFetchingFee)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: context.themeColors.circularLoader),
                    ),
                  ),
              ],
            ),
            // _buildIconButton('assets/settings_icon.svg'),
          ],
        ),
        const SizedBox(height: 10),
        Button(
          variant: ButtonVariant.neutral,
          label: getButtonText,
          onPressed: !isButtonDisabled ? _showSendConfirmation : null,
          isDisabled: isButtonDisabled,
        ),
        SizedBox(height: context.themeSize.bottomButtonSpacing),
      ],
    );
  }

  Widget _buildIconButton(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Colors.white.useOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: SvgPicture.asset(
        assetPath,
        width: context.themeSize.mainMenuIconSize,
        height: context.themeSize.mainMenuIconSize,
      ),
    );
  }

  Widget _buildHistoryIconButton() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Colors.white.useOpacity(0.15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      child: Icon(Icons.history, color: Colors.white, size: context.themeSize.mainMenuIconSize),
    );
  }
}
