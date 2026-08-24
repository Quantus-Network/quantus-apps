import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/routes.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/current_route_extensions.dart';
import 'package:resonance_network_wallet/shared/utils/print.dart';
import 'package:resonance_network_wallet/v2/screens/send/input_amount_screen.dart';
import 'package:resonance_network_wallet/v2/screens/send/regular_send_strategy.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';

class SharedAddressActionSheet extends StatefulWidget {
  final String address;
  const SharedAddressActionSheet({super.key, required this.address});

  @override
  State<SharedAddressActionSheet> createState() => _SharedAddressActionSheetState();
}

class _SharedAddressActionSheetState extends State<SharedAddressActionSheet> {
  String? _checksum;
  Future<String?>? _checksumFuture;
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
      quantusPrint('Error loading account data: $e');
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
    final container = ProviderScope.containerOf(context);
    // Fail closed: never pre-fill the send flow with an invalid address,
    // same as address entry in the send flow itself.
    if (!container.read(substrateServiceProvider).isValidSS58Address(widget.address)) {
      context.showErrorToaster(message: container.read(l10nProvider).invalidAddress);
      return;
    }
    final active = container.read(activeAccountProvider).value;
    if (active is! RegularAccount) {
      quantusPrint('shared address send: active account cannot send regular transfers');
      context.showWarningToaster(message: container.read(l10nProvider).sendRegularAccountRequired);
      return;
    }
    Navigator.of(context).pop();
    startSendFlow(
      context,
      screen: InputAmountScreen(
        strategy: RegularSendStrategy(account: active.account),
        recipientAddress: widget.address,
      ),
    );
  }

  Widget _copyIcon(AppColorsV3 colors) {
    return Icon(Icons.copy, size: 20, color: colors.textContent);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return BottomSheetContainer(
      title: 'Shared Acount',
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2, color: colors.accentFlare),
                      ),
                      const SizedBox(width: 8),
                      Text('Loading checkphrase...', style: text.caption.copyWith(color: colors.textMuted)),
                    ],
                  ),
                );
              } else if (snapshot.hasError || !snapshot.hasData || snapshot.data == null || snapshot.data!.isEmpty) {
                quantusPrint(
                  'Error loading checksum name for ${widget.address}: '
                  '${snapshot.error}',
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_checksum != null) {
                    setState(() {
                      _checksum = null;
                    });
                  }
                });

                return Text(
                  'Name not found',
                  style: text.body.copyWith(color: colors.textMuted),
                  textAlign: TextAlign.center,
                );
              } else {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_checksum != snapshot.data) {
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
                        style: text.body.copyWith(color: colors.semanticLilac),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    InkWell(onTap: _copyChecksum, child: _copyIcon(colors)),
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
                decoration: BoxDecoration(
                  color: colors.bgSurface2,
                  borderRadius: context.radiusV3.mdBorder,
                  border: Border.all(color: colors.borderHairline),
                ),
                child: Text(
                  '${_splittedAddress?.join(" ")}',
                  textAlign: TextAlign.left,
                  style: text.dataAddressLarge.copyWith(color: colors.textContent),
                ),
              ),
              InkWell(onTap: _copyAddress, child: _copyIcon(colors)),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: context.isTablet ? 465 : 305,
            child: QuantusButton.simple(label: 'Send To This Account', onTap: _sendToAddress),
          ),
        ],
      ),
    );
  }
}

void showSharedAddressActionSheet(BuildContext context, String address) {
  if (context.peekTopRouteName == sharedAccountSheetRouteSettings.name) Navigator.pop(context);

  BottomSheetContainer.show(
    context,
    routeSettings: sharedAccountSheetRouteSettings,
    builder: (_) => SharedAddressActionSheet(address: address),
  );
}
