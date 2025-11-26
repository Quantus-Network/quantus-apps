import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_miner/src/services/binary_manager.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class RewardsAddressSetupScreen extends StatefulWidget {
  const RewardsAddressSetupScreen({super.key});

  @override
  State<RewardsAddressSetupScreen> createState() => _RewardsAddressSetupScreenState();
}

class _RewardsAddressSetupScreenState extends State<RewardsAddressSetupScreen> {
  bool _isLoading = true;
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _checkRewardsAddress();
    _addressController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _addressController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _checkRewardsAddress() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final rewardsFile = File('$quantusHome/rewards-address.txt');

      if (await rewardsFile.exists()) {
        final address = await rewardsFile.readAsString();
        if (address.trim().isNotEmpty) {
          setState(() {
            _addressController.text = address.trim();
          });
          print('Rewards address found: $address');
        }
      }
    } catch (e) {
      print('Error checking rewards address: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRewardsAddress() async {
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid address')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final quantusHome = await BinaryManager.getQuantusHomeDirectoryPath();
      final rewardsFile = File('$quantusHome/rewards-address.txt');
      await rewardsFile.writeAsString(address);

      print('Rewards address saved: $address');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Rewards address saved successfully!')));
        // Navigate to the main mining screen
        context.go('/miner_dashboard');
      }
    } catch (e) {
      print('Error saving rewards address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving address: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showQrOverlay() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Stack(
          children: [
            // Semi-transparent dark background handled by Dialog's barrierColor,
            // but we can ensure high contrast content here
            Center(
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  margin: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.useOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 40, // spacer for alignment
                          ),
                          // const Text(
                          //   'Scan QR Code',
                          //   style: TextStyle(
                          //     color: Colors.white,
                          //     fontSize: 20,
                          //     fontWeight: FontWeight.bold,
                          //   ),
                          // ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Icon(Icons.close, color: Colors.white, size: 24),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: Image.asset(
                          'assets/tr-ee-u1vxT1-qrcode-white.png', // White QR on dark bg
                          width: 250,
                          height: 250,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Scan with your mobile phone\nto set up your wallet',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rewards Address Setup')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SvgPicture.asset('assets/logo/logo.svg', width: 80, height: 80),
                    const SizedBox(height: 24),
                    const Text(
                      'Add Rewards Account',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Your minted coins will go there.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _addressController,
                      focusNode: _focusNode,
                      autofocus: true,
                      enableInteractiveSelection: true,
                      onSubmitted: (_) => _saveRewardsAddress(),
                      contextMenuBuilder: (context, editableTextState) {
                        return AdaptiveTextSelectionToolbar.editableText(editableTextState: editableTextState);
                      },
                      decoration: InputDecoration(
                        labelText: 'Rewards Wallet Address',
                        border: const OutlineInputBorder(),
                        hintText: 'Paste your address here',
                        prefixIcon: const Icon(Icons.account_balance_wallet),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_addressController.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _addressController.clear();
                                },
                                tooltip: 'Clear',
                              ),
                            IconButton(
                              icon: const Icon(Icons.paste),
                              onPressed: () async {
                                final data = await Clipboard.getData(Clipboard.kTextPlain);
                                if (data?.text != null) {
                                  _addressController.text = data!.text!;
                                }
                              },
                              tooltip: 'Paste',
                            ),
                          ],
                        ),
                      ),
                      maxLines: 1,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _saveRewardsAddress,
                      icon: const Icon(Icons.save),
                      label: const Text('Set Rewards Address'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 48),
                    const Divider(),
                    const SizedBox(height: 24),
                    const Text(
                      "Don't have an account?",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create one in the mobile wallet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _showQrOverlay,
                      icon: const Icon(Icons.qr_code),
                      label: const Text('Scan QR code to set up wallet'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
