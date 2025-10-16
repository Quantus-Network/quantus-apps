import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/card_info.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  final Account? accountToEdit;

  const CreateAccountScreen({super.key, this.accountToEdit});

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final AccountsService _accountsService = AccountsService();
  final ReferralService _referralService = ReferralService();
  final HumanReadableChecksumService _checksumService =
      HumanReadableChecksumService();
  final TextEditingController _nameController = TextEditingController();

  late Account _provisionalAccount;
  late String _checksum;
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
      final checkphrase = await _checksumService.getHumanReadableName(
        account.accountId,
      );

      setState(() {
        _provisionalAccount = account;
        _checksum = checkphrase;
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
      final checkphrase = await _checksumService.getHumanReadableName(
        account.accountId,
      );

      if (mounted) {
        setState(() {
          _provisionalAccount = account;
          _checksum = checkphrase;
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
        await _referralService
            .submitAddressToBackend(); // ensure the user is logged in
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
    return ScaffoldBase(
      decorations: [
        Positioned(
          right: -40,
          top: MediaQuery.of(context).size.height * 0.4,
          child: const Sphere(variant: 2, size: 321.853),
        ),
      ],
      backdropBlur: 32,
      appBar: _isEditMode ? 'Edit Account' : 'Create New Account',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 18),
                        CustomTextField(
                          controller: _nameController,
                          labelText: 'ACCOUNT NAME',
                        ),
                        const SizedBox(height: 25.0),
                        CardInfo(
                          text: _isLoading ? 'Loading checksum...' : _checksum,
                          icon: const Icon(Icons.info_outline),
                          label: 'ACCOUNT CHECKPHRASE',
                          onPressed: () {},
                          textColor: context.themeColors.checksumDarker,
                        ),
                        const SizedBox(height: 25.0),
                        CardInfo(
                          text: _isLoading
                              ? 'Loading address...'
                              : AddressFormattingService.splitIntoChunks(
                                  _provisionalAccount.accountId,
                                ).join(' '),
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            ClipboardExtensions.copyTextWithSnackbar(
                              context,
                              _provisionalAccount.accountId,
                            );
                          },
                          label: 'ACCOUNT ADDRESS',
                        ),
                      ],
                    ),
                  ),
                ),
                _buildCreateButton(),
              ],
            ),
    );
  }

  Widget _buildCreateButton() {
    return _isCreating
        ? const Center(child: CircularProgressIndicator())
        : Button(
            variant: ButtonVariant.primary,
            onPressed: _saveAccount,
            label: _isEditMode ? 'Save' : 'Create Account',
          );
  }
}
