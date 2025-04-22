import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';

class ReceiveSheet extends StatefulWidget {
  const ReceiveSheet({super.key});

  @override
  State<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<ReceiveSheet> {
  String? _accountId;
  String? _walletName;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getString('account_id');
      final walletName = prefs.getString('wallet_name');

      if (accountId == null) {
        throw Exception('No account found');
      }

      setState(() {
        _accountId = accountId;
        _walletName = walletName;
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');
    }
  }

  void _copyAddress() {
    if (_accountId != null) {
      Clipboard.setData(ClipboardData(text: _accountId!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Address copied to clipboard')),
      );
    }
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
                  const SizedBox(width: 10, height: 10),
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
                    fontSize: 37,
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
              const SizedBox(height: 28),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    _walletName ?? 'Unnamed Wallet',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Opacity(
                    opacity: 0.5,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _accountId!.substring(0, 6) + '...' + _accountId!.substring(_accountId!.length - 5),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
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
    builder: (context) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
      child: Container(
        color: Colors.black.withOpacity(0.2),
        child: const ReceiveSheet(),
      ),
    ),
  );
}
