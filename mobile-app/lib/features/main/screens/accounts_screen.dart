import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_mobile_wallet/features/components/snackbar_helper.dart';
import 'package:quantus_mobile_wallet/features/main/screens/account_settings_screen.dart';
import 'package:quantus_mobile_wallet/features/main/screens/create_account_screen.dart';
import 'package:quantus_mobile_wallet/models/wallet_state_manager.dart';

class AccountDetails {
  final Account account;
  final Future<Map<String, dynamic>> detailsFuture;

  AccountDetails({required this.account, required this.detailsFuture});
}

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final SettingsService _settingsService = SettingsService();
  final SubstrateService _substrateService = SubstrateService();
  final HumanReadableChecksumService _checksumService =
      HumanReadableChecksumService();
  final NumberFormattingService _formattingService = NumberFormattingService();

  List<AccountDetails> _accountDetails = [];
  Account? _activeAccount;
  bool _isLoading = true;
  bool _isCreatingAccount = false;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final accounts = await _settingsService.getAccounts();
      final activeAccount = await _settingsService.getActiveAccount();

      final detailsFutures = accounts.map((account) {
        try {
          final detailsFuture =
              Future.wait([
                _substrateService.queryBalance(account.accountId),
                _checksumService.getHumanReadableName(account.accountId),
              ]).then(
                (results) => {
                  'balance': results[0] as BigInt,
                  'checksumName': results[1] as String,
                },
              );
          return AccountDetails(account: account, detailsFuture: detailsFuture);
        } catch (e) {
          print('Error fetching details for ${account.accountId}: $e');
          // Return with default/error values if a single account fails
          return AccountDetails(
            account: account,
            detailsFuture: Future.value({
              'balance': BigInt.zero,
              'checksumName': 'Unavailable',
            }),
          );
        }
      }).toList();

      if (mounted) {
        setState(() {
          _accountDetails = detailsFutures;
          _activeAccount = activeAccount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load accounts: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _createNewAccount() async {
    setState(() {
      _isCreatingAccount = true;
    });
    try {
      final created = await Navigator.push<bool?>(
        context,
        MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
      );
      if (created == true) {
        await _loadAccounts(); // Reload accounts to show the new one
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingAccount = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/light_leak_effect_background.jpg'),
                fit: BoxFit.cover,
                opacity: 0.54,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildAppBar(),
                Expanded(child: _buildAccountsList()),
                // _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Text(
                'Your Accounts',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(width: 48), // to balance the back button
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_accountDetails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No accounts found.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 25),
            _buildCreateNewAccountButton(),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      itemCount: _accountDetails.length + 1,
      separatorBuilder: (context, index) => const SizedBox(height: 25),
      itemBuilder: (context, index) {
        if (index == _accountDetails.length) {
          return _buildCreateNewAccountButton();
        }
        final details = _accountDetails[index];
        final bool isActive =
            details.account.accountId == _activeAccount?.accountId;
        return _buildAccountListItem(details, isActive, index);
      },
    );
  }

  Widget _buildCreateNewAccountButton() {
    return InkWell(
      onTap: _isCreatingAccount ? null : _createNewAccount,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          color: Colors.black.useOpacity(0.50),
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0xFFE6E6E6)),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (_isCreatingAccount)
              const CircularProgressIndicator(color: Colors.white)
            else
              const Text(
                'Create New Account',
                style: TextStyle(
                  color: Color(0xFFE6E6E6),
                  fontSize: 18,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Widget _buildTag(String text, Color color) {
  //   return Container(
  //     padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
  //     decoration: ShapeDecoration(
  //       color: color,
  //       shape: RoundedRectangleBorder(borderRadius:
  // BorderRadius.circular(2)),
  //     ),
  //     child: Text(
  //       text,
  //       textAlign: TextAlign.center,
  //       style: const TextStyle(color: Colors.black, fontSize: 10, fontFamily:
  // 'Fira Code', fontWeight: FontWeight.w400),
  //     ),
  //   );
  // }

  Widget _buildAccountListItem(
    AccountDetails details,
    bool isActive,
    int index,
  ) {
    final account = details.account;

    return InkWell(
      onTap: () async {
        if (!isActive) {
          final walletStateManager = Provider.of<WalletStateManager>(
            context,
            listen: false,
          );
          await walletStateManager.switchAccount(account);
          if (mounted) Navigator.pop(context);
        }
      },
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              height: 105,
              decoration: ShapeDecoration(
                color: isActive ? Colors.white : Colors.black.useOpacity(0.65),
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 1,
                    color: Colors.white.useOpacity(0.15),
                  ),
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    'assets/res_icon.svg',
                    width: 32,
                    height: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FutureBuilder<Map<String, dynamic>>(
                      future: details.detailsFuture,
                      builder: (context, snapshot) {
                        String formattedBalance;
                        String humanChecksum;
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          formattedBalance = 'loading balance...';
                          humanChecksum = '';
                        } else {
                          final balance =
                              snapshot.data?['balance'] as BigInt? ??
                              BigInt.zero;
                          final checksumName =
                              snapshot.data?['checksumName'] as String? ??
                              'Unavailable';
                          formattedBalance = _formattingService.formatBalance(
                            balance,
                          );
                          humanChecksum = checksumName;
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // demo code for tags bug not yet implemented,
                            // they look good though.
                            // if (!isActive && index == 1) ...[
                            //   Row(
                            //     children: [
                            //       _buildTag(
                            //         'Recovery',
                            //         const Color(0xFF16CECE),
                            //       ),
                            //       const SizedBox(width: 8),
                            //       _buildTag(
                            //         'Anti-Theft',
                            //         const Color(0xFFFADC34),
                            //       ),
                            //     ],
                            //   ),
                            //   const SizedBox(height: 6),
                            // ],
                            Text(
                              account.name,
                              style: TextStyle(
                                color: isActive ? Colors.black : Colors.white,
                                fontSize: 14,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              humanChecksum,
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFF06A8A8)
                                    : const Color(0xFF16CECE),
                                fontSize: 12,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  AddressFormattingService.formatAddress(
                                    account.accountId,
                                  ),
                                  style: TextStyle(
                                    color: isActive
                                        ? const Color(0xFF313131)
                                        : Colors.white.useOpacity(0.99),
                                    fontSize: 10,
                                    fontFamily: 'Fira Code',
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                InkWell(
                                  onTap: () {
                                    Clipboard.setData(
                                      ClipboardData(text: account.accountId),
                                    );

                                    showTopSnackBar(
                                      context,
                                      icon: Container(
                                        width: 36,
                                        height: 36,
                                        decoration: const ShapeDecoration(
                                          color: Color(0xFF494949),
                                          shape: OvalBorder(),
                                        ),
                                        alignment: Alignment.center,
                                        child: SvgPicture.asset(
                                          'assets/copy_icon.svg',
                                          width: 16,
                                          height: 16,
                                        ),
                                      ),
                                      title: 'Copied!',
                                      message:
                                          'Address '
                                          'copied to clipboard',
                                    );
                                  },
                                  child: Icon(
                                    Icons.copy,
                                    size: 14,
                                    color: isActive
                                        ? const Color(0xFF313131)
                                        : Colors.white.useOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: formattedBalance,
                                    style: TextStyle(
                                      color: isActive
                                          ? const Color(0xFF313131)
                                          : const Color(0xFFE6E6E6),
                                      fontSize: 12,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' ${AppConstants.tokenSymbol}',
                                    style: TextStyle(
                                      color: isActive
                                          ? const Color(0xFF313131)
                                          : const Color(0xFFE6E6E6),
                                      fontSize: 10,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 0),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: SvgPicture.asset(
              'assets/settings_icon_off.svg',
              width: 21,
              height: 21,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () async {
              final accountDetails = await details.detailsFuture;
              final checksumName = accountDetails['checksumName'] as String;
              final balance = accountDetails['balance'] as BigInt;
              if (!mounted) return;
              final result = await Navigator.push<bool?>(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountSettingsScreen(
                    account: account,
                    balance:
                        // ignore: lines_longer_than_80_chars
                        '${_formattingService.formatBalance(balance)} ${AppConstants.tokenSymbol}',
                    checksumName: checksumName,
                  ),
                ),
              );
              if (result == true) {
                _loadAccounts();
                if (mounted) {
                  Provider.of<WalletStateManager>(
                    context,
                    listen: false,
                  ).refreshActiveAccount();
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
