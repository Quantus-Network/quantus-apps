import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io'; // Import for SocketException
import 'dart:async'; // Import for Future.timeout / TimeoutException
import 'package:resonance_network_wallet/features/main/screens/account_profile.dart';
import 'package:resonance_network_wallet/core/constants/app_constants.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/core/services/settings_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/core/services/number_formatting_service.dart';
import 'package:resonance_network_wallet/features/main/screens/welcome_screen.dart';
import 'package:resonance_network_wallet/core/helpers/snackbar_helper.dart';
import 'package:resonance_network_wallet/core/services/chain_history_service.dart';
import 'package:resonance_network_wallet/features/main/screens/send_screen.dart';

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
  final SettingsService _settingsService = SettingsService();
  final ChainHistoryService _chainHistoryService = ChainHistoryService();

  Future<WalletData?>? _walletDataFuture;
  String? _accountId;
  List<Transfer> _transfers = [];
  bool _isHistoryLoading = true;
  String? _historyError;

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
    BigInt? balance;
    const Duration networkTimeout = Duration(seconds: 15);

    try {
      accountId = await _settingsService.getAccountId();

      if (accountId == null || accountId.isEmpty) {
        throw Exception('Account ID not found');
      }
      _accountId = accountId;

      print('Attempting initial balance query for $accountId...');
      balance = await _substrateService.queryBalance(accountId).timeout(networkTimeout);
      print('Initial balance query successful.');

      // Fetch transaction history after successful wallet data load
      await _fetchTransactionHistory();
    } catch (e) {
      print('Initial load/query failed: $e');

      bool isConnectionError = e is SocketException ||
          e is TimeoutException ||
          e.toString().contains('Connection refused') ||
          e.toString().contains('WebSocket');

      if (isConnectionError && accountId != null) {
        print('Connection error detected. Attempting reconnect and retry...');
        try {
          await _substrateService.reconnect();
          balance = await _substrateService.queryBalance(accountId).timeout(networkTimeout);
          print('Balance query successful after reconnect.');
        } catch (retryError) {
          print('Retry failed after reconnect: $retryError');
          throw Exception('Failed to load wallet data after retry: $retryError');
        }
      } else {
        print('Error was not connection-related or accountId is null. Rethrowing.');
        throw Exception('Failed to load wallet data: $e');
      }
    }

    return WalletData(accountId: accountId, walletName: '', balance: balance);
  }

  Future<void> _fetchTransactionHistory() async {
    print('fetchTransactionHistory: $_accountId');
    if (_accountId == null) return; // Ensure accountId is available

    setState(() {
      _isHistoryLoading = true;
      _historyError = null;
    });

    try {
      final fetchedTransfers = await _chainHistoryService.fetchTransfers(accountId: _accountId!);
      setState(() {
        _transfers = fetchedTransfers;
        _isHistoryLoading = false;
      });
      print('fetchedTransfers: ${_transfers.length}');
    } catch (e) {
      print('Error fetching transaction history: $e');
      setState(() {
        _historyError = 'Failed to load transaction history.';
        _isHistoryLoading = false;
      });
      // Optionally show a snackbar or other UI indication for the error
    }
  }

  // Helper to format the address (now just returns the full address)
  String _formatAddress(String address) {
    return address; // Return the full address, let Text widget handle overflow
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
    required Widget iconWidget,
    required Color typeColor,
    required String rawTimestamp,
  }) {
    final String iconAsset;
    final Color effectiveTypeColor;
    if (type == 'Sent') {
      iconAsset = 'assets/send_icon_1.svg';
      effectiveTypeColor = const Color(0xFF16CECE);
    } else {
      iconAsset = 'assets/receive_icon.svg';
      effectiveTypeColor = const Color(0xFFB259F2);
    }

    String formattedTimestamp = 'Invalid Timestamp';
    try {
      final dateTime = DateTime.parse(rawTimestamp).toLocal();
      final day = dateTime.day.toString().padLeft(2, '0');
      final month = dateTime.month.toString().padLeft(2, '0');
      final year = dateTime.year;
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      final second = dateTime.second.toString().padLeft(2, '0');
      formattedTimestamp = '$day-$month-$year $hour:$minute:$second';
    } catch (e) {
      print('Error formatting timestamp $rawTimestamp: $e');
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 21,
              height: 17,
              child: SvgPicture.asset(
                iconAsset,
                colorFilter: ColorFilter.mode(effectiveTypeColor, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: type,
                          style: TextStyle(
                            color: effectiveTypeColor,
                            fontSize: 14,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        TextSpan(
                          text: ' ' + amount,
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
                    '${details} | $formattedTimestamp',
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

  Widget _buildHistorySection() {
    if (_isHistoryLoading) {
      return const SliverFillRemaining(
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_historyError != null) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            _historyError!,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    } else if (_transfers.isEmpty) {
      return const SliverFillRemaining(
        child: Center(
          child: Text(
            'No transactions found.',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    } else {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final transfer = _transfers[index];
            final isSend = transfer.from == _accountId;
            final type = isSend ? 'Sent' : 'Received';
            final details = isSend ? 'to ${_formatAddress(transfer.to)}' : 'from ${_formatAddress(transfer.from)}';
            final amountDisplay =
                '${isSend ? '-' : '+'}${_formattingService.formatBalance(BigInt.parse(transfer.amount))} ${AppConstants.tokenSymbol}';

            return _buildTransactionItem(
              type: type,
              amount: amountDisplay,
              details: details,
              iconWidget: Container(),
              typeColor: Colors.transparent,
              rawTimestamp: transfer.timestamp,
            );
          },
          childCount: _transfers.length,
        ),
      );
    }
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
      print('Error during logout: $e');
      if (mounted) {
        showTopSnackBar(
          context,
          title: 'Error',
          message: 'Logout failed: ${e.toString()}',
          icon: buildErrorIcon(),
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
            image: AssetImage('assets/light_leak_effect_background.jpg'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
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
                                  style: TextStyle(color: Colors.white.useOpacity(0.7), fontSize: 14),
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
                              backgroundColor: Colors.white.useOpacity(0.2),
                              textColor: Colors.white.useOpacity(0.8),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                final walletData = snapshot.data!;
                // Use the full address
                final displayAddress = _formatAddress(walletData.accountId);

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadWalletDataAndSetFuture();
                    await _walletDataFuture;
                  },
                  color: const Color(0xFF0CE6ED), // Match your app's accent color
                  backgroundColor: Colors.black,
                  child: CustomScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(), // Ensures pull-to-refresh works even when content fits screen
                    slivers: [
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SvgPicture.asset('assets/quantus_logo_hz.svg', height: 40),
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
                                        Image.asset(
                                          'assets/active_dot.png',
                                          width: 20,
                                          height: 20,
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
                                              displayAddress,
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
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: ShapeDecoration(
                                color: Colors.black.withAlpha(64),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Recent Transactions',
                                    style: TextStyle(
                                      color: Color(0xFFE6E6E6),
                                      fontSize: 14,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: 18),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      _buildHistorySection(),
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
