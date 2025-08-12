import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/gradient_action_button.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  final Account? accountToEdit;

  const CreateAccountScreen({super.key, this.accountToEdit});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final AccountsService _accountsService = AccountsService();
  final HumanReadableChecksumService _checksumService =
      HumanReadableChecksumService();
  final TextEditingController _nameController = TextEditingController();

  late Account _provisionalAccount;
  Future<String>? _checksumFuture;
  bool _isLoading = true;
  bool _isCreating = false;

  bool get _isEditMode => widget.accountToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      _loadExistingAccount();
    } else {
      _generateAccount();
    }
  }

  Future<void> _loadExistingAccount() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final account = widget.accountToEdit!;
      setState(() {
        _provisionalAccount = account;
        _checksumFuture = _checksumService.getHumanReadableName(
          account.accountId,
        );
        _nameController.text = account.name;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load account details: $e')),
        );
      }
    }
  }

  Future<void> _generateAccount() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final account = await _accountsService.createNewAccount();
      if (mounted) {
        setState(() {
          _provisionalAccount = account;
          _checksumFuture = _checksumService.getHumanReadableName(
            account.accountId,
          );
          _nameController.text = account.name;
          _isLoading = false;
        });
      }
    } catch (e, s) {
      print('Exception on create account screen: $e $s');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to generate account details')),
        );
      }
    }
  }

  Future<void> _saveAccount() async {
    setState(() {
      _isCreating = true;
    });
    try {
      if (_isEditMode) {
        await _accountsService.updateAccountName(
          _provisionalAccount,
          _nameController.text,
        );
        // Invalidate the accounts provider to reload the entire list
        ref.invalidate(accountsProvider);
        TelemetryService().sendEvent('edit_account');
      } else {
        final accountToSave = _provisionalAccount.copyWith(
          name: _nameController.text,
        );
        await _accountsService.addAccount(accountToSave);
        // Invalidate the accounts provider to reload the entire list
        ref.invalidate(accountsProvider);
        TelemetryService().sendEvent('create_account');
      }
      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e, s) {
      print('Exception on _createAccount: $e $s');

      TelemetryService().sendEvent(
        'error',
        parameters: {
          'action': _isEditMode ? 'edit_account' : 'create_account',
          'error': e.toString(),
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${_isEditMode ? 'save' : 'create'} account',
            ),
          ),
        );
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
      extendBodyBehindAppBar: true,
      backgroundColor: context.themeColors.background,
      appBar: WalletAppBar(
        title: _isEditMode ? 'Edit Account' : 'Create New Account',
      ),
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

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Name your Account',
          style: context.themeText.smallTitle?.copyWith(
            color: context.themeColors.light,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _nameController,
          style: context.themeText.smallTitle,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckphraseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Account Checkphrase',
          style: context.themeText.smallTitle?.copyWith(
            color: context.themeColors.light,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          width: context.isTablet ? 600 : 325,
          child: Text(
            'A unique phrase which allows you to easily recognise and '
            'verify your wallet.',
            style: context.themeText.smallParagraph?.copyWith(
              color: context.themeColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: context.isTablet ? 600 : 311,
          height: 50, // Set a fixed height to avoid layout jump
          child: FutureBuilder<String>(
            future: _checksumFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.0),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                );
              }
              if (snapshot.hasData) {
                return Text(
                  snapshot.data!,
                  style: context.themeText.largeTag?.copyWith(
                    color: context.themeColors.checksum,
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
          : GradientActionButton(
              onPressed: _saveAccount,
              label: _isEditMode ? 'Save' : 'Create Account',
              textStyle: context.themeText.smallTitle?.copyWith(
                color: context.themeColors.textSecondary,
              ),
            ),
    );
  }
}
