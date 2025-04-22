import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/core/services/human_readable_checksum_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'package:human_checksum/human_checksum.dart';

// Function to run in isolate
Future<String> _getWalletNameInIsolate(String address) async {
  debugPrint('Starting isolate for address: $address');
  final receivePort = ReceivePort();

  // Load word list in main thread
  final wordList = await rootBundle.loadString('assets/text/crypto_checksum_bip39.txt');
  final words = wordList.split('\n').where((word) => word.isNotEmpty).toList();
  debugPrint('Loaded word list with ${words.length} words');

  if (words.length != 2048) {
    debugPrint('Word list length mismatch. Expected 2048, got ${words.length}');
    return '';
  }

  await Isolate.spawn(_isolateEntry, [receivePort.sendPort, words]);
  final sendPort = await receivePort.first as SendPort;
  debugPrint('Got sendPort from isolate');

  final responsePort = ReceivePort();
  sendPort.send([address, responsePort.sendPort]);
  debugPrint('Sent address to isolate');
  final result = await responsePort.first as String;
  debugPrint('Got result from isolate: $result');
  responsePort.close();
  return result;
}

void _isolateEntry(List<dynamic> args) async {
  final mainSendPort = args[0] as SendPort;
  final words = args[1] as List<String>;

  debugPrint('Isolate started with word list length: ${words.length}');
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);
  debugPrint('Sent sendPort to main isolate');

  await for (final message in receivePort) {
    final address = message[0] as String;
    final replyTo = message[1] as SendPort;
    debugPrint('Isolate received address: $address');

    try {
      if (words.length != 2048) {
        debugPrint('Word list length mismatch in isolate. Expected 2048, got ${words.length}');
        replyTo.send('');
        continue;
      }

      final humanChecksum = HumanChecksum(words);
      final result = humanChecksum.addressToChecksum(address).join('-');
      debugPrint('Got wallet name in isolate: $result');
      replyTo.send(result);
    } catch (e) {
      debugPrint('Error in isolate: $e');
      replyTo.send('');
    }
  }
}

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  SendScreenState createState() => SendScreenState();
}

class SendScreenState extends State<SendScreen> {
  final TextEditingController _recipientController = TextEditingController();
  BigInt _maxBalance = BigInt.from(0);
  bool _hasAddressError = false;
  String _savedAddressesLabel = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  bool _isValidSS58Address(String address) {
    try {
      // Use SubstrateService to validate the address
      return SubstrateService().isValidSS58Address(address);
    } catch (e) {
      debugPrint('Error validating address: $e');
      return false;
    }
  }

  Future<void> _loadBalance() async {
    setState(() {});

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
      setState(() {});
    }
  }

  Future<void> _lookupIdentity() async {
    final recipient = _recipientController.text.trim();
    if (recipient.isEmpty) {
      setState(() {
        _savedAddressesLabel = '';
      });
      return;
    }

    try {
      final isValid = _isValidSS58Address(recipient);
      setState(() {
        _hasAddressError = !isValid;
      });

      if (isValid) {
        final stopwatch = Stopwatch()..start();
        debugPrint('Starting wallet name lookup for: $recipient');
        final humanReadableName = await HumanReadableChecksumService().getHumanReadableName(recipient);
        stopwatch.stop();
        debugPrint('Wallet name lookup took: ${stopwatch.elapsedMilliseconds}ms');
        debugPrint('Final humanReadableName: $humanReadableName');
        setState(() {
          _savedAddressesLabel = humanReadableName;
        });
      } else {
        setState(() {
          _savedAddressesLabel = '';
        });
      }
    } catch (e) {
      debugPrint('Error in identity lookup: $e');
      setState(() {
        _savedAddressesLabel = '';
      });
    }
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
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 24,
                        ),
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
                                    enabledBorder: _hasAddressError
                                        ? OutlineInputBorder(
                                            borderSide: const BorderSide(color: Colors.red, width: 1),
                                          )
                                        : InputBorder.none,
                                    focusedBorder: _hasAddressError
                                        ? OutlineInputBorder(
                                            borderSide: const BorderSide(color: Colors.red, width: 1),
                                          )
                                        : InputBorder.none,
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
                                    setState(() {
                                      _hasAddressError = false;
                                    });

                                    if (_debounce?.isActive ?? false) _debounce?.cancel();
                                    _debounce = Timer(const Duration(milliseconds: 300), () {
                                      _lookupIdentity();
                                    });
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
                            GestureDetector(
                              onTap: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data != null && data.text != null) {
                                  _recipientController.text = data.text!;
                                  _lookupIdentity();
                                }
                              },
                              child: _buildIconButton('assets/Paste_icon.svg'),
                            ),
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
                      _savedAddressesLabel,
                      style: TextStyle(
                        color: Colors.white.useOpacity(0.8),
                        fontSize: 13,
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
                      _buildIconButton('assets/settings_icon.svg'),
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
