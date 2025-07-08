import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'dart:io';
import 'dart:async';
import 'package:resonance_network_wallet/features/main/screens/account_profile.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/transactions_screen.dart';
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
  final SettingsService _settingsService = SettingsService();
  final ChainHistoryService _chainHistoryService = ChainHistoryService();

  Future<WalletData?>? _walletDataFuture;
  String? _accountId;
  List<TransactionEvent> _transfers = [];
  bool _isHistoryLoading = true;
  String? _historyError;

  // Pagination state
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _transactionsPerPage = 10;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadWalletDataAndSetFuture();
    // _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreTransactions();
    }
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

      bool isConnectionError =
          e is SocketException ||
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

  Future<void> _loadMoreTransactions() async {
    if (!_hasMore || _isLoadingMore || _isHistoryLoading) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final result = await _chainHistoryService.fetchTransfers(
        accountId: _accountId!,
        limit: _transactionsPerPage,
        offset: _offset,
      );

      setState(() {
        _transfers.addAll(result.combinedTransfers);
        _hasMore = result.hasMore;
        _offset = result.nextOffset;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _historyError = 'Failed to load more transactions.';
      });
    }
  }

  Future<void> _fetchTransactionHistory() async {
    print('fetchTransactionHistory: $_accountId');
    if (_accountId == null) return;

    setState(() {
      _isHistoryLoading = true;
      _historyError = null;
      // Reset pagination state for main screen.
      // We are fetching a fixed number of items here.
      _offset = 0;
      _hasMore = true; // Assume there might be more for the "See More" page
      _transfers = [];
    });

    try {
      final result = await _chainHistoryService.fetchTransfers(
        accountId: _accountId!,
        limit: 5, // Fetch only 5 transactions for the main screen
        offset: 0,
      );

      setState(() {
        _transfers = result.combinedTransfers;
        // _hasMore should reflect if there are more than 5,
        // which can be inferred if the result length is 5 (the limit)
        _hasMore = result.hasMore;
        _isHistoryLoading = false;
      });
      print('fetchedTransfers: ${_transfers.length}');
    } catch (e) {
      print('Error fetching transaction history: $e');
      setState(() {
        _historyError = 'Failed to load transaction history.';
        _isHistoryLoading = false;
      });
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

  Widget _buildHistorySection() {
    if (_isHistoryLoading) {
      return Container(
        width: 321,
        padding: const EdgeInsets.all(10),
        decoration: ShapeDecoration(
          color: Colors.black.withAlpha(64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0CE6ED))),
          ),
        ),
      );
    }

    if (_historyError != null) {
      return Container(
        width: 321,
        padding: const EdgeInsets.all(20),
        decoration: ShapeDecoration(
          color: Colors.black.withAlpha(64),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _historyError!,
                style: const TextStyle(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: _fetchTransactionHistory, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 10.0, bottom: 10.0),
          child: Text(
            'Reversible Transactions',
            style: TextStyle(
              color: Color(0xFFE6E6E6),
              fontSize: 14,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        RecentTransactionsList(transactions: _transfers, currentWalletAddress: _accountId!),
        if (true || _hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 12.0, right: 12.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TransactionsScreen(initialAccountId: _accountId!)),
                  );
                },
                child: Text(
                  'Transaction History →',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.80),
                    fontSize: 12,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
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
      print('Error during logout: $e');
      if (mounted) {
        showTopSnackBar(context, title: 'Error', message: 'Logout failed: ${e.toString()}', icon: buildErrorIcon());
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
                final displayAddress = _formatAddress(walletData.accountId);

                return RefreshIndicator(
                  onRefresh: () async {
                    _loadWalletDataAndSetFuture();
                    await _walletDataFuture;
                  },
                  color: const Color(0xFF0CE6ED),
                  backgroundColor: Colors.black,
                  child: CustomScrollView(
                    controller: _scrollController,
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
                                              displayAddress,
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
                          ],
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildHistorySection()),
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
