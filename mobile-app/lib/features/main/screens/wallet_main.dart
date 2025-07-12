import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:resonance_network_wallet/features/main/services/wallet_state_manager.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/main/screens/account_profile.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/transactions_screen.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletMain extends StatefulWidget {
  const WalletMain({super.key});

  @override
  State<WalletMain> createState() => _WalletMainState();
}

class _WalletMainState extends State<WalletMain> {
  final SettingsService _settingsService = SettingsService();
  final NumberFormattingService _formattingService = NumberFormattingService();
  String? _accountId;

  @override
  void initState() {
    super.initState();
    _initAccountId();
  }

  Future<void> _initAccountId() async {
    _accountId = await _settingsService.getAccountId();
    if (_accountId != null && mounted) {
      Provider.of<WalletStateManager>(context, listen: false).loadInitialData();
    }
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
      finalIconWidget = SvgPicture.asset((iconWidget.bytesLoader as SvgAssetLoader).assetName, width: 20, height: 20);
    } else if (iconWidget is Icon) {
      finalIconWidget = Icon(iconWidget.icon, color: color, size: 20);
    } else if (iconWidget is Image) {
      finalIconWidget = SizedBox(width: 20, height: 20, child: iconWidget);
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
                style: TextStyle(color: color, fontSize: 10, fontFamily: 'Inter', fontWeight: FontWeight.w300),
              ),
            ],
          ),
        ),
      ),
    );
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Consumer<WalletStateManager>(
              builder: (context, manager, child) {
                final balance = manager.currentBalance;
                final recentTxs = manager.transactions.take(5).toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    await manager.loadInitialData();
                  },
                  color: const Color(0xFF0CE6ED),
                  backgroundColor: Colors.black,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SvgPicture.asset('assets/quantus_logo_hz.svg', height: 40),
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
                            ),
                            const SizedBox(height: 40),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                InkWell(
                                  onTap: () {
                                    if (_accountId != null) {
                                      Clipboard.setData(ClipboardData(text: _accountId!));
                                      showTopSnackBar(
                                        context,
                                        title: 'Copied!',
                                        message: 'Account ID copied to clipboard',
                                      );
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(5),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Image.asset('assets/active_dot.png', width: 20, height: 20),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                            decoration: ShapeDecoration(
                                              color: Colors.black.useOpacity(0.5),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            ),
                                            child: Text(
                                              _formatAddress(_accountId ?? ''),
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
                                        text: _formattingService.formatBalance(balance),
                                        style: const TextStyle(
                                          color: Color(0xFFE6E6E6),
                                          fontSize: 40,
                                          fontFamily: 'Fira Code',
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const TextSpan(
                                        text: ' ${AppConstants.tokenSymbol}',
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
                                  iconWidget: SvgPicture.asset('assets/swap_icon.svg'),
                                  label: 'SWAP',
                                  borderColor: const Color(0xFF0AD4F6),
                                  onPressed: () {},
                                  disabled: true,
                                ),
                                _buildActionButton(
                                  iconWidget: SvgPicture.asset('assets/bridge_icon.svg'),
                                  label: 'BRIDGE',
                                  borderColor: const Color(0xFF0AD4F6),
                                  onPressed: () {},
                                  disabled: true,
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(left: 10.0, bottom: 10.0),
                              child: Text(
                                'Recent Transactions',
                                style: TextStyle(
                                  color: Color(0xFFE6E6E6),
                                  fontSize: 14,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            RecentTransactionsList(transactions: recentTxs, currentWalletAddress: _accountId ?? ''),
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0, right: 12.0),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (context) => TransactionsScreen()),
                                    );
                                  },
                                  child: Text(
                                    'Transaction History →',
                                    style: TextStyle(
                                      color: Colors.white.useOpacity(0.80),
                                      fontSize: 12,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
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

  String _formatAddress(String address) {
    return address; // Return the full address, let Text widget handle overflow
  }
}
