import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';

class AccountInfo {
  final String name;
  final String address;
  final String balance;

  AccountInfo({required this.name, required this.address, required this.balance});
}

class AccountProfilePage extends StatefulWidget {
  final String currentAccountId;

  const AccountProfilePage({super.key, required this.currentAccountId});

  @override
  State<AccountProfilePage> createState() => _AccountProfilePageState();
}

class _AccountProfilePageState extends State<AccountProfilePage> {
  AccountInfo? _account;
  bool _isLoading = true;
  final NumberFormattingService _formattingService = NumberFormattingService();
  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();
  final SettingsService _settingsService = SettingsService();

  @override
  void initState() {
    super.initState();
    _checksumService.initialize();
    _loadAccountData();
  }

  Future<void> _loadAccountData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final accountId = await _settingsService.getAccountId();

      if (accountId == null) {
        throw Exception('No account found');
      }

      final balance = await SubstrateService().queryBalance(accountId);
      final formattedBalance = _formattingService.formatBalance(balance);

      setState(() {
        _account = AccountInfo(name: '', address: accountId, balance: formattedBalance);
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
    showTopSnackBar(context, title: 'Info', message: 'Create New Wallet action not implemented yet.');
  }

  void _showLogoutConfirmationSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext bc) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
            decoration: const ShapeDecoration(
              color: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Confirm Logout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                const SizedBox(height: 13),
                const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Are you sure you want to Logout? This will delete all local wallet data. Make sure you have backed up your recovery phrase.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () async {
                    final navigator = Navigator.of(context);
                    final scaffoldMessenger = ScaffoldMessenger.of(context);
                    navigator.pop();
                    try {
                      await SubstrateService().logout();
                      if (mounted) {
                        navigator.pushNamedAndRemoveUntil('/', (route) => false);
                      }
                    } catch (e) {
                      debugPrint('Error during logout: $e');
                      if (mounted) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Logout failed: ${e.toString()}'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFF2D53),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'Reset & Clear Data',
                          style: TextStyle(
                            color: Color(0xFF0E0E0E),
                            fontSize: 18,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: double.infinity,
                    child: Text(
                      'Cancel',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFF1D25),
                        fontSize: 14,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                        decorationColor: Color(0xFFFF1D25),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  void _logoutAndClearData() async {
    debugPrint('Log Out tapped');
    _showLogoutConfirmationSheet(context);
  }

  void _copyAddress(String address) {
    Clipboard.setData(ClipboardData(text: address));
    showTopSnackBar(context, title: 'Copied!', message: 'Address copied to clipboard');
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
          style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Fira Code', fontWeight: FontWeight.w400),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/light_leak_effect_background.jpg'),
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
                    child: Center(child: CircularProgressIndicator(color: Colors.white)),
                  )
                else if (_account == null)
                  const Expanded(
                    child: Center(
                      child: Text('No account found', style: TextStyle(color: Colors.white)),
                    ),
                  )
                else
                  Expanded(child: ListView(children: [_buildAccountItem(_account!, true)])),
                const SizedBox(height: 24),
                _buildActionButton(text: 'Create New Wallet', onPressed: _createNewWallet, isOutlined: true),
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
          SvgPicture.asset('assets/account_list_icon.svg', width: 21, height: 32),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FutureBuilder<String?>(
                  future: _checksumService.getHumanReadableName(account.address),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 14,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                            ),
                          ],
                        ),
                      );
                    } else if (snapshot.hasError) {
                      debugPrint('Error fetching identity name for ${account.address}: ${snapshot.error}');
                      return Text(
                        account.name,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    } else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
                      return Text(
                        snapshot.data!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    } else {
                      return Text(
                        account.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                  },
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
                      child: const Icon(Icons.content_copy, color: Colors.white70, size: 14),
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
                        text: ' ${AppConstants.tokenSymbol}',
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
            textStyle: const TextStyle(fontSize: 18, fontFamily: 'Fira Code', fontWeight: FontWeight.w500),
          )
        : ElevatedButton.styleFrom(
            backgroundColor: backgroundColor ?? const Color(0xFFE6E6E6),
            foregroundColor: textColor ?? const Color(0xFF0E0E0E),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            minimumSize: const Size(double.infinity, 50),
            textStyle: const TextStyle(fontSize: 18, fontFamily: 'Fira Code', fontWeight: FontWeight.w500),
          );

    return SizedBox(
      width: double.infinity,
      child: isOutlined
          ? OutlinedButton(onPressed: onPressed, style: style, child: Text(text))
          : ElevatedButton(onPressed: onPressed, style: style, child: Text(text)),
    );
  }
}
