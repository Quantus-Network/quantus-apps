import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/features/main/screens/account_settings_screen.dart';

class AccountDetails {
  final Account account;
  final BigInt balance;
  final String checksumName;

  AccountDetails({required this.account, required this.balance, required this.checksumName});
}

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  final SettingsService _settingsService = SettingsService();
  final AccountsService _accountsService = AccountsService();
  final SubstrateService _substrateService = SubstrateService();
  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();
  final NumberFormattingService _formattingService = NumberFormattingService();

  List<AccountDetails> _accountDetails = [];
  Account? _activeAccount;
  bool _isLoading = true;
  bool _isCreatingAccount = false;

  @override
  void initState() {
    super.initState();
    _checksumService.initialize().then((_) {
      _loadAccounts();
    });
  }

  Future<void> _loadAccounts() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final accounts = await _settingsService.getAccounts();
      final activeAccount = await _settingsService.getActiveAccount();

      final detailsFutures = accounts.map((account) async {
        try {
          final balance = await _substrateService.queryBalance(account.accountId);
          final checksumName = await _checksumService.getHumanReadableName(account.accountId);
          return AccountDetails(account: account, balance: balance, checksumName: checksumName);
        } catch (e) {
          print('Error fetching details for ${account.accountId}: $e');
          // Return with default/error values if a single account fails
          return AccountDetails(account: account, balance: BigInt.zero, checksumName: 'Unavailable');
        }
      }).toList();

      final details = await Future.wait(detailsFutures);

      if (mounted) {
        setState(() {
          _accountDetails = details;
          _activeAccount = activeAccount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to load accounts: ${e.toString()}')));
      }
    }
  }

  Future<void> _createNewAccount() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Account'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'Account Name (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(nameController.text), child: const Text('Create')),
        ],
      ),
    );

    if (name != null) {
      setState(() {
        _isCreatingAccount = true;
      });
      try {
        await _accountsService.createNewAccount(name);
        await _loadAccounts(); // Reload accounts to show the new one
      } catch (e) {
        // Handle error, maybe show a snackbar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create account: $e')));
        }
      } finally {
        if (mounted) {
          setState(() {
            _isCreatingAccount = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/light_leak_effect_background.jpg'),
              fit: BoxFit.cover,
              opacity: 0.54,
            ),
          ),
          child: Column(
            children: [
              _buildAppBar(),
              Expanded(child: _buildAccountsList()),
              _buildFooter(),
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
            'Your Accounts',
            style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'Fira Code'),
          ),
          const SizedBox(width: 48), // to balance the back button
        ],
      ),
    );
  }

  Widget _buildAccountsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (_accountDetails.isEmpty) {
      return const Center(
        child: Text('No accounts found.', style: TextStyle(color: Colors.white70)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      itemCount: _accountDetails.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final details = _accountDetails[index];
        final bool isActive = details.account.accountId == _activeAccount?.accountId;
        return _buildAccountListItem(details, isActive);
      },
    );
  }

  Widget _buildAccountListItem(AccountDetails details, bool isActive) {
    final account = details.account;
    return InkWell(
      onTap: () async {
        if (!isActive) {
          final walletStateManager = Provider.of<WalletStateManager>(context, listen: false);
          await walletStateManager.switchAccount(account);
          await _loadAccounts();
          if (mounted) Navigator.pop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.black.useOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: isActive ? null : Border.all(color: Colors.white.useOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Placeholder for account icon
            SvgPicture.asset(
              'assets/quantus_icon.svg',
              width: 40,
              height: 40,
              colorFilter: ColorFilter.mode(isActive ? Colors.black : Colors.white, BlendMode.srcIn),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: TextStyle(
                      color: isActive ? Colors.black : Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(details.checksumName, style: TextStyle(color: isActive ? Colors.black54 : Colors.white70)),
                  const SizedBox(height: 4),
                  Text(
                    '${_formattingService.formatBalance(details.balance)} ${AppConstants.tokenSymbol}',
                    style: TextStyle(color: isActive ? Colors.black54 : Colors.white70, fontFamily: 'Fira Code'),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.settings, color: isActive ? Colors.black : Colors.white),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AccountSettingsScreen(
                      account: account,
                      balance: '${_formattingService.formatBalance(details.balance)} ${AppConstants.tokenSymbol}',
                      checksumName: details.checksumName,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _isCreatingAccount ? null : _createNewAccount,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
              backgroundColor: Colors.blueAccent,
            ),
            child: _isCreatingAccount
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('Create New Account', style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // TODO: Implement lock functionality
            },
            child: const Text('Lock', style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
