import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/features/main/screens/manual_backup_screen.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/core/services/human_readable_checksum_service.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  String _walletName = 'Loading...';
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
      _mnemonic = await SubstrateService().generateMnemonic();
      if (_mnemonic == null || _mnemonic!.isEmpty) throw Exception('Mnemonic generation failed');

      _walletInfo = await SubstrateService().generateWalletFromSeed(_mnemonic!);
      if (_walletInfo == null) throw Exception('Wallet generation failed');

      _walletName = await HumanReadableChecksumService().getHumanReadableName(_walletInfo!.accountId);
      if (_walletName.isEmpty) throw Exception('Checksum generation failed');

      if (mounted) {
        setState(() {});
      }

      debugPrint('Initialization successful');
      debugPrint('Generated mnemonic: $_mnemonic');
      debugPrint('Generated wallet info: ${_walletInfo!.accountId}');
      debugPrint('Generated wallet name: $_walletName');
    } catch (e) {
      debugPrint('Initialization failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to initialize wallet: $e';
          _walletName = 'Error';
        });
      }
    }
  }

  Future<void> _regenerateWalletName() async {
    if (!mounted) return;

    setState(() {
      _error = null;
      _walletName = 'Regenerating...';
      _mnemonic = null;
      _walletInfo = null;
    });

    try {
      _mnemonic = await SubstrateService().generateMnemonic();
      if (_mnemonic == null || _mnemonic!.isEmpty) throw Exception('Mnemonic regeneration failed');

      _walletInfo = await SubstrateService().generateWalletFromSeed(_mnemonic!);
      if (_walletInfo == null) throw Exception('Wallet regeneration failed');

      final newWalletName = await HumanReadableChecksumService().getHumanReadableName(_walletInfo!.accountId);
      if (newWalletName.isEmpty) throw Exception('Checksum regeneration failed');

      if (mounted) {
        setState(() {
          _walletName = newWalletName;
        });
      }
      debugPrint('Regeneration successful: $_mnemonic, $_walletName');
    } catch (e) {
      debugPrint('Regeneration failed: $e');
      if (mounted) {
        setState(() {
          _error = 'Failed to regenerate: $e';
          _walletName = 'Error';
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
                bool isLoading = snapshot.connectionState == ConnectionState.waiting ||
                    _walletName == 'Loading...' ||
                    _walletName == 'Regenerating...';
                bool hasError = _error != null;
                bool showContent = snapshot.connectionState == ConnectionState.done && !isLoading && !hasError;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                        if (isLoading && _walletName != 'Regenerating...')
                          const Column(
                            children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 16),
                              Text(
                                'Generating your unique wallet name...',
                                style: TextStyle(
                                  color: Color(0x99FFFFFF),
                                  fontSize: 14,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
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
                                style: TextStyle(
                                  color: _walletName == 'Error' ? Colors.red : Colors.white,
                                  fontSize: 20,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (_walletName != 'Regenerating...' && _walletName != 'Error') ...[
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
                            ],
                          ),
                        const SizedBox(height: 16),
                        if (_walletName == 'Regenerating...')
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                          )
                        else if (showContent || hasError)
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
                    if (showContent)
                      Container(
                        width: double.infinity,
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
                              MaterialPageRoute(
                                builder: (context) => ManualBackupScreen(initialMnemonic: _mnemonic!),
                              ),
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
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: ShapeDecoration(
                          color: Colors.grey.withOpacity(0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Continue',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 18,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
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
