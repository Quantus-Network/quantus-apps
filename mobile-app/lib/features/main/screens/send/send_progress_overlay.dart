import 'dart:ui';

import 'package:convert/convert.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/generated/schrodinger/types/qp_scheduler/block_number_or_timestamp.dart' as qp;
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/pending_transactions_provider.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

enum SendOverlayState { confirm, progress, complete, hardwareSign, hardwareScan }

String encodePayloadAsUr(List<int> payload) {
  final urParts = encodeUr(data: payload);
  if (urParts.isEmpty) {
    throw Exception('Failed to encode UR: empty result');
  }
  return urParts.first;
}

class SendConfirmationOverlay extends ConsumerStatefulWidget {
  final BigInt amount;
  final String recipientName;
  final String recipientAddress;
  final VoidCallback onClose;
  final BigInt fee;
  final int reversibleTimeSeconds;
  final int blockHeight;
  final bool isHighSecurity;

  const SendConfirmationOverlay({
    required this.amount,
    required this.recipientName,
    required this.recipientAddress,
    required this.onClose,
    required this.fee,
    required this.reversibleTimeSeconds,
    required this.blockHeight,
    this.isHighSecurity = false,
    super.key,
  });

  @override
  SendConfirmationOverlayState createState() => SendConfirmationOverlayState();
}

class SendConfirmationOverlayState extends ConsumerState<SendConfirmationOverlay> {
  SendOverlayState currentState = SendOverlayState.confirm;
  String? _errorMessage;
  bool _isSending = false;
  Account? _hardwareAccount;
  UnsignedTransactionData? _hardwareUnsignedData;
  bool _isHardwareSubmitting = false;
  final MobileScannerController _signatureScannerController = MobileScannerController();
  bool _hasScannedSignature = false;
  final Set<String> _collectedUrParts = {};

  int? _getTotalFragmentCount() {
    if (_collectedUrParts.isEmpty) return null;

    for (final part in _collectedUrParts) {
      final match = RegExp(r'/(\d+)-(\d+)/').firstMatch(part);
      if (match != null) {
        final total = int.tryParse(match.group(2) ?? '');
        if (total != null && total > 0) return total;
      }
    }
    return null;
  }

  void goHome() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const Navbar()), (route) => false);
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
      case SendOverlayState.hardwareSign:
      case SendOverlayState.hardwareScan:
        widget.onClose();
        break;
    }
  }

  bool get _isReversible => widget.reversibleTimeSeconds > 0;

  final NumberFormattingService _formattingService = NumberFormattingService();
  final SettingsService _settingsService = SettingsService();

  @override
  void dispose() {
    _signatureScannerController.dispose();
    super.dispose();
  }

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
      _errorMessage = null;
    });

    try {
      final account = (await _settingsService.getActiveRegularAccount())!;

      // ignore: use_build_context_synchronously
      if (!context.mounted) {
        return;
      }

      if (account.accountType == AccountType.keystone || AppConstants.debugHardwareWallet) {
        _collectedUrParts.clear();
        await _startHardwareFlow(account);
        return;
      } else {
        // For local wallets, show progress state
        setState(() {
          currentState = SendOverlayState.progress;
        });
        await _handleLocalWalletTransaction(account);

        RecentAddressesService().addAddress(widget.recipientAddress);

        if (mounted) {
          setState(() {
            currentState = SendOverlayState.complete;
            _isSending = false;
          });
        }
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

  RuntimeCall _buildRuntimeCall() {
    final balancesService = BalancesService();
    final reversibleTransfersService = ReversibleTransfersService();

    if (widget.reversibleTimeSeconds <= 0) {
      return balancesService.getBalanceTransferCall(widget.recipientAddress, widget.amount);
    }

    final delay = qp.Timestamp(BigInt.from(widget.reversibleTimeSeconds) * BigInt.from(1000));
    return reversibleTransfersService.getReversibleTransferCall(widget.recipientAddress, widget.amount, delay);
  }

  Future<void> _startHardwareFlow(Account account) async {
    setState(() {
      currentState = SendOverlayState.hardwareSign;
      _hardwareAccount = account;
      _hardwareUnsignedData = null;
      _isHardwareSubmitting = false;
      _hasScannedSignature = false;
      _collectedUrParts.clear();
    });

    final substrateService = SubstrateService();
    final unsignedData = await substrateService.getUnsignedTransactionPayload(account, _buildRuntimeCall());
    if (!mounted) return;

    setState(() {
      _hardwareUnsignedData = unsignedData;
      _isSending = false;
    });
  }

  void _goToHardwareScanStep() {
    setState(() {
      currentState = SendOverlayState.hardwareScan;
      _hasScannedSignature = false;
      _isHardwareSubmitting = false;
      _collectedUrParts.clear();
    });
  }

  Future<void> _onHardwareSignatureScanned(List<String> signatureQRParts) async {
    if (_isHardwareSubmitting) return;
    final unsignedData = _hardwareUnsignedData;
    final account = _hardwareAccount;
    if (unsignedData == null || account == null) return;

    setState(() {
      _isHardwareSubmitting = true;
    });

    await _processHardwareSignature(signatureQRParts, unsignedData, account);
  }

  Future<void> _simulateHardwareSignature() async {
    final unsignedData = _hardwareUnsignedData;
    final account = _hardwareAccount;
    if (unsignedData == null || account == null) return;

    try {
      final debugWallet = await account.getKeypair();
      final signature = signMessage(keypair: debugWallet, message: unsignedData.encodedPayloadToSign);
      final signatureWithPublicKey = Uint8List(signature.length + debugWallet.publicKey.length);
      signatureWithPublicKey.setAll(0, signature);
      signatureWithPublicKey.setAll(signature.length, debugWallet.publicKey);
      // printKatValues(unsignedData, signatureWithPublicKey);
      await _onHardwareSignatureScanned(['0x${hex.encode(signatureWithPublicKey)}']);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Simulation failed: $e';
        _hasScannedSignature = false;
        _isHardwareSubmitting = false;
        _collectedUrParts.clear();
      });
    }
  }

  Future<void> _handleLocalWalletTransaction(Account account) async {
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
      if (widget.isHighSecurity) {
        // For high security accounts, use scheduleTransfer (no custom delay)
        await submissionService.scheduleTransfer(
          account: account,
          recipientAddress: widget.recipientAddress,
          amount: widget.amount,
          fee: widget.fee,
          blockHeight: widget.blockHeight,
        );
      } else {
        // For regular accounts, use scheduleReversibleTransferWithDelaySeconds
        await submissionService.scheduleReversibleTransferWithDelaySeconds(
          account: account,
          recipientAddress: widget.recipientAddress,
          amount: widget.amount,
          delaySeconds: widget.reversibleTimeSeconds,
          feeEstimate: widget.fee,
          blockHeight: widget.blockHeight,
        );
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
                    child: Icon(Icons.close, color: Colors.white, size: context.themeSize.overlayCloseIconSize),
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
              Text('SEND', textAlign: TextAlign.center, style: context.themeText.largeTitle),
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
                        TextSpan(text: formattedAmount, style: context.themeText.mediumTitle),
                        TextSpan(text: ' ${AppConstants.tokenSymbol}', style: context.themeText.paragraph),
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
                  Text('To:', style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.textMuted)),
                  const SizedBox(height: 12),
                  Text(
                    widget.recipientName,
                    textAlign: TextAlign.center,
                    style: context.themeText.paragraph?.copyWith(color: context.themeColors.checksum),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                              TextSpan(text: 'Reversible for: ', style: context.themeText.smallParagraph),
                              TextSpan(text: _formatReversibleTime(), style: context.themeText.detail),
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
                    style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
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
                    Text('Network fee', style: context.themeText.detail?.copyWith(fontWeight: FontWeight.w500)),

                    Row(
                      spacing: 8,
                      children: [
                        Text(
                          '$formattedFee ${AppConstants.tokenSymbol}',
                          style: context.themeText.detail?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        SvgPicture.asset('assets/settings_icon.svg', width: context.isTablet ? 20 : 14),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Button(variant: ButtonVariant.neutral, label: 'Confirm', onPressed: _isSending ? null : _confirmSend),
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
                    child: Icon(Icons.close, color: Colors.white, size: context.themeSize.overlayCloseIconSize),
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
              Text('TRANSACTION \nIN PROGRESS', textAlign: TextAlign.center, style: context.themeText.largeTitle),
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
                    child: Icon(Icons.close, color: Colors.white, size: context.themeSize.overlayCloseIconSize),
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
              Text('SENDING', textAlign: TextAlign.center, style: context.themeText.largeTitle),
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
                        TextSpan(text: formattedAmount, style: context.themeText.mediumTitle),
                        TextSpan(text: ' ${AppConstants.tokenSymbol}', style: context.themeText.paragraph),
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
                style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.textMuted),
              ),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    child: Text(
                      widget.recipientName,
                      textAlign: TextAlign.center,
                      style: context.themeText.paragraph?.copyWith(color: context.themeColors.checksum),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
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
                              TextSpan(text: 'Reversible for: ', style: context.themeText.smallParagraph),
                              TextSpan(text: _formatReversibleTime(), style: context.themeText.detail),
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
          Button(variant: ButtonVariant.glassOutline, label: 'Done', onPressed: goHome),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }

  Widget _buildHardwareSignState() {
    final unsignedData = _hardwareUnsignedData;

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
                    child: Icon(Icons.close, color: Colors.white, size: context.themeSize.overlayCloseIconSize),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Hardware wallet icon and title
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
              Text('Scan with Keystone Wallet', textAlign: TextAlign.center, style: context.themeText.largeTitle),
            ],
          ),
          const SizedBox(height: 28),

          if (unsignedData == null)
            SizedBox(
              height: 250,
              child: Center(child: CircularProgressIndicator(color: context.themeColors.primary)),
            )
          else
            Container(
              width: context.isTablet ? 300 : 250,
              height: context.isTablet ? 300 : 250,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Builder(
                builder: (context) {
                  final qrData = encodePayloadAsUr(unsignedData.encodedPayloadRaw);
                  debugPrint('QR Code payload: $qrData');
                  return QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: double.infinity,
                    padding: EdgeInsets.zero,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  );
                },
              ),
            ),

          const Spacer(),
          // Continue button
          SizedBox(
            width: context.themeSize.sendOverlayContainerWidth,
            child: Button(
              variant: ButtonVariant.neutral,
              label: 'Next',
              onPressed: unsignedData == null ? null : _goToHardwareScanStep,
            ),
          ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }

  Widget _buildHardwareScanState() {
    final unsignedData = _hardwareUnsignedData;

    return SizedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Back + close
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(7),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => setState(() => currentState = SendOverlayState.hardwareSign),
                  child: SizedBox(
                    width: context.themeSize.overlayCloseIconSize,
                    height: context.themeSize.overlayCloseIconSize,
                    child: Icon(Icons.arrow_back, color: Colors.white, size: context.themeSize.overlayCloseIconSize),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onClose,
                  child: SizedBox(
                    width: context.themeSize.overlayCloseIconSize,
                    height: context.themeSize.overlayCloseIconSize,
                    child: Icon(Icons.close, color: Colors.white, size: context.themeSize.overlayCloseIconSize),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Hardware wallet icon and title
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
              Text('SCAN SIGNATURE', textAlign: TextAlign.center, style: context.themeText.largeTitle),
            ],
          ),
          const SizedBox(height: 28),

          if (unsignedData == null)
            SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator(color: context.themeColors.primary)),
            )
          else if (_isHardwareSubmitting)
            SizedBox(
              height: 320,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: context.themeColors.primary),
                    const SizedBox(height: 16),
                    Text('Submitting...', style: context.themeText.paragraph),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              height: 320,
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _signatureScannerController,
                    onDetect: (capture) {
                      debugPrint('QR Scanner: onDetect called');
                      if (_hasScannedSignature || _isHardwareSubmitting) {
                        debugPrint('QR Scanner: Already scanned or submitting, ignoring');
                        return;
                      }
                      debugPrint('QR Scanner: Processing ${capture.barcodes.length} barcode(s)');
                      for (final barcode in capture.barcodes) {
                        final v = barcode.rawValue;
                        debugPrint(
                          'QR Scanner: Raw value: ${v?.substring(0, v.length > 100 ? 100 : v.length)}${v != null && v.length > 100 ? '...' : ''}',
                        );
                        if (v == null) {
                          debugPrint('QR Scanner: Null value, skipping');
                          continue;
                        }

                        if (v.startsWith('UR:')) {
                          debugPrint('QR Scanner: UR code detected');
                          final wasNew = _collectedUrParts.add(v);
                          debugPrint('QR Scanner: Was new part: $wasNew, Total parts: ${_collectedUrParts.length}');
                          if (wasNew) {
                            final total = _getTotalFragmentCount();
                            debugPrint('QR Scanner: Total fragments: $total');
                            setState(() {});
                            final isComplete = isCompleteUr(urParts: _collectedUrParts.toList());
                            debugPrint('QR Scanner: Is complete: $isComplete');
                            if (isComplete) {
                              debugPrint('QR Scanner: All parts collected, processing signature');
                              _hasScannedSignature = true;
                              _onHardwareSignatureScanned(_collectedUrParts.toList());
                            }
                          } else {
                            debugPrint('QR Scanner: Duplicate part, ignoring');
                          }
                        } else {
                          debugPrint('QR Scanner: Non-UR code detected, ignoring');
                        }
                        break;
                      }
                    },
                  ),
                  Container(
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: Color(0xFF0CE6ED), width: 2),
                      ),
                    ),
                    margin: const EdgeInsets.all(50),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_collectedUrParts.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              () {
                                final scanned = _collectedUrParts.length;
                                final total = _getTotalFragmentCount();
                                if (total != null) {
                                  return 'Scanned $scanned of $total fragments';
                                }
                                return 'Scanned $scanned fragment${scanned == 1 ? '' : 's'}...';
                              }(),
                              textAlign: TextAlign.center,
                              style: context.themeText.paragraph?.copyWith(
                                color: context.themeColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          _collectedUrParts.isEmpty
                              ? 'Position the QR code within the frame'
                              : 'Keep scanning until all parts are collected',
                          textAlign: TextAlign.center,
                          style: context.themeText.paragraph?.copyWith(
                            color: context.themeColors.textPrimary.useOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (AppConstants.debugHardwareWallet)
                    Positioned(
                      bottom: 56,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: TextButton(
                          onPressed: _simulateHardwareSignature,
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.red.useOpacity(0.7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text('DEBUG: SIMULATE SIGNATURE'),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          const Spacer(),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                _errorMessage!,
                style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }

  Future<void> _processHardwareSignature(
    List<String> signatureQRParts,
    UnsignedTransactionData unsignedData,
    Account account,
  ) async {
    try {
      Uint8List signatureBytes;

      if (signatureQRParts.isNotEmpty && signatureQRParts.first.startsWith('UR:')) {
        try {
          signatureBytes = decodeUr(urParts: signatureQRParts);
        } catch (e) {
          throw Exception('Invalid UR format: $e');
        }
      } else {
        throw Exception('Invalid signature format');
      }

      // print('signatureSize: ${hex.encode(signatureBytes)}');
      // print('sig PK hash: ${hex.encode(const Blake2bHasher(32).hash(signatureBytes))}');

      final expectedTotalSize = signatureSize + publicKeySize;

      if (signatureBytes.length != expectedTotalSize) {
        throw Exception('Invalid signature length: expected $expectedTotalSize bytes, got ${signatureBytes.length}');
      }

      final signature = signatureBytes.sublist(0, signatureSize);
      final publicKey = signatureBytes.sublist(signatureSize);

      final substrateService = SubstrateService();
      final submissionService = ref.read(transactionSubmissionServiceProvider);
      final pendingTx = PendingTransactionEvent(
        tempId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
        from: account.accountId,
        to: widget.recipientAddress,
        amount: widget.amount,
        timestamp: DateTime.now(),
        transactionState: TransactionState.created,
        fee: widget.fee,
        blockNumber: widget.blockHeight,
      );

      ref.read(pendingTransactionsProvider.notifier).add(pendingTx);

      Future<Uint8List> submissionBuilder() async {
        return await substrateService.submitExtrinsicWithExternalSignature(unsignedData, signature, publicKey);
      }

      RecentAddressesService().addAddress(widget.recipientAddress);

      TelemetryService().sendEvent('send_transfer_hardware');
      await submissionService.submitAndTrackTransaction(submissionBuilder, pendingTx);

      if (mounted) {
        setState(() {
          currentState = SendOverlayState.complete;
          _isSending = false;
          _isHardwareSubmitting = false;
        });
      }
    } catch (e) {
      print('Hardware signature processing failed: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Signature processing failed: ${e.toString()}';
          _isHardwareSubmitting = false;
          _hasScannedSignature = false;
          _collectedUrParts.clear();
        });
      }
    }
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
      case SendOverlayState.hardwareSign:
        content = _buildHardwareSignState();
        break;
      case SendOverlayState.hardwareScan:
        content = _buildHardwareScanState();
        break;
    }
    final effectiveSheetHeightFraction = context.isSmallHeight ? 0.9 : AppConstants.sendingSheetHeightFraction;

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
              height: MediaQuery.of(context).size.height * effectiveSheetHeightFraction,
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: ShapeDecoration(
                color: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
              ),
              child: content,
            ),
          ],
        ),
      ),
    );
  }
}
