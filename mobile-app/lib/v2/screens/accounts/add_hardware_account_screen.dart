import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';

class AddHardwareAccountScreen extends ConsumerStatefulWidget {
  const AddHardwareAccountScreen({super.key, required this.walletIndex, this.isNewWallet = false});

  final int walletIndex;
  final bool isNewWallet;

  @override
  ConsumerState<AddHardwareAccountScreen> createState() => _AddHardwareAccountScreenState();
}

class _AddHardwareAccountScreenState extends ConsumerState<AddHardwareAccountScreen> {
  final _name = TextEditingController(text: 'Keystone Wallet');
  final _address = TextEditingController();

  final _accountsService = AccountsService();
  final _settingsService = SettingsService();
  final _substrateService = SubstrateService();

  bool _isSaving = false;
  String? _error;

  Future<void> _scanQRCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const QrScannerPage(), fullscreenDialog: true),
    );
    if (result != null && mounted) {
      _address.text = result.trim();
      if (_error != null) setState(() => _error = null);
    }
  }

  void _fillDebugAddress() {
    _address.text = 'qzn5St24cMsjE4JKYdXLBctusWj5zom67dnrW22SweAahLGeG';
    if (_error != null) setState(() => _error = null);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final address = _address.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Name is required');
      return;
    }
    if (!_substrateService.isValidSS58Address(address)) {
      setState(() => _error = 'Invalid address');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final nextIndex = await _settingsService.getNextFreeAccountIndex(widget.walletIndex);
      final account = Account(
        walletIndex: widget.walletIndex,
        index: nextIndex,
        name: name,
        accountId: address,
        accountType: AccountType.keystone,
      );
      await _accountsService.addAccount(account);
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isNewWallet ? 'Add Hardware Wallet' : 'Add Hardware Account';
    return ScaffoldBase(
      appBar: WalletAppBar(title: title),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(title, style: context.themeText.smallTitle),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _name,
            labelText: 'NAME',
            hintText: widget.isNewWallet ? 'Hardware Wallet' : 'Account',
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _address,
            labelText: 'ADDRESS',
            hintText: 'SS58 address',
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Button(variant: ButtonVariant.neutral, label: 'Scan QR Code', onPressed: _scanQRCode),
              ),
              if (kDebugMode) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Button(variant: ButtonVariant.neutral, label: 'Debug Fill', onPressed: _fillDebugAddress),
                ),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: context.themeText.tiny?.copyWith(color: Colors.red)),
          ],
          const Spacer(),
          Button(
            variant: ButtonVariant.primary,
            label: widget.isNewWallet ? 'Add Hardware Wallet' : 'Add Hardware Account',
            onPressed: _isSaving ? null : _save,
            isLoading: _isSaving,
          ),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }
}
