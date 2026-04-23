import 'package:flash/flash_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:quantus_miner/src/utils/app_logger.dart';
import 'package:quantus_miner/src/services/miner_wallet_service.dart';
import 'package:quantus_miner/src/shared/extensions/snackbar_extensions.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final _log = log.withTag('InnerHashSetup');

/// Setup screen for the miner inner hash.
class RewardsAddressSetupScreen extends StatefulWidget {
  const RewardsAddressSetupScreen({super.key});

  @override
  State<RewardsAddressSetupScreen> createState() => _RewardsAddressSetupScreenState();
}

enum _ImportMode { mnemonic, preimage }

class _RewardsAddressSetupScreenState extends State<RewardsAddressSetupScreen> {
  final MinerWalletService _walletService = MinerWalletService();

  bool _isLoading = false;
  bool _showImportView = false;
  _ImportMode _importMode = _ImportMode.mnemonic;

  // Generated mnemonic flow
  String? _generatedMnemonic;
  bool _mnemonicConfirmed = false;

  // Import mnemonic flow
  final TextEditingController _importController = TextEditingController();
  final FocusNode _importFocusNode = FocusNode();
  String? _importError;

  // Result after saving
  WormholeKeyPair? _savedKeyPair;

  // For preimage-only flow (no keypair available)
  String? _savedPreimageOnly;

  @override
  void initState() {
    super.initState();
    _showImportView = true;
    _importMode = _ImportMode.preimage;
    _loadExistingInnerHash();
  }

  Future<void> _loadExistingInnerHash() async {
    try {
      final innerHash = await _walletService.readRewardsPreimageFile();
      if (!mounted || innerHash == null || innerHash.isEmpty) {
        return;
      }

      setState(() {
        _importController.text = innerHash;
      });
    } catch (e) {
      _log.e('Error loading existing inner hash', error: e);
    }
  }

  @override
  void dispose() {
    _importController.dispose();
    _importFocusNode.dispose();
    super.dispose();
  }

  /// Generate a new 24-word mnemonic.
  void _generateNewMnemonic() {
    setState(() {
      _generatedMnemonic = _walletService.generateMnemonic();
      _mnemonicConfirmed = false;
    });
  }

  /// Save the generated mnemonic and derive the wormhole address.
  Future<void> _saveGeneratedMnemonic() async {
    if (_generatedMnemonic == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final keyPair = await _walletService.saveMnemonic(_generatedMnemonic!);
      setState(() {
        _savedKeyPair = keyPair;
      });
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar(title: 'Error', message: 'Failed to save wallet: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Validate and save an imported mnemonic.
  Future<void> _saveImportedMnemonic() async {
    final raw = _importController.text.trim();

    if (raw.isEmpty) {
      setState(() {
        _importError = 'Please enter your recovery phrase';
      });
      return;
    }

    final words = raw.split(RegExp(r'\s+'));
    if (words.length != 24 && words.length != 12) {
      setState(() {
        _importError = 'Recovery phrase must be exactly 24 or 12 words (got ${words.length})';
      });
      return;
    }

    // Normalize: collapse any whitespace/newlines to single spaces
    final mnemonic = words.join(' ');

    if (!_walletService.validateMnemonic(mnemonic)) {
      setState(() {
        _importError = 'Invalid recovery phrase. Please check your words.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _importError = null;
    });

    try {
      final keyPair = await _walletService.saveMnemonic(mnemonic);
      setState(() {
        _savedKeyPair = keyPair;
      });
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar(title: 'Error', message: 'Failed to save wallet: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Continue to the miner dashboard.
  void _continueToMining() {
    context.go('/miner_dashboard');
  }

  /// Copy text to clipboard with feedback.
  Future<void> _copyToClipboard(String text, String label) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      context.showSuccessBar(content: Text('$label copied to clipboard'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = _showImportView && _savedKeyPair == null && _savedPreimageOnly == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inner Hash Setup'),
        leading: canGoBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _showImportView = false;
                    _importController.clear();
                    _importError = null;
                    _importMode = _ImportMode.mnemonic;
                  });
                },
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _savedKeyPair != null
          ? _buildSuccessView()
          : _savedPreimageOnly != null
          ? _buildPreimageOnlySuccessView()
          : _showImportView
          ? _buildImportView()
          : _generatedMnemonic != null
          ? _buildGeneratedMnemonicView()
          : _buildInitialChoiceView(),
    );
  }

  /// Initial view: Choose to generate or import a wallet.
  Widget _buildInitialChoiceView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SvgPicture.asset('assets/logo/logo.svg', width: 80, height: 80),
            const SizedBox(height: 24),
            const Text(
              'Set Up Inner Hash',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste the wormhole inner hash that the miner should use for rewards.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 48),
            ElevatedButton.icon(
              onPressed: _generateNewMnemonic,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create New Wallet'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _showImportView = true;
                });
              },
              icon: const Icon(Icons.download),
              label: const Text('Enter Inner Hash'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 48),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.amber),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'If you already have an inner hash from the CLI, paste it here to use the same rewards destination.',
                      style: TextStyle(fontSize: 14, color: Colors.amber.shade200),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// View showing the generated mnemonic for backup.
  Widget _buildGeneratedMnemonicView() {
    final words = _generatedMnemonic!.split(' ');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.security, size: 48, color: Colors.amber),
          const SizedBox(height: 16),
          const Text(
            'Write Down Your Recovery Phrase',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Store these 24 words safely. You will need them to recover your wallet and withdraw mining rewards.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: Column(
              children: [
                // Grid of words
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: words.length,
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(6)),
                      child: Row(
                        children: [
                          Text('${index + 1}.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              words[index],
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextButton.icon(
                  onPressed: () => _copyToClipboard(_generatedMnemonic!, 'Recovery phrase'),
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copy to clipboard'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.red, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Never share your recovery phrase. Anyone with these words can access your funds.',
                    style: TextStyle(fontSize: 13, color: Colors.red.shade200),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          CheckboxListTile(
            value: _mnemonicConfirmed,
            onChanged: (value) {
              setState(() {
                _mnemonicConfirmed = value ?? false;
              });
            },
            title: const Text(
              'I have written down my recovery phrase and stored it safely',
              style: TextStyle(fontSize: 14),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _mnemonicConfirmed ? _saveGeneratedMnemonic : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
            ),
            child: const Text('Continue'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _generatedMnemonic = null;
                _mnemonicConfirmed = false;
              });
            },
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  /// Validate and save an imported preimage (no mnemonic).
  Future<void> _saveImportedPreimage() async {
    final preimage = _importController.text.trim();

    if (preimage.isEmpty) {
      setState(() {
        _importError = 'Please enter your inner hash';
      });
      return;
    }

    if (!_walletService.validatePreimage(preimage)) {
      setState(() {
        _importError = 'Invalid inner hash format. Expected 64-character hex string.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _importError = null;
    });

    try {
      await _walletService.savePreimageOnly(preimage);
      setState(() {
        _savedPreimageOnly = preimage;
      });
    } catch (e) {
      if (mounted) {
        context.showErrorSnackbar(title: 'Error', message: 'Failed to save inner hash: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// View for importing an existing mnemonic or preimage.
  Widget _buildImportView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(_importMode == _ImportMode.mnemonic ? Icons.download : Icons.key, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              _importMode == _ImportMode.mnemonic ? 'Import Recovery Phrase' : 'Import Inner Hash',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _importMode == _ImportMode.mnemonic
                  ? 'Enter your 24-word recovery phrase to restore your wallet.'
                  : 'Enter your inner hash (hex format) from the CLI or another source.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),

            // Toggle between mnemonic and preimage mode
            SegmentedButton<_ImportMode>(
              segments: const [
                ButtonSegment(value: _ImportMode.mnemonic, label: Text('Recovery Phrase'), icon: Icon(Icons.vpn_key)),
                ButtonSegment(value: _ImportMode.preimage, label: Text('Inner Hash Only'), icon: Icon(Icons.key)),
              ],
              selected: {_importMode},
              onSelectionChanged: (selected) {
                setState(() {
                  _importMode = selected.first;
                  _importController.clear();
                  _importError = null;
                });
              },
            ),
            const SizedBox(height: 24),

            TextField(
              controller: _importController,
              focusNode: _importFocusNode,
              maxLines: _importMode == _ImportMode.mnemonic ? 4 : 2,
              decoration: InputDecoration(
                labelText: _importMode == _ImportMode.mnemonic ? 'Recovery Phrase' : 'Inner Hash',
                hintText: _importMode == _ImportMode.mnemonic
                    ? 'Enter your 24 words separated by spaces'
                    : 'e.g., 0xa9da183a...',
                border: const OutlineInputBorder(),
                errorText: _importError,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  onPressed: () async {
                    final data = await Clipboard.getData(Clipboard.kTextPlain);
                    if (data?.text != null) {
                      _importController.text = data!.text!;
                      setState(() {
                        _importError = null;
                      });
                    }
                  },
                  tooltip: 'Paste from clipboard',
                ),
              ),
              onChanged: (_) {
                if (_importError != null) {
                  setState(() {
                    _importError = null;
                  });
                }
              },
            ),

            // Warning for preimage-only mode
            if (_importMode == _ImportMode.preimage) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Without the recovery phrase, you cannot withdraw rewards from this app. Use this option only if you plan to withdraw using the CLI.',
                        style: TextStyle(fontSize: 13, color: Colors.amber.shade200),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _importMode == _ImportMode.mnemonic ? _saveImportedMnemonic : _saveImportedPreimage,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              child: Text(_importMode == _ImportMode.mnemonic ? 'Import Wallet' : 'Save Inner Hash'),
            ),
          ],
        ),
      ),
    );
  }

  /// Success view for preimage-only import (no mnemonic).
  Widget _buildPreimageOnlySuccessView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Inner Hash Saved!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your mining rewards will be directed using this inner hash.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),

          _buildInfoCard(
            title: 'Inner Hash',
            subtitle: 'Used by the node to direct rewards',
            value: _savedPreimageOnly!,
            icon: Icons.key,
            color: Colors.blue,
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber, color: Colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Without your recovery phrase, you cannot withdraw rewards from this app. Make sure you have access to your secret via the CLI or another tool.',
                    style: TextStyle(fontSize: 14, color: Colors.amber.shade200),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _continueToMining,
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Start Mining'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Success view showing the derived wormhole address and rewards preimage.
  Widget _buildSuccessView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Wallet Created Successfully!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Your mining rewards will be sent to this wormhole address.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 32),

          // Wormhole Address
          _buildInfoCard(
            title: 'Wormhole Address',
            subtitle: 'Where your mining rewards go',
            value: _savedKeyPair!.address,
            icon: Icons.account_balance_wallet,
            color: Colors.green,
          ),
          const SizedBox(height: 16),

          _buildInfoCard(
            title: 'Inner Hash',
            subtitle: 'Used by the node (auto-configured)',
            value: _savedKeyPair!.rewardsPreimageHex,
            icon: Icons.key,
            color: Colors.blue,
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The inner hash has been saved automatically. The mining node will use it to direct rewards to your wormhole address.',
                    style: TextStyle(fontSize: 14, color: Colors.green.shade200),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: _continueToMining,
            icon: const Icon(Icons.rocket_launch),
            label: const Text('Start Mining'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 18),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget for displaying address/preimage info cards.
  Widget _buildInfoCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.grey.shade800, borderRadius: BorderRadius.circular(8)),
            child: SelectableText(value, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _copyToClipboard(value, title),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
              style: TextButton.styleFrom(foregroundColor: color),
            ),
          ),
        ],
      ),
    );
  }
}
