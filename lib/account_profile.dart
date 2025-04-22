import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountInfo {
  final String name;
  final String address;
  final String balance;

  AccountInfo({required this.name, required this.address, required this.balance});
}

class AccountProfilePage extends StatefulWidget {
  final String currentAccountId;

  const AccountProfilePage({
    super.key,
    required this.currentAccountId,
  });

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  AccountInfo? _account;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getString('account_id');
      final walletName = prefs.getString('wallet_name') ?? '';

      if (accountId == null) {
        throw Exception('No account found');
      }

      final balance = await SubstrateService().queryBalance(accountId);
      final formattedBalance = SubstrateService().formatBalance(balance);

      setState(() {
        _account = AccountInfo(
          name: walletName,
          address: accountId,
          balance: formattedBalance,
        );
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _createNewWallet() {
    debugPrint('Create New Wallet tapped');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Create New Wallet action not implemented yet.')),
    );
  }

  void _logoutAndClearData() async {
    debugPrint('Log Out tapped');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D2D),
        title: const Text('Confirm Logout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to log out? This will delete all local wallet data. Make sure you have backed up your recovery phrase.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF9F7AEA))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            child: const Text('Log Out & Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SubstrateService().logout();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        debugPrint('Error during logout: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Logout failed: ${e.toString()}')),
          );
        }
      }
    }
  }

  void _copyAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Address copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Your Accounts',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/BG_00 1.png'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                if (_isLoading)
                  const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  )
                else if (_account == null)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'No account found',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView(
                      children: [
                        _buildAccountItem(_account!, true),
                      ],
                    ),
                  ),
                const SizedBox(height: 24),
                _buildActionButton(
                  text: 'Create New Wallet',
                  onPressed: _createNewWallet,
                  isOutlined: true,
                ),
                const SizedBox(height: 16),
                _buildActionButton(
                  text: 'Log Out & Clear Data',
                  onPressed: _logoutAndClearData,
                  isOutlined: false,
                  backgroundColor: const Color(0xFFE6E6E6),
                  textColor: const Color(0xFF0E0E0E),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountItem(AccountInfo account, bool isActive) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: ShapeDecoration(
        color: Colors.black.useOpacity(166 / 255.0),
        shape: RoundedRectangleBorder(
          side: isActive ? const BorderSide(width: 1, color: Colors.white) : BorderSide.none,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            'assets/account_list_icon.svg',
            width: 21,
            height: 32,
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        account.address,
                        style: TextStyle(
                          color: Colors.white.useOpacity(153 / 255.0),
                          fontSize: 10,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w300,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 5),
                    InkWell(
                      onTap: () => _copyAddress(account.address),
                      child: const Icon(
                        Icons.content_copy,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: account.balance,
                        style: const TextStyle(
                          color: Color(0xFFE6E6E6),
                          fontSize: 12,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const TextSpan(
                        text: ' RES',
                        style: TextStyle(
                          color: Color(0xFFE6E6E6),
                          fontSize: 10,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback onPressed,
    required bool isOutlined,
    Color? backgroundColor,
    Color? textColor,
  }) {
    final ButtonStyle style = isOutlined
        ? OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE6E6E6),
            side: const BorderSide(width: 1, color: Color(0xFFE6E6E6)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            minimumSize: const Size(double.infinity, 50),
            textStyle: const TextStyle(
              fontSize: 18,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w500,
            ),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? const Color(0xFFE6E6E6),
            foregroundColor: textColor ?? const Color(0xFF0E0E0E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            minimumSize: const Size(double.infinity, 50),
            textStyle: const TextStyle(
              fontSize: 18,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w500,
            ),
          );

    return SizedBox(
      width: double.infinity,
      child: isOutlined
          ? OutlinedButton(onPressed: onPressed, style: style, child: Text(text))
          : ElevatedButton(onPressed: onPressed, style: style, child: Text(text)),
    );
  }
}
