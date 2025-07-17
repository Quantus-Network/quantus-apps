import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/main/screens/create_account_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';

class AccountSettingsScreen extends StatefulWidget {
  final Account account;
  final String balance;
  final String checksumName;

  const AccountSettingsScreen({super.key, required this.account, required this.balance, required this.checksumName});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  void _showReceiveModal() {
    showReceiveSheet(context);
  }

  void _editAccountName() {
    Navigator.push<bool?>(
      context,
      MaterialPageRoute(builder: (context) => CreateAccountScreen(accountToEdit: widget.account)),
    ).then((result) {
      if (result == true && mounted) {
        // Pop this screen with a result to force a refresh on the previous one
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/light_leak_effect_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(),
              const SizedBox(height: 20),
              _buildAccountHeader(),
              const SizedBox(height: 40),
              _buildAddressSection(),
              const SizedBox(height: 20),
              _buildSecuritySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Account Settings',
            style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Fira Code'),
          ),
          const SizedBox(width: 48), // To balance the back button
        ],
      ),
    );
  }

  Widget _buildAccountHeader() {
    return Column(
      children: [
        // Placeholder for account icon
        SvgPicture.asset('assets/res_icon.svg', width: 60, height: 60),
        const SizedBox(height: 10),
        InkWell(
          onTap: _editAccountName,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.account.name,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Fira Code'),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.edit, color: Colors.white70, size: 16),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Text(
          widget.checksumName,
          style: const TextStyle(color: Color(0xFF16CECE), fontSize: 14, fontFamily: 'Fira Code'),
        ),
        const SizedBox(height: 5),
        Text(
          widget.balance,
          style: const TextStyle(color: Color(0xFFE6E6E6), fontSize: 14, fontFamily: 'Fira Code'),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF313131), borderRadius: BorderRadius.circular(4)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AddressFormattingService.formatAddress(widget.account.accountId),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Fira Code'),
            ),
            IconButton(
              icon: const Icon(Icons.copy, color: Colors.white, size: 22),
              onPressed: _showReceiveModal,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFF313131), borderRadius: BorderRadius.circular(4)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.white, size: 25),
                SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'High Security',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Fira Code'),
                    ),
                    Text(
                      'OFF', // This should be dynamic based on the account's state
                      style: TextStyle(color: Colors.white54, fontSize: 12, fontFamily: 'Fira Code'),
                    ),
                  ],
                ),
              ],
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 17),
          ],
        ),
      ),
    );
  }
}
