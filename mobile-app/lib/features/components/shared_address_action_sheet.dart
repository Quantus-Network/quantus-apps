import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';

class SharedAddressActionSheet extends StatefulWidget {
  final String address;
  const SharedAddressActionSheet({super.key, required this.address});

  @override
  State<SharedAddressActionSheet> createState() => _SharedAddressActionSheetState();
}

class _SharedAddressActionSheetState extends State<SharedAddressActionSheet> {
  String? _checksum;
  Future<String>? _checksumFuture;
  List<String>? _splittedAddress;

  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    try {
      setState(() {
        _checksumFuture = _checksumService.getHumanReadableName(widget.address);
        _splittedAddress = AddressFormattingService.splitIntoChunks(widget.address);
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _copyAddress() {
    context.copyTextWithToaster(widget.address);
  }

  void _copyChecksum() {
    if (_checksum != null) {
      context.copyTextWithToaster(_checksum!, message: 'Checkphrase copied to clipboard');
    }
  }

  void _sendToAddress() {
    Navigator.of(context).pop();
    Navigator.push(context, MaterialPageRoute(builder: (_) => InputAmountScreen(recipientAddress: widget.address)));
  }

  void _closeSheet() {
    Navigator.of(context).pop();
  }

  Widget _copyIcon() {
    return const Icon(Icons.copy, size: 20, color: Colors.white);
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
                Text('Shared Acount', style: context.themeText.largeTitle),
                SizedBox(height: context.isTablet ? 36 : 28),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    FutureBuilder<String?>(
                      future: _checksumFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return SizedBox(
                            height: 18,
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
                            'Error loading checksum name for ${widget.address}: '
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

                          return Row(
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
                              InkWell(onTap: _copyChecksum, child: _copyIcon()),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 26),
                    Row(
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
                        InkWell(onTap: _copyAddress, child: _copyIcon()),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: context.isTablet ? 465 : 305,
                  child: QuantusButton.simple(label: 'Send To This Account', onTap: _sendToAddress),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to show the receive sheet
void showSharedAddressActionSheet(BuildContext context, String address) {
  if (context.peekTopRouteName == sharedAccountSheetRouteSettings.name) Navigator.pop(context);

  showModalBottomSheet(
    context: context,
    routeSettings: sharedAccountSheetRouteSettings,
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
            child: Container(
              color: Colors.black.useOpacity(0.3),
              child: SharedAddressActionSheet(address: address),
            ),
          ),
        ),
      ],
    ),
  );
}
