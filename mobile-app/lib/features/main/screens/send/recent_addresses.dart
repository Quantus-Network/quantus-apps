import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/recent_address_list.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';

class RecentAddresses extends StatelessWidget {
  final TextEditingController recipientController;
  final Account activeAccount;
  final VoidCallback lookupIdentity;

  const RecentAddresses({
    super.key,
    required this.recipientController,
    required this.activeAccount,
    required this.lookupIdentity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8, // Adjustable height for scrollability
      padding: const EdgeInsets.fromLTRB(35, 16, 35, 16),
      decoration: const ShapeDecoration(
        color: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)), // Softer radius for modal
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
                SizedBox(width: 226, child: Text('Recently Used', style: context.themeText.largeTag)),
                const SizedBox(height: 20), // Spacing from Figma
                Expanded(
                  child: RecentAddressList(
                    currentAddress: activeAccount.accountId,
                    onAddressSelected: (address) {
                      recipientController.text = address;
                      lookupIdentity();
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// NEW: Method to show the recent addresses modal bottom sheet
void showRecentAddresses(
  BuildContext context, {
  required Account activeAccount,
  required TextEditingController recipientController,
  required VoidCallback lookupIdentity,
}) async {
  showAppModalBottomSheet(
    // ignore: use_build_context_synchronously
    context: context,
    builder: (context) => RecentAddresses(
      recipientController: recipientController,
      activeAccount: activeAccount,
      lookupIdentity: lookupIdentity,
    ),
  );
}
