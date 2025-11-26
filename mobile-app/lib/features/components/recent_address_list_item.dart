import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class RecentAddressListItem extends StatefulWidget {
  final String address;
  final VoidCallback onTap;

  const RecentAddressListItem({super.key, required this.address, required this.onTap});

  @override
  State<RecentAddressListItem> createState() => _RecentAddressListItemState();
}

class _RecentAddressListItemState extends State<RecentAddressListItem> {
  late Future<String> _humanReadableNameFuture;

  @override
  void initState() {
    super.initState();
    _humanReadableNameFuture = HumanReadableChecksumService().getHumanReadableName(widget.address);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<String>(
            future: _humanReadableNameFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Text(
                  'Loading name...',
                  style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.checksum),
                );
              } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return Text(
                  'Unknown Name',
                  style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.checksum),
                );
              }
              return Text(
                snapshot.data!,
                style: context.themeText.smallParagraph?.copyWith(color: context.themeColors.checksum),
              );
            },
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 217,
            child: Text(
              AddressFormattingService.splitIntoChunks(widget.address).join(' '),
              style: context.themeText.detail?.copyWith(color: context.themeColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
