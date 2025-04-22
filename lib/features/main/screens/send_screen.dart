import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  SendScreenState createState() => SendScreenState();
}

class SendScreenState extends State<SendScreen> {
  final TextEditingController _recipientController = TextEditingController();
  BigInt _maxBalance = BigInt.from(0);

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    setState(() {
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final accountId = prefs.getString('account_id');

      if (accountId == null) {
        throw Exception('Wallet not found');
      }

      final balance = await SubstrateService().queryBalance(accountId);

      setState(() {
        _maxBalance = balance;
      });
    } catch (e) {
      debugPrint('Error loading balance: $e');
      setState(() {
      });
    }
  }

  Future<void> _lookupIdentity() async {
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      setState(() {
      });
      return;
    }

    setState(() {
    });
  }


  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: const Color(0xFF0E0E0E),
        body: Stack(
          children: [
            // Background image with opacity
            Positioned.fill(
              child: Opacity(
                opacity: 0.54,
                child: Image.asset(
                  'assets/light-leak-effect-black-background 2.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Main content
            Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      SvgPicture.asset(
                        'assets/back_icon.svg',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Send',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
                // Recipient input
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Text(
                                'To:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontFamily: 'Fira Code',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 17,
                                color: Colors.white,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _recipientController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontFamily: 'Fira Code',
                                    fontWeight: FontWeight.w400,
                                  ),
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    hintText: 'RES Name or address',
                                    hintStyle: TextStyle(
                                      color: Colors.white.useOpacity(0.3),
                                      fontSize: 14,
                                      fontFamily: 'Fira Code',
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: 0.5,
                                    ),
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                    filled: true,
                                    fillColor: Colors.transparent,
                                  ),
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  enableInteractiveSelection: true,
                                  keyboardType: TextInputType.text,
                                  textCapitalization: TextCapitalization.none,
                                  onChanged: (value) {
                                    _lookupIdentity();
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            _buildIconButton('assets/scan.svg'),
                            const SizedBox(width: 9),
                            _buildIconButton('assets/Paste_icon.svg'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                // Saved addresses
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'Saved Addresses',
                      style: TextStyle(
                        color: Colors.white.useOpacity(0.5),
                        fontSize: 12,
                        fontFamily: 'Fira Code',
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
                // Amount display
                Expanded(
                  child: Center(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '0',
                            style: TextStyle(
                              color: Colors.white.useOpacity(0.5),
                              fontSize: 40,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(
                            text: ' RES',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Available balance and max button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Available: ${SubstrateService().formatBalance(_maxBalance)}',
                        style: const TextStyle(
                          color: Color(0xFF16CECE),
                          fontSize: 14,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: ShapeDecoration(
                          color: Colors.white.useOpacity(0.15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          'Max',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontFamily: 'Fira Code',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Network fee
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Network fee',
                            style: TextStyle(
                              color: Colors.white.useOpacity(0.6),
                              fontSize: 12,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Text(
                            '-',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'Fira Code',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      _buildIconButton('assets/info_icon.svg'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                // Send button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Opacity(
                    opacity: 0.3,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: const Text(
                        'Enter Address',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF0E0E0E),
                          fontSize: 18,
                          fontFamily: 'Fira Code',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(String assetPath) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: Colors.white.useOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: SvgPicture.asset(
        assetPath,
        width: 17,
        height: 17,
      ),
    );
  }
}
