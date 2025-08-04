import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/snackbar_helper.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/account_settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/create_account_screen.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final HumanReadableChecksumService _checksumService =
      HumanReadableChecksumService();
  final NumberFormattingService _formattingService = NumberFormattingService();

  bool _isCreatingAccount = false;

  Future<void> _createNewAccount() async {
    setState(() {
      _isCreatingAccount = true;
    });
    try {
      await Navigator.push<bool?>(
        context,
        MaterialPageRoute(builder: (context) => const CreateAccountScreen()),
      );
      // Providers will automatically refresh when a new account is added
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
      appBar: const WalletAppBar(title: 'Your Accounts'),
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
                // Row 2: Accounts List (takes remaining space, scrollable)
                Expanded(child: _buildAccountsList()),
                // Row 3: Create Button (takes needed space)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: _buildCreateNewAccountButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    final accountsAsync = ref.watch(accountsProvider);
    final activeAccountAsync = ref.watch(activeAccountProvider);

    return accountsAsync.when(
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (error, _) => Center(
        child: Text(
          'Failed to load accounts: $error',
          style: const TextStyle(color: Colors.white70),
        ),
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return const Center(
            child: Text(
              'No accounts found.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return activeAccountAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (error, _) => Center(
            child: Text(
              'Failed to load active account: $error',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          data: (activeAccount) {
            return ListView.separated(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              itemCount: accounts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 25),
              itemBuilder: (context, index) {
                final account = accounts[index];
                final bool isActive =
                    account.accountId == activeAccount?.accountId;
                return _buildAccountListItem(account, isActive, index);
              },
            );
          },
        );
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

  Widget _buildAccountListItem(Account account, bool isActive, int index) {
    return InkWell(
      onTap: () async {
        if (!isActive) {
          await ref
              .read(activeAccountProvider.notifier)
              .setActiveAccount(account);
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
                    child: Consumer(
                      builder: (context, ref, child) {
                        final balanceAsync = ref.watch(
                          balanceProviderFamily(account.accountId),
                        );

                        return FutureBuilder<String>(
                          future: _checksumService.getHumanReadableName(
                            account.accountId,
                          ),
                          builder: (context, checksumSnapshot) {
                            final humanChecksum = checksumSnapshot.data ?? '';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.name,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.black
                                        : Colors.white,
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
                                          ClipboardData(
                                            text: account.accountId,
                                          ),
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
                                balanceAsync.when(
                                  loading: () => Text(
                                    'loading balance...',
                                    style: TextStyle(
                                      color: isActive
                                          ? const Color(0xFF313131)
                                          : const Color(0xFFE6E6E6),
                                      fontSize: 12,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  error: (error, _) => Text(
                                    'error loading',
                                    style: TextStyle(
                                      color: isActive
                                          ? const Color(0xFF313131)
                                          : const Color(0xFFE6E6E6),
                                      fontSize: 12,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  data: (balance) => Text.rich(
                                    TextSpan(
                                      children: [
                                        TextSpan(
                                          text: _formattingService
                                              .formatBalance(balance),
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
                                ),
                              ],
                            );
                          },
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
              // Get current data from providers
              final balanceAsync = ref.read(
                balanceProviderFamily(account.accountId),
              );
              final checksumName = await _checksumService.getHumanReadableName(
                account.accountId,
              );

              balanceAsync.when(
                loading: () {
                  // Show loading or handle appropriately
                },
                error: (error, _) {
                  // Handle error
                },
                data: (balance) async {
                  if (!mounted) return;
                  await Navigator.push<bool?>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AccountSettingsScreen(
                        account: account,
                        balance:
                            '${_formattingService.formatBalance(balance)}'
                            ' ${AppConstants.tokenSymbol}',
                        checksumName: checksumName,
                      ),
                    ),
                  );
                  // Providers will automatically refresh if needed
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
