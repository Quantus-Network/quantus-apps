import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:async';
import 'account_profile.dart';

import 'package:resonance_network_wallet/src/rust/frb_generated.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubstrateService().initialize();
  await RustLib.init();
  runApp(const ResonanceWalletApp());
}

enum Mode {
  schorr,
  dilithium,
}

const mode = Mode.dilithium;

class ResonanceWalletApp extends StatelessWidget {
  const ResonanceWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Resonance Network Wallet',
      theme: ThemeData(
        primaryColor: const Color(0xFF6B46C1), // Deep purple
        scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Dark background
        cardColor: const Color(0xFF2D2D2D), // Slightly lighter dark for cards
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6B46C1), // Deep purple
          secondary: const Color(0xFF9F7AEA), // Lighter purple
          surface: const Color(0xFF2D2D2D),
          error: Colors.red.shade400,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B46C1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF9F7AEA),
            side: const BorderSide(color: Color(0xFF9F7AEA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF9F7AEA),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6B46C1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF6B46C1).withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9F7AEA)),
          ),
          filled: true,
          fillColor: const Color(0xFF2D2D2D),
        ),
      ),
      darkTheme: ThemeData(
        primaryColor: const Color(0xFF6B46C1),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        cardColor: const Color(0xFF2D2D2D),
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6B46C1),
          secondary: const Color(0xFF9F7AEA),
          surface: const Color(0xFF2D2D2D),
          error: Colors.red.shade400,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2D2D2D),
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B46C1),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF9F7AEA),
            side: const BorderSide(color: Color(0xFF9F7AEA)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF9F7AEA),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF6B46C1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: const Color(0xFF6B46C1).withOpacity(0.5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF9F7AEA)),
          ),
          filled: true,
          fillColor: const Color(0xFF2D2D2D),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const WalletInitializer(),
    );
  }
}

class WalletInitializer extends StatefulWidget {
  const WalletInitializer({super.key});

  @override
  _WalletInitializerState createState() => _WalletInitializerState();
}

class _WalletInitializerState extends State<WalletInitializer> {
  bool _loading = true;
  bool _walletExists = false;

  @override
  void initState() {
    super.initState();
    _checkWalletExists();
  }

  Future<void> _checkWalletExists() async {
    final prefs = await SharedPreferences.getInstance();
    final hasWallet = prefs.getBool('has_wallet') ?? false;

    setState(() {
      _walletExists = hasWallet;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_walletExists) {
      return const WalletMain();
    } else {
      return const WelcomeScreen();
    }
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [const Color(0xFF1A1A1A), const Color(0xFF6B46C1).withOpacity(0.8)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2D2D2D),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6B46C1).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet,
                size: 80,
                color: Color(0xFF9F7AEA),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Resonance Network',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Welcome to your REZ wallet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 60),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreateWalletScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B46C1),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create New Wallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ImportWalletScreen()),
                );
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF9F7AEA)),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Import Existing Wallet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9F7AEA),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  _ImportWalletScreenState createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final TextEditingController _mnemonicController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _importWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final input = _mnemonicController.text.trim();

      // Check if it's a derivation path
      if (input.startsWith('//')) {
        // No validation needed for derivation paths
        print('Using derivation path: $input');
      } else {
        // Validate mnemonic
        final words = input.split(' ').where((word) => word.isNotEmpty).toList();
        if (words.length != 12 && words.length != 24) {
          throw Exception('Mnemonic must be 12 or 24 words');
        }
      }

      if (mode == Mode.dilithium) {
        final walletInfo = await SubstrateService().generateWalletFromSeedDilithium(input);
        // Save wallet info
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_wallet', true);
        await prefs.setString('mnemonic', input);
        await prefs.setString('account_id', walletInfo.accountId);
      } else {
        final walletInfo = await SubstrateService().generateWalletFromSeed(input);
        // Save wallet info
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_wallet', true);
        await prefs.setString('mnemonic', input);
        await prefs.setString('account_id', walletInfo.accountId);
      }
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WalletMain()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Wallet'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter your 12 or 24 word mnemonic phrase',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _mnemonicController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF6B46C1)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: const Color(0xFF6B46C1).withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Color(0xFF9F7AEA)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2D2D2D),
                  hintText: 'Enter your mnemonic phrase...',
                  hintStyle: const TextStyle(color: Colors.grey),
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Enter all words separated by spaces',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.paste),
                    onPressed: () async {
                      final data = await Clipboard.getData('text/plain');
                      if (data != null && data.text != null) {
                        _mnemonicController.text = data.text!;
                      }
                    },
                    tooltip: 'Paste',
                  ),
                ],
              ),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const Spacer(),
              SafeArea(
                minimum: const EdgeInsets.only(bottom: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add test button for Alice's wallet
                    Center(
                      child: TextButton.icon(
                        onPressed: () {
                          if (mode == Mode.schorr) {
                            _mnemonicController.text = '//Alice';
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Alice development account loaded')),
                            );
                          } else {
                            _mnemonicController.text = CRYSTAL_ALICE;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Crystal Alice development account loaded')),
                            );
                          }
                        },
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Load Test Account (Crystal Alice)'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF9F7AEA),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _importWallet,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Import Wallet'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  _CreateWalletScreenState createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  String _mnemonic = '';
  bool _isLoading = false;
  bool _hasSavedMnemonic = false;

  @override
  void initState() {
    super.initState();
    _generateMnemonic();
  }

  Future<void> _generateMnemonic() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _mnemonic = await SubstrateService().generateMnemonic();
      final walletInfo = await SubstrateService().generateNewWallet(_mnemonic);
      print('Generated wallet address: ${walletInfo.accountId}');

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error generating mnemonic: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWalletAndContinue() async {
    try {
      final walletInfo = await SubstrateService().generateNewWallet(_mnemonic);

      if (mode == Mode.dilithium) {
        throw Exception('Dilithium is not supported yet');
      }
      // Save wallet info
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_wallet', true);
      await prefs.setString('mnemonic', _mnemonic);
      await prefs.setString('account_id', walletInfo.accountId);

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const WalletMain()),
        (route) => false,
      );
    } catch (e) {
      print('Error saving wallet: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving wallet: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Wallet'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Recovery Phrase',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Write down these words in order and keep them in a safe place. This is the only way to recover your wallet if you lose access.',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF6B46C1).withOpacity(0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _mnemonic,
                                style: const TextStyle(
                                  fontSize: 18,
                                  height: 1.5,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(text: _mnemonic));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Recovery phrase copied to clipboard')),
                                    );
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: const Text('Copy to Clipboard'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Never share your recovery phrase with anyone. Store it securely offline.',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Checkbox(
                              value: _hasSavedMnemonic,
                              onChanged: (value) {
                                setState(() {
                                  _hasSavedMnemonic = value ?? false;
                                });
                              },
                            ),
                            const Expanded(
                              child: Text(
                                'I have written down my recovery phrase and stored it securely',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _hasSavedMnemonic ? _saveWalletAndContinue : null,
                            child: const Text('Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class WalletMain extends StatefulWidget {
  const WalletMain({super.key});

  @override
  _WalletMainState createState() => _WalletMainState();
}

class _WalletMainState extends State<WalletMain> {
  String _accountId = '';
  BigInt _balance = BigInt.zero;
  final List<Transaction> _recentTransactions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getString('account_id') ?? '';

      // Fetch actual balance from the blockchain
      final balance = await SubstrateService().queryBalance(accountId);

      setState(() {
        _accountId = accountId;
        _balance = balance;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading wallet data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildBalanceDisplay() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Balance',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${SubstrateService().formatBalance(_balance)} REZ',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF9F7AEA),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resonance Wallet'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF9F7AEA)),
            onPressed: _loadWalletData,
          ),
          IconButton(
            icon: const Icon(Icons.person, color: Color(0xFF9F7AEA)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AccountProfilePage(accountId: _accountId),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B46C1)),
            ))
          : RefreshIndicator(
              onRefresh: _loadWalletData,
              color: const Color(0xFF6B46C1),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Account Card
                      Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF2D2D2D),
                                const Color(0xFF6B46C1).withOpacity(0.3),
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF6B46C1).withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_wallet,
                                        color: Color(0xFF9F7AEA),
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Resonance Network',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Text(
                                            _accountId,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                _buildBalanceDisplay(),
                                const SizedBox(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: () {
                                          _showReceiveDialog(context);
                                        },
                                        icon: const Icon(Icons.qr_code),
                                        label: const Text('Receive'),
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          side: const BorderSide(
                                            color: Color(0xFF9F7AEA),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => const SendScreen(),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.send, color: Colors.white, size: 20),
                                        label: const Text('Send'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                          backgroundColor: const Color(0xFF6B46C1),
                                          foregroundColor: Colors.white,
                                          elevation: 2,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.0),
                        child: Text(
                          'Recent Transactions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _recentTransactions.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.hourglass_empty,
                                      size: 48,
                                      color: const Color(0xFF9F7AEA).withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No transactions yet',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _recentTransactions.length,
                              itemBuilder: (context, index) {
                                final tx = _recentTransactions[index];
                                return TransactionListItem(
                                    transaction: tx, isReceived: tx.type == TransactionType.received);
                              },
                            ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  void _showReceiveDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Receive REZ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 280,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                      child: QrImageView(
                        data: _accountId,
                        version: QrVersions.auto,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your wallet address',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _accountId,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _accountId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy Address'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final bool isReceived;

  const TransactionListItem({
    super.key,
    required this.transaction,
    required this.isReceived,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isReceived ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(
          isReceived ? Icons.arrow_downward : Icons.arrow_upward,
          color: isReceived ? Colors.green : Colors.red,
        ),
      ),
      title: Text(
        isReceived ? 'Received' : 'Sent',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        transaction.otherParty,
        style: const TextStyle(fontSize: 12),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isReceived ? '+' : '-'}${SubstrateService().formatBalance(transaction.amount)} REZ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isReceived ? Colors.green : Colors.red,
            ),
          ),
          Text(
            transaction.status.name,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  _SendScreenState createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  final List<String> _recentRecipients = [];
  String? _recipientName;
  BigInt _maxBalance = BigInt.from(0);

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get the current account ID
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getString('account_id');

      if (accountId == null) {
        throw Exception('Wallet not found');
      }

      // Fetch actual balance from the blockchain
      final balance = await SubstrateService().queryBalance(accountId);

      setState(() {
        _maxBalance = balance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _lookupIdentity() async {
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      setState(() {
        _recipientName = null;
      });
      return;
    }

    // In a real app, you'd query the identity pallet on the blockchain
    // This is a placeholder implementation
    setState(() {
      _recipientName = recipient.length > 5 ? 'User ${recipient.substring(3, 7)}' : null;
    });
  }

  Future<void> _sendTransaction() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final recipient = _recipientController.text.trim();
      final amountText = _amountController.text.trim();

      if (recipient.isEmpty) {
        throw Exception('Please enter a recipient address');
      }

      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        throw Exception('Please enter a valid amount');
      }

      if (BigInt.from(amount) > _maxBalance) {
        throw Exception('Insufficient balance');
      }

      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You are about to send:'),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    '$amount REZ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('To:'),
              const SizedBox(height: 8),
              if (_recipientName != null)
                Text(
                  _recipientName!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              Text(
                recipient,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Network fee: 0.001 REZ',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get the sender's seed phrase
      final prefs = await SharedPreferences.getInstance();
      final senderSeed = prefs.getString('mnemonic');

      if (senderSeed == null) {
        throw Exception('Wallet data not found');
      }

      // Submit the transaction
      String hash;
      if (mode == Mode.dilithium) {
        hash = await SubstrateService().balanceTransfer2(
          senderSeed,
          recipient,
          amount,
        );
      } else {
        hash = await SubstrateService().balanceTransferSr25519(
          senderSeed,
          recipient,
          amount,
        );
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Transaction submitted successfully: $hash')),
      );

      Navigator.pop(context);
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send REZ'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBalance,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Recipient',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _recipientController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF6B46C1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: const Color(0xFF6B46C1).withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF9F7AEA)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2D2D2D),
                        hintText: 'Enter recipient address',
                        hintStyle: const TextStyle(color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.paste, color: Color(0xFF9F7AEA)),
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data != null && data.text != null) {
                              _recipientController.text = data.text!;
                              _lookupIdentity();
                            }
                          },
                        ),
                      ),
                      onChanged: (value) {
                        _lookupIdentity();
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              if (mode == Mode.dilithium) {
                                final bobWallet = await SubstrateService().generateWalletFromSeedDilithium(CRYSTAL_BOB);
                                _recipientController.text = bobWallet.accountId;
                                _lookupIdentity();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('$CRYSTAL_BOB development account loaded')),
                                );
                              } else {
                                final bobWallet = await SubstrateService().generateWalletFromSeed('//Bob');
                                _recipientController.text = bobWallet.accountId;
                                _lookupIdentity();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Bob development account loaded')),
                                );
                              }
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error loading Bob account: $e')),
                              );
                            }
                          },
                          icon: const Icon(Icons.bug_report, size: 16),
                          label: const Text('Use Crystal Bob (Dilithium Test)'),
                          // label: Text('Use Bob (Test)'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 0),
                            foregroundColor: const Color(0xFF9F7AEA),
                          ),
                        ),
                      ],
                    ),
                    if (_recipientName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Card(
                          color: const Color(0xFF2D2D2D),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: const Color(0xFF6B46C1).withOpacity(0.3),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.person, color: Color(0xFF9F7AEA)),
                                const SizedBox(width: 8),
                                Text(
                                  _recipientName!,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const Text(
                      'Amount',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _amountController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF6B46C1)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: const Color(0xFF6B46C1).withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: const BorderSide(color: Color(0xFF9F7AEA)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: const Color(0xFF2D2D2D),
                        hintText: 'Enter amount to send',
                        hintStyle: const TextStyle(color: Colors.grey),
                        suffix: const Text('REZ', style: TextStyle(color: Colors.grey)),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Available Balance:',
                            style: TextStyle(color: Colors.grey),
                          ),
                          Row(
                            children: [
                              Text(
                                '${SubstrateService().formatBalance(_maxBalance)} REZ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF9F7AEA),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () {
                                  _amountController.text = _maxBalance.toString();
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  minimumSize: const Size(0, 0),
                                ),
                                child: const Text('MAX'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _sendTransaction,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Send REZ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

enum TransactionType {
  sent,
  received,
}

enum TransactionStatus {
  pending,
  confirmed,
  failed,
}

class Transaction {
  final String id;
  final BigInt amount;
  final DateTime timestamp;
  final TransactionType type;
  final String otherParty;
  final TransactionStatus status;

  Transaction({
    required this.id,
    required this.amount,
    required this.timestamp,
    required this.type,
    required this.otherParty,
    required this.status,
  });
}

// test app for rust bindings below

// import 'package:flutter/material.dart';
// import 'package:resonance_network_wallet/src/rust/api/crypto.dart';
// import 'package:resonance_network_wallet/src/rust/frb_generated.dart';

// Future<void> main() async {
//   await RustLib.init();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     final keypair = crystalAlice();
//     final accountId = toAccountId(obj: keypair);

//     print("alice: ${keypair.publicKey}");
//     print("bob: ${crystalBob().publicKey}");
//     print("charlie: ${crystalCharlie().publicKey}");

//     return MaterialApp(
//       home: Scaffold(
//         appBar: AppBar(title: const Text('flutter_rust_bridge quickstart')),
//         body: Center(
//           child: Text('Action: Call Rust gen key\nResult: $accountId'),
//         ),
//       ),
//     );
//   }
// }
