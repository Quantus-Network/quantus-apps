import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_mobile_wallet/features/components/snackbar_helper.dart';

class ReceiveSheet extends StatefulWidget {
  const ReceiveSheet({super.key});

  @override
  State<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<ReceiveSheet> {
  String? _accountId;
  String? _accountName;
  String? _checksum;
  Future<String>? _checksumFuture;
  List<String>? _splittedAddress;

  final HumanReadableChecksumService _checksumService =
      HumanReadableChecksumService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    try {
      final account = await _settingsService.getActiveAccount();
      setState(() {
        _accountName = account.name;
        _accountId = account.accountId;
        _checksumFuture = _checksumService.getHumanReadableName(
          account.accountId,
        );
        _splittedAddress = AddressFormattingService.splitIntoChunks(
          account.accountId,
        );
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _copyAddress() {
    if (_accountId != null && _checksum != null) {
      Clipboard.setData(ClipboardData(text: '$_accountId\n$_checksum'));

      showTopSnackBar(
        context,
        icon: Container(
          width: 36,
          height: 36,
          decoration: const ShapeDecoration(
            color: Color(0xFF494949), // Default grey background
            shape: OvalBorder(), // Use OvalBorder for circle
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            'assets/copy_icon.svg',
            width: 16,
            height: 16,
          ),
        ),
        title: 'Copied!',
        message: 'Address and checkphrase copied to clipboard',
      );
    }
  }

  void _closeSheet() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
        decoration: ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(7),
              decoration: ShapeDecoration(
                color: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  InkWell(onTap: _closeSheet, child: const Icon(Icons.close)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/receive_icon.svg',
                  width: 37,
                  height: 37,
                ),
                const SizedBox(width: 7),
                const Text(
                  'RECEIVE',
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
            if (_accountId == null)
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              )
            else ...[
              Container(
                width: 227,
                height: 227,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: QrImageView(
                  data: _accountId!,
                  version: QrVersions.auto,
                  size: 260.0,
                  padding: EdgeInsets.zero,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                spacing: 15,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/account_list_icon.svg',
                    width: 21,
                    height: 32,
                  ),
                  Text(
                    _accountName ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FutureBuilder<String?>(
                    future: _checksumFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 14,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 12,
                                height: 12,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white54,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Loading name...',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      } else if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data == null ||
                          snapshot.data!.isEmpty) {
                        debugPrint(
                          'Error loading checksum name for $_accountId: '
                          '${snapshot.error}',
                        );
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_checksum != null) {
                            // Only clear if it was set before
                            setState(() {
                              _checksum = null;
                            });
                          }
                        });

                        return const Text(
                          'Name not found',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w400,
                          ),
                          textAlign: TextAlign.center,
                        );
                      } else {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_checksum != snapshot.data) {
                            // Only update if it's different
                            setState(() {
                              _checksum = snapshot.data!;
                            });
                          }
                        });

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 7,
                          children: [
                            Text(
                              snapshot.data!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            InkWell(
                              onTap: _copyAddress,
                              child: SvgPicture.asset(
                                'assets/copy_icon.svg',
                                width: 16,
                                height: 16,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 27.5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8,
                    children: [
                      Container(
                        width: 214,
                        padding: const EdgeInsets.all(10),
                        decoration: ShapeDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: Text(
                          '${_splittedAddress?.join(" ")}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: _copyAddress,
                        child: SvgPicture.asset(
                          'assets/copy_icon.svg',
                          width: 16,
                          height: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 305,
                height: 44,
                child: ElevatedButton(
                  onPressed: _copyAddress,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                  child: const Text(
                    'Share',
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
          ],
        ),
      ),
    );
  }
}

// Helper function to show the receive sheet
void showReceiveSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
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
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(
              color: Colors.black.useOpacity(0.3),
              child: const ReceiveSheet(),
            ),
          ),
        ),
      ],
    ),
  );
}
