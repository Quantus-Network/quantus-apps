import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart'; 
import 'package:quantus_miner/src/services/binary_manager.dart';

class RewardsAddressSetupScreen extends StatefulWidget {
  const RewardsAddressSetupScreen({super.key});

  @override
  State<RewardsAddressSetupScreen> createState() =>
      _RewardsAddressSetupScreenState();
}

class _RewardsAddressSetupScreenState extends State<RewardsAddressSetupScreen> {
  bool _isLoading = true;
  bool _showQrCode = false;
  final TextEditingController _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkRewardsAddress();
  }

  @override
  void dispose() {
    _addressController.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid address')),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rewards address saved successfully!')),
        );
        // Navigate to the main mining screen
        context.go('/miner_dashboard');
      }
    } catch (e) {
      print('Error saving rewards address: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving address: $e')),
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
                    SvgPicture.asset(
                      'assets/logo/logo.svg',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Add Rewards Account',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
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
                      decoration: const InputDecoration(
                        labelText: 'Rewards Wallet Address',
                        border: OutlineInputBorder(),
                        hintText: 'Paste your address here',
                        prefixIcon: Icon(Icons.account_balance_wallet),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create one in the mobile wallet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    if (!_showQrCode)
                      OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            _showQrCode = true;
                          });
                        },
                        icon: const Icon(Icons.qr_code),
                        label: const Text('Scan QR code to set up wallet'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    if (_showQrCode) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            SvgPicture.asset(
                              'assets/tr-ee-u1vxT1-qrcode-black.svg', // Black QR on white bg for better scanning
                              width: 200,
                              height: 200,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Scan with your mobile phone',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _showQrCode = false;
                          });
                        },
                        child: const Text('Hide QR Code'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}
