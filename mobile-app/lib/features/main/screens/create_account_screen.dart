import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/gradient_action_button.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final AccountsService _accountsService = AccountsService();
  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();
  final TextEditingController _nameController = TextEditingController();

  Account? _provisionalAccount;
  Future<String>? _checksumFuture;
  bool _isLoading = true;
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    _generateAccount();
  }

  Future<void> _generateAccount() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final account = await _accountsService.generateProvisionalAccount();
      if (mounted) {
        setState(() {
          _provisionalAccount = account;
          _checksumFuture = _checksumService.getHumanReadableName(account.accountId);
          _nameController.text = account.name;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate account details: $e')));
      }
    }
  }

  Future<void> _createAccount() async {
    if (_provisionalAccount == null) return;
    setState(() {
      _isCreating = true;
    });
    try {
      await _accountsService.createNewAccount(_provisionalAccount!, name: _nameController.text);
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to create account: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/light_leak_effect_background.jpg'),
                fit: BoxFit.cover,
                opacity: 0.54,
              ),
            ),
          ),
          SafeArea(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      _buildAppBar(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 25),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 40),
                              _buildNameField(),
                              const SizedBox(height: 39),
                              _buildCheckphraseSection(),
                            ],
                          ),
                        ),
                      ),
                      _buildCreateButton(),
                      const SizedBox(height: 40),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Text(
            'Create New Account',
            style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Fira Code', fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Name your Account',
          style: TextStyle(
            color: Color(0xFFE6E6E6),
            fontSize: 18,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontFamily: 'Fira Code'),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckphraseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Account Checkphrase',
          style: TextStyle(
            color: Color(0xFFE6E6E6),
            fontSize: 18,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: 325,
          child: Text(
            'A unique phrase which allows you to easily recognise and verify your wallet.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.60),
              fontSize: 14,
              fontFamily: 'Fira Code',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: 311,
          height: 20, // Set a fixed height to avoid layout jump
          child: FutureBuilder<String>(
            future: _checksumFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2.0)),
                );
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red));
              }
              if (snapshot.hasData) {
                return Text(
                  snapshot.data!,
                  style: const TextStyle(
                    color: Color(0xFF16CECE),
                    fontSize: 16,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400,
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25.0),
      child: _isCreating
          ? const Center(child: CircularProgressIndicator())
          : GradientActionButton(onPressed: _createAccount, label: 'Create Account'),
    );
  }
}
