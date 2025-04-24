import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io'; // Import for SocketException
import 'dart:async'; // Import for Future.timeout / TimeoutException
import 'package:resonance_network_wallet/account_profile.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/core/services/number_formatting_service.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';

class WalletData {
  final String accountId;
  final String walletName;
  final BigInt balance;

  WalletData({required this.accountId, required this.walletName, required this.balance});
}

class WalletMain extends StatefulWidget {
  const WalletMain({super.key});

  @override
  State<WalletMain> createState() => _WalletMainState();
}

class _WalletMainState extends State<WalletMain> {
  final SubstrateService _substrateService = SubstrateService();
  final NumberFormattingService _formattingService = NumberFormattingService();

  Future<WalletData?>? _walletDataFuture;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _loadWalletDataAndSetFuture();
  }

  void _loadWalletDataAndSetFuture() {
    setState(() {
      _walletDataFuture = _loadWalletDataInternal();
    });
  }

  Future<WalletData?> _loadWalletDataInternal() async {
    String? accountId;
    String? walletName;
    BigInt? balance;
    const Duration networkTimeout = Duration(seconds: 15);

    try {
      final prefs = await SharedPreferences.getInstance();
      accountId = prefs.getString('account_id');
      walletName = prefs.getString('wallet_name') ?? 'Name Unknown';

      if (accountId == null || accountId.isEmpty) {
        throw Exception('Account ID not found');
      }
      _accountId = accountId;

      debugPrint('Attempting initial balance query for $accountId...');
      balance = await _substrateService.queryBalance(accountId).timeout(networkTimeout);
      debugPrint('Initial balance query successful.');
    } catch (e) {
      debugPrint('Initial load/query failed: $e');

      bool isConnectionError = e is SocketException ||
          e is TimeoutException ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('WebSocket');

      if (isConnectionError && accountId != null) {
        debugPrint('Connection error detected. Attempting reconnect and retry...');
        try {
          await _substrateService.reconnect();
          balance = await _substrateService.queryBalance(accountId).timeout(networkTimeout);
          debugPrint('Balance query successful after reconnect.');
        } catch (retryError) {
          debugPrint('Retry failed after reconnect: $retryError');
          throw Exception('Failed to load wallet data after retry: $retryError');
        }
      } else {
        debugPrint('Error was not connection-related or accountId is null. Rethrowing.');
        throw Exception('Failed to load wallet data: $e');
      }
    }

    return WalletData(accountId: accountId, walletName: walletName!, balance: balance);
  }

  Widget _buildActionButton({
    required Widget iconWidget,
    required String label,
    required Color borderColor,
    required VoidCallback onPressed,
    bool disabled = false,
  }) {
    final color = disabled ? Colors.white.useOpacity(0.5) : Colors.white;
    final bgColor = Colors.black.useOpacity(166 / 255.0);
    final effectiveBorderColor = disabled ? borderColor.useOpacity(0.5) : borderColor;

    Widget finalIconWidget = iconWidget;
    if (iconWidget is SvgPicture) {
      finalIconWidget = SvgPicture.asset(
        (iconWidget.bytesLoader as SvgAssetLoader).assetName,
        width: 20,
        height: 20,
      );
    } else if (iconWidget is Icon) {
      finalIconWidget = Icon(
        iconWidget.icon,
        color: color,
        size: 20,
      );
    } else if (iconWidget is Image) {
      finalIconWidget = SizedBox(
        width: 20,
        height: 20,
        child: iconWidget,
      );
    }

    return Opacity(
      opacity: disabled ? 0.7 : 1.0,
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 65,
          height: 56,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: ShapeDecoration(
            color: bgColor,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: 1, color: effectiveBorderColor),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              finalIconWidget,
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionItem({
    required String type,
    required String amount,
    required String details,
    required IconData icon,
    required Color typeColor,
  }) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, color: typeColor, size: 20),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$type ',
                          style: TextStyle(
                            color: typeColor,
                            fontSize: 14,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: amount,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    details,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Divider(
          color: Colors.white.useOpacity(38 / 255.0),
          height: 1,
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Future<void> _logout() async {
    try {
      await _substrateService.logout();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WelcomeScreen()),
          (route) => false,
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg_001.png'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: FutureBuilder<WalletData?>(
              future: _walletDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Colors.red, size: 50),
                                const SizedBox(height: 20),
                                const Text(
                                  'Failed to Connect',
                                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Could not load wallet data. Please check your network connection and try again.',
                                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0, top: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFullWidthActionButton(
                              label: 'Retry',
                              onTap: _loadWalletDataAndSetFuture,
                              gradient: const LinearGradient(
                                begin: Alignment(0.50, 0.00),
                                end: Alignment(0.50, 1.00),
                                colors: [Color(0xFF0CE6ED), Color(0xFF8AF9A8)],
                              ),
                            ),
                            const SizedBox(height: 15),
                            _buildFullWidthActionButton(
                              label: 'Logout',
                              onTap: _logout,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              textColor: Colors.white.withOpacity(0.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final walletData = snapshot.data!;

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadWalletDataAndSetFuture();
                    await _walletDataFuture;
                  },
                  color: const Color(0xFF0CE6ED), // Match your app's accent color
                  backgroundColor: Colors.black,
                  child: ListView(
                    physics:
                        const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works even when content fits screen
                    children: [
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              SvgPicture.asset('assets/main_wallet_title_logo.svg', height: 40),
                              Row(
                                children: [
                                  IconButton(
                                    icon: SvgPicture.asset('assets/wallet_icon.svg', width: 24, height: 24),
                                    onPressed: () {
                                      if (_accountId != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => AccountProfilePage(currentAccountId: _accountId!),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ],
                              )
                            ],
                          ),
                          const SizedBox(height: 40),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              InkWell(
                                onTap: () {
                                  if (_accountId != null) {
                                    Clipboard.setData(ClipboardData(text: _accountId!));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Account ID copied to clipboard')),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(5),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SvgPicture.asset(
                                        'assets/active_dot.svg',
                                        width: 13,
                                        height: 13,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: ShapeDecoration(
                                            color: Colors.black.useOpacity(0.5),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                          ),
                                          child: Text(
                                            walletData.walletName,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontFamily: 'Fira Code',
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.expand_more, color: Colors.white70, size: 12),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 7),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: _formattingService.formatBalance(walletData.balance),
                                      style: const TextStyle(
                                        color: Color(0xFFE6E6E6),
                                        fontSize: 40,
                                        fontFamily: 'Fira Code',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(
                                      text: ' RES',
                                      style: TextStyle(
                                        color: Color(0xFFE6E6E6),
                                        fontSize: 20,
                                        fontFamily: 'Fira Code',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildActionButton(
                                iconWidget: SvgPicture.asset('assets/send_icon_1.svg'),
                                label: 'SEND',
                                borderColor: const Color(0xFF0AD4F6),
                                onPressed: () {
                                  Navigator.pushNamed(context, '/send');
                                },
                              ),
                              _buildActionButton(
                                iconWidget: SvgPicture.asset('assets/receive_icon.svg'),
                                label: 'RECEIVE',
                                borderColor: const Color(0xFFB258F1),
                                onPressed: () {
                                  showReceiveSheet(context);
                                },
                              ),
                              _buildActionButton(
                                iconWidget: const Icon(Icons.swap_horiz),
                                label: 'SWAP',
                                borderColor: const Color(0xFF0AD4F6),
                                onPressed: () {},
                                disabled: true,
                              ),
                              _buildActionButton(
                                iconWidget: const Icon(Icons.sync_alt),
                                label: 'BRIDGE',
                                borderColor: const Color(0xFF0AD4F6),
                                onPressed: () {},
                                disabled: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 30),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: ShapeDecoration(
                              color: Colors.black.useOpacity(64 / 255.0),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Recent Transactions',
                                  style: TextStyle(
                                    color: Color(0xFFE6E6E6),
                                    fontSize: 14,
                                    fontFamily: 'Fira Code',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 18),
                                SizedBox(
                                  height: 300, // Fixed height for transactions list
                                  child: ListView(
                                    physics:
                                        const NeverScrollableScrollPhysics(), // Disable scrolling for inner ListView
                                    children: [
                                      _buildTransactionItem(
                                        type: 'Sent',
                                        amount: '-13.082 RES',
                                        details: 'to 0xc344...fe82 | 01-04-2025  09:45:21',
                                        icon: Icons.arrow_upward,
                                        typeColor: const Color(0xFF16CECE),
                                      ),
                                      _buildTransactionItem(
                                        type: 'Received',
                                        amount: '13.2345 RES',
                                        details: 'from 0xc344...fe82 | 24-12-2024  16:23:04',
                                        icon: Icons.arrow_downward,
                                        typeColor: const Color(0xFFB259F2),
                                      ),
                                      _buildTransactionItem(
                                        type: 'Sent',
                                        amount: '-309.9866 RES',
                                        details: 'to 0xc344...fe82 | 13-11-2024  02:12:33',
                                        icon: Icons.arrow_upward,
                                        typeColor: const Color(0xFF16CECE),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFullWidthActionButton({
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          gradient: gradient,
          color: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: textColor ?? const Color(0xFF0E0E0E),
              fontSize: 18,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
