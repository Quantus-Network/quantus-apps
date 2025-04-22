import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:human_checksum/human_checksum.dart';
import 'package:resonance_network_wallet/features/main/screens/create_wallet_screen.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';

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
      final String wordListContent = await rootBundle.loadString('assets/text/crypto_checksum_bip39.txt');
      _wordList = wordListContent.split('\n').where((word) => word.isNotEmpty).toList();

      if (_wordList.isEmpty) {
        throw Exception('Word list is empty');
      }

      await _generateNewMnemonic();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize wallet: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateNewMnemonic() async {
    if (!mounted) return;

    try {
      // Generate a new mnemonic using SubstrateService
      _mnemonic = await SubstrateService().generateMnemonic();
      _walletInfo = await SubstrateService().generateWalletFromSeed(_mnemonic!);

      // Generate human-readable checksum
      HumanChecksum humanChecksum = HumanChecksum(_wordList);
      final words = humanChecksum.addressToChecksum(_walletInfo!.accountId);

      if (mounted) {
        setState(() {
          _walletName = words.join('-');
          _isLoading = false;
        });
      }

      debugPrint('Generated mnemonic: $_mnemonic');
      debugPrint('Generated wallet info: ${_walletInfo!.accountId} ${_walletInfo!.keypair.publicKey}');
      debugPrint('Generated words: $words');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to generate mnemonic: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _regenerateWalletName() {
    _generateNewMnemonic();
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

                        if (snapshot.connectionState == ConnectionState.waiting)
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
                        else if (_error != null)
                          Text(
                            _error!,
                            style: const TextStyle(color: Colors.red),
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
                        if (snapshot.connectionState == ConnectionState.done && _error == null)
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
                    if (snapshot.connectionState == ConnectionState.done && _error == null)
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
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const CreateWalletScreen()),
                            );
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
