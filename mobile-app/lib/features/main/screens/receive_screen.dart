import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/copy_icon.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:share_plus/share_plus.dart';

class ReceiveSheet extends StatefulWidget {
  final bool isReceiving;

  const ReceiveSheet({super.key, this.isReceiving = true});

  @override
  State<ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<ReceiveSheet> {
  String? _accountId;
  String? _accountName;
  String? _checksum;
  Future<String>? _checksumFuture;
  List<String>? _splittedAddress;

  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    try {
      final account = (await _settingsService.getActiveAccount())!;
      setState(() {
        _accountName = account.account.name;
        _accountId = account.account.accountId;
        _checksumFuture = _checksumService.getHumanReadableName(account.account.accountId);
        _splittedAddress = AddressFormattingService.splitIntoChunks(account.account.accountId);
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _copyAddress() {
    if (_accountId != null) {
      ClipboardExtensions.copyTextWithSnackbar(context, _accountId!);
    }
  }

  void _copyChecksum() {
    if (_checksum != null) {
      ClipboardExtensions.copyTextWithSnackbar(context, _checksum!, message: 'Checkphrase copied to clipboard');
    }
  }

  void _share() {
    if (_accountId != null && _checksum != null) {
      final textToShare =
          'Hey! These are my Quantus account details:\n\nAddress:\n$_accountId\n\nCheckphrase:$_checksum\n\nTo open in the app or to download click the link below:\n${AppConstants.websiteBaseUrl}/account?id=$_accountId';
      SharePlus.instance.share(
        ShareParams(
          text: textToShare,
          subject: 'Shared Address',
          title: 'Shared Address',
          sharePositionOrigin: context.sharePositionRect(),
        ),
      );
    }
  }

  void _closeSheet() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: ShapeDecoration(
          color: context.themeColors.background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Stack(
          children: [
            Positioned(
              left: context.getHorizontalCenterPosition(
                230 + (24 * 2),
              ), // We add 24 * 2 because of the padding horizontal
              bottom: -100,
              child: const Sphere(variant: 7, size: 230),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(7),
                  decoration: ShapeDecoration(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      InkWell(
                        onTap: _closeSheet,
                        child: Icon(Icons.close, size: context.isTablet ? 28 : 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                if (widget.isReceiving) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset('assets/transaction/receive_icon.svg', width: context.isTablet ? 67 : 37),
                      const SizedBox(width: 7),
                      Text('RECEIVE', style: context.themeText.largeTitle),
                    ],
                  ),
                  SizedBox(height: context.isTablet ? 36 : 28),
                ],
                if (_accountId == null)
                  const Center(child: CircularProgressIndicator(color: Colors.white))
                else ...[
                  Container(
                    width: context.isTablet ? 277 : 227,
                    height: context.isTablet ? 277 : 227,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    child: QrImageView(
                      data: _accountId!,
                      version: QrVersions.auto,
                      size: 260.0,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  SizedBox(height: context.isTablet ? 23 : 15),
                  Row(
                    spacing: 15,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AccountGradientImage(
                        accountId: _accountId,
                        width: context.isTablet ? 32.0 : 24.0,
                        height: context.isTablet ? 32.0 : 24.0,
                      ),
                      Text(_accountName ?? '', textAlign: TextAlign.center, style: context.themeText.smallTitle),
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
                            return SizedBox(
                              height: 14,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Loading checkphrase...',
                                    style: context.themeText.paragraph?.copyWith(color: Colors.white54),
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

                            return Text(
                              'Name not found',
                              style: context.themeText.paragraph,
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

                            return InkWell(
                              onTap: _copyChecksum,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                spacing: 7,
                                children: [
                                  Flexible(
                                    child: Text(
                                      snapshot.data!,
                                      style: context.themeText.paragraph,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  const CopyIcon(),
                                ],
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 26),
                      InkWell(
                        onTap: _copyAddress,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          spacing: 8,
                          children: [
                            Container(
                              width: context.isTablet ? 386 : 271,
                              padding: const EdgeInsets.all(10),
                              decoration: ShapeDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              child: Text(
                                '${_splittedAddress?.join(" ")}',
                                textAlign: TextAlign.left,
                                style: context.themeText.smallParagraph,
                              ),
                            ),
                            const CopyIcon(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: context.isTablet ? 465 : 305,
                    child: Button(label: 'Share Wallet', variant: ButtonVariant.primary, onPressed: _share),
                  ),
                  SizedBox(height: context.isSmallHeight ? 40 : 80),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show the receive sheet
void showReceiveSheet(BuildContext context, {bool isReceiving = true}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxWidth: MediaQuery.of(context).size.width, // Ensure full width
    ),
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
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
            child: Container(color: Colors.black.useOpacity(0.3), child: const ReceiveSheet(isReceiving: false)),
          ),
        ),
      ],
    ),
  );
}
