import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:human_checksum/human_checksum.dart';
import 'package:resonance_network_wallet/features/main/screens/create_wallet_screen.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/src/rust/frb_generated.dart';

// --- Top-level functions for compute ---

// Helper to ensure RustLib is initialized in the isolate
Future<void> _ensureRustInitialized() async {
  // Needs error handling if init can fail
  await RustLib.init();
}

Future<String> _generateMnemonicIsolate(dynamic _) async {
  await _ensureRustInitialized();
  // Note: Instantiating SubstrateService here might be problematic
  // if it depends on main isolate state. Let's try it first.
  return await SubstrateService().generateMnemonic();
}

Future<DilithiumWalletInfo> _generateWalletFromSeedIsolate(String mnemonic) async {
  await _ensureRustInitialized();
  return await SubstrateService().generateWalletFromSeed(mnemonic);
}

Future<List<String>> _generateChecksumIsolate(Map<String, dynamic> params) async {
  // Checksum might not need Rust init, but good practice if unsure
  // await _ensureRustInitialized();
  final List<String> wordList = params['wordList'] as List<String>;
  final String accountId = params['accountId'] as String;
  // HumanChecksum itself is likely pure Dart and safe
  HumanChecksum humanChecksum = HumanChecksum(wordList);
  // addressToChecksum might be pure Dart, or might call Rust - assume pure Dart for now
  return humanChecksum.addressToChecksum(accountId);
}
// --- End Top-level functions ---

class CreateWalletCheckPhraseScreen extends StatefulWidget {
  const CreateWalletCheckPhraseScreen({super.key});

  @override
  State<CreateWalletCheckPhraseScreen> createState() => _CreateWalletCheckPhraseScreenState();
}

class _CreateWalletCheckPhraseScreenState extends State<CreateWalletCheckPhraseScreen> {
  String _walletName = 'Loading...';
  List<String> _wordList = [];
  bool _isLoading = true;
  String? _error;
  String? _mnemonic;
  DilithiumWalletInfo? _walletInfo;
  late final Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeWallet();
  }

  Future<void> _initializeWallet() async {
    try {
      // Load word list (usually fast)
      final String wordListContent = await rootBundle.loadString('assets/text/crypto_checksum_bip39.txt');
      _wordList = wordListContent.split('\n').where((word) => word.isNotEmpty).toList();

      if (_wordList.isEmpty) {
        throw Exception('Word list is empty');
      }

      // Generate mnemonic and wallet IN ISOLATE
      _mnemonic = await compute(_generateMnemonicIsolate, 0); // Pass dummy arg
      if (_mnemonic == null) throw Exception("Mnemonic generation failed");

      _walletInfo = await compute(_generateWalletFromSeedIsolate, _mnemonic!);
      if (_walletInfo == null) throw Exception("Wallet generation failed");

      // Generate checksum IN ISOLATE
      final checksumParams = {'wordList': _wordList, 'accountId': _walletInfo!.accountId};
      final List<String> words = await compute(_generateChecksumIsolate, checksumParams);

      // Update state ONLY if mounted and successful
      if (mounted) {
        setState(() {
          _walletName = words.join('-');
        });
      }

      debugPrint('Initialization successful');
      debugPrint('Generated mnemonic: $_mnemonic');
      debugPrint('Generated wallet info: ${_walletInfo!.accountId} ${_walletInfo!.keypair.publicKey}');
      debugPrint('Generated words: $words');
    } catch (e) {
      debugPrint('Initialization failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize wallet: $e';
        });
      }
    }
  }

  Future<void> _regenerateWalletName() async {
    if (!mounted) return;

    setState(() {
      _error = null;
      _walletName = "Regenerating...";
    });

    try {
      // Re-run the generation logic IN ISOLATE
      _mnemonic = await compute(_generateMnemonicIsolate, 0); // Pass dummy arg
      if (_mnemonic == null) throw Exception("Mnemonic regeneration failed");

      _walletInfo = await compute(_generateWalletFromSeedIsolate, _mnemonic!);
      if (_walletInfo == null) throw Exception("Wallet regeneration failed");

      final checksumParams = {'wordList': _wordList, 'accountId': _walletInfo!.accountId};
      final List<String> words = await compute(_generateChecksumIsolate, checksumParams);

      if (mounted) {
        setState(() {
          _walletName = words.join('-');
        });
      }
      debugPrint('Regeneration successful $_mnemonic');
    } catch (e) {
      debugPrint('Regeneration failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to regenerate: $e';
          _walletName = "Error";
        });
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
            image: AssetImage('assets/BG_00 1.png'),
            fit: BoxFit.cover,
            opacity: 0.54,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FutureBuilder<void>(
              future: _initializationFuture,
              builder: (context, snapshot) {
                bool isLoading = snapshot.connectionState == ConnectionState.waiting;
                bool hasError = _error != null;
                bool showContent = snapshot.connectionState == ConnectionState.done && !hasError;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button and title
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text(
                          'Create Wallet',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Wallet name section
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Your Wallet Name',
                          style: TextStyle(
                            color: Color(0xFFE6E6E6),
                            fontSize: 18,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 16),

                        if (isLoading)
                          Column(
                            children: [
                              const CircularProgressIndicator(color: Colors.white),
                              const SizedBox(height: 16),
                              const Text(
                                'Generating your unique wallet name...',
                                style: TextStyle(
                                  color: Color(0x99FFFFFF),
                                  fontSize: 14,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Loading...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        else if (hasError)
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red, fontSize: 16),
                            textAlign: TextAlign.center,
                          )
                        else
                          Column(
                            children: [
                              Text(
                                _walletName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Your unique wallet identifier',
                                style: TextStyle(
                                  color: Color(0x99FFFFFF),
                                  fontSize: 14,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 16),

                        // Regenerate button
                        if (showContent && _walletName != "Regenerating...")
                          GestureDetector(
                            onTap: _regenerateWalletName,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.refresh, color: Colors.white, size: 24),
                                SizedBox(width: 8),
                                Text(
                                  'Regenerate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontFamily: 'Fira Code',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_walletName == "Regenerating...")
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                          ),

                        const SizedBox(height: 16),

                        // Description
                        const Text(
                          'An easy way to recognise your wallets\nRefresh to autogenerate a new name',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0x99FFFFFF),
                            fontSize: 14,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Continue button
                    if (showContent)
                      Container(
                        width: 343,
                        padding: const EdgeInsets.all(16),
                        decoration: ShapeDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment(0.50, 0.00),
                            end: Alignment(0.50, 1.00),
                            colors: [Color(0xFF0CE6ED), Color(0xFF8AF9A8)],
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            if (_mnemonic != null && _walletInfo != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreateWalletScreen(initialMnemonic: _mnemonic!),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Wallet data not ready yet.')),
                              );
                            }
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Continue',
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

                    const SizedBox(height: 34),
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
