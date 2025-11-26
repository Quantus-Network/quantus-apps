import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/recent_address_list_item.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class RecentAddressList extends StatefulWidget {
  final Function(String) onAddressSelected;
  final String currentAddress;

  const RecentAddressList({super.key, required this.currentAddress, required this.onAddressSelected});

  @override
  State<RecentAddressList> createState() => _RecentAddressListState();
}

class _RecentAddressListState extends State<RecentAddressList> {
  late Future<List<String>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    _addressesFuture = RecentAddressesService().getAddresses();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _addressesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}', style: context.themeText.smallParagraph));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(child: Text('No recent addresses.', style: context.themeText.smallParagraph));
        }

        final addresses = snapshot.data!;
        addresses.remove(widget.currentAddress);

        return ListView.separated(
          itemCount: addresses.length,
          separatorBuilder: (context, index) => const SizedBox(height: 20),
          itemBuilder: (context, index) {
            final address = addresses[index];
            return RecentAddressListItem(address: address, onTap: () => widget.onAddressSelected(address));
          },
        );
      },
    );
  }
}
