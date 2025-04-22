import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/core/extensions/color_extensions.dart';
import 'package:resonance_network_wallet/core/services/substrate_service.dart';
import 'package:resonance_network_wallet/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  SendScreenState createState() => SendScreenState();
}

class SendScreenState extends State<SendScreen> {
  final TextEditingController _recipientController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
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
      hash = await SubstrateService().balanceTransfer2(
        senderSeed,
        recipient,
        amount,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transaction submitted successfully: $hash')),
        );
        Navigator.pop(context);
      }
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
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Recipient',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                  borderSide: BorderSide(color: const Color(0xFF6B46C1).useOpacity(0.5)),
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
                                        final bobWallet = await SubstrateService().generateWalletFromSeed(crystalBob);
                                        _recipientController.text = bobWallet.accountId;
                                        _lookupIdentity();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('$crystalBob development account loaded')),
                                          );
                                        }
                                      } else {
                                        final bobWallet = await SubstrateService().generateWalletFromSeed('//Bob');
                                        _recipientController.text = bobWallet.accountId;
                                        _lookupIdentity();
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Bob development account loaded')),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Error loading Bob account: $e')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.bug_report, size: 16),
                                  label: const Text('Use Crystal Bob (Dilithium Test)'),
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
                                      color: const Color(0xFF6B46C1).useOpacity(0.3),
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                                  borderSide: BorderSide(color: const Color(0xFF6B46C1).useOpacity(0.5)),
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
                                  Flexible(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${SubstrateService().formatBalance(_maxBalance)} REZ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF9F7AEA),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
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
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
