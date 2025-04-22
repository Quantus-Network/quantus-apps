import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:resonance_network_wallet/account_profile.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/models/transaction_model.dart';
import 'package:resonance_network_wallet/core/models/transaction_type.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  Future<WalletData?>? _walletDataFuture;
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _walletDataFuture = _loadWalletData();
  }

  Future<WalletData?> _loadWalletData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getString('account_id');

      if (accountId == null || accountId.isEmpty) {
        print("Error: No account ID found in SharedPreferences");
        throw Exception("Account ID not found");
      }
      _accountId = accountId;
      final walletName = prefs.getString('wallet_name') ?? 'Grain-Flash-Something';
      final balance = await _substrateService.queryBalance(accountId);
      return WalletData(accountId: accountId, walletName: walletName, balance: balance);
    } catch (e) {
      print("Error loading wallet data: $e");
      throw Exception('Failed to load wallet data: $e');
    }
  }

  String _truncateAddress(String address, {int prefixLength = 6, int suffixLength = 6}) {
    if (address.length <= prefixLength + suffixLength + 3) {
      return address;
    }
    return '${address.substring(0, prefixLength)}...${address.substring(address.length - suffixLength)}';
  }

  Widget _buildActionButton({
    required Widget iconWidget,
    required String label,
    required Color borderColor,
    required VoidCallback onPressed,
    bool disabled = false,
  }) {
    final color = disabled ? Colors.white.withOpacity(0.5) : Colors.white;
    final bgColor = Colors.black.withOpacity(166 / 255.0);
    final effectiveBorderColor = disabled ? borderColor.withOpacity(0.5) : borderColor;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
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
            child: FutureBuilder<WalletData?>(
              future: _walletDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                  return const Center(
                    child: Text(
                      'Error loading wallet data.',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                }

                final walletData = snapshot.data!;

                return Column(
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
                                      builder: (context) => AccountProfilePage(accountId: _accountId!),
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
                            // decoration: ShapeDecoration(
                            //   color: Colors.black.useOpacity(0.5),
                            //   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            // ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SvgPicture.asset(
                                  'assets/active_dot.svg',
                                  width: 13,
                                  height: 13,
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  decoration: ShapeDecoration(
                                    color: Colors.black.useOpacity(0.5),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                  ),
                                  child: Text(
                                    walletData.walletName,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w400,
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
                                text: _substrateService.formatBalance(walletData.balance),
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
                          iconWidget: SvgPicture.asset('assets/send_icon.svg'),
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
                            Navigator.pushNamed(context, '/receive');
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
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: ShapeDecoration(
                          color: Colors.black.withOpacity(64 / 255.0),
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
                            Expanded(
                              child: ListView(
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
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
