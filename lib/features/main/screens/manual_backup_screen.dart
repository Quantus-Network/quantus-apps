import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:resonance_network_wallet/core/helpers/snackbar_helper.dart';
import 'package:resonance_network_wallet/core/widgets/gradient_action_button.dart';

class ManualBackupScreen extends StatefulWidget {
  const ManualBackupScreen({super.key});

  @override
  ManualBackupScreenState createState() => ManualBackupScreenState();
}

class ManualBackupScreenState extends State<ManualBackupScreen> {
  String _mnemonic = '';
  bool _isLoading = true;
  bool _hasSavedMnemonic = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _generateMnemonic();
  }

  Future<void> _generateMnemonic() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _mnemonic = await SubstrateService().generateMnemonic();
      if (_mnemonic.isEmpty) throw Exception('Mnemonic generation returned empty.');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating mnemonic: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to generate recovery phrase: $e';
        });
      }
    }
  }

  Future<void> _saveWalletAndContinue() async {
    if (_mnemonic.isEmpty) {
      debugPrint('Cannot save wallet, mnemonic is empty.');
      if (mounted) {
        showTopSnackBar(
          context,
          title: 'Error',
          message: 'Recovery phrase not generated.',
        );
      }
      return;
    }

    try {
      final walletInfo = await SubstrateService().generateWalletFromSeed(_mnemonic);

      // final walletName = await HumanReadableChecksumService().getHumanReadableName(walletInfo.accountId);
      // if (walletName.isEmpty) throw Exception('Checksum generation failed');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_wallet', true);
      await prefs.setString('mnemonic', _mnemonic);
      await prefs.setString('account_id', walletInfo.accountId);

      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const WalletMain()),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error saving wallet: $e');
      if (mounted) {
        showTopSnackBar(
          context,
          title: 'Error',
          message: 'Error saving wallet: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final words = _mnemonic.isNotEmpty ? _mnemonic.split(' ') : [];

    final bool canContinue = _hasSavedMnemonic && !_isLoading && _error == null;

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
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
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
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'Your Secret Recovery Phrase',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 13),
                        Text(
                          'Write down and save your seed phrase in a secure location. This is the only way to recover your wallet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.useOpacity(153 / 255.0),
                            fontSize: 14,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                            height: 1.21,
                          ),
                        ),
                        const SizedBox(height: 21),
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 50.0),
                            child: Column(
                              children: [
                                CircularProgressIndicator(color: Colors.white),
                                SizedBox(height: 16),
                                Text(
                                  'Generating secure phrase...',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ],
                            ),
                          )
                        else if (_error != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 50.0, horizontal: 20),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.redAccent, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 9),
                            decoration: ShapeDecoration(
                              color: Colors.black.useOpacity(0.7),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                            ),
                            child: GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10.0,
                              crossAxisSpacing: 9.0,
                              childAspectRatio: (105 / 38),
                              children: List.generate(words.length, (index) {
                                return _buildMnemonicWord(index + 1, words[index]);
                              }),
                            ),
                          ),
                        const SizedBox(height: 21),
                        if (!_isLoading && _error == null)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _mnemonic));
                              showTopSnackBar(
                                context,
                                title: 'Copied!',
                                message: 'Recovery phrase copied to clipboard',
                              );
                            },
                            child: const Opacity(
                              opacity: 0.8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.copy, color: Colors.white, size: 24),
                                  SizedBox(width: 8),
                                  Text(
                                    'Copy to Clipboard',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 35),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _hasSavedMnemonic,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _hasSavedMnemonic = value ?? false;
                                      });
                                    },
                              activeColor: const Color(0xFF8AF9A8),
                              checkColor: const Color(0xFF8AF9A8),
                              side: WidgetStateBorderSide.resolveWith((states) {
                                return const BorderSide(width: 1, color: Colors.white);
                              }),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(2),
                              ),
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'I have copied and stored my seed phrase',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 17),
                      if (canContinue)
                        GradientActionButton(
                          label: 'Continue',
                          onPressed: _saveWalletAndContinue,
                          isLoading: _isLoading,
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              backgroundColor: Colors.grey[400],
                              minimumSize: const Size(double.infinity, 50),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5.0),
                              ),
                            ),
                            onPressed: null,
                            child: const Text(
                              'Continue',
                              style: TextStyle(
                                color: Color(0xFF0E0E0E),
                                fontSize: 18,
                                fontFamily: 'Fira Code',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMnemonicWord(int index, String word) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            color: Colors.white.useOpacity(0.15),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        '$index.$word',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontFamily: 'Fira Code',
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
