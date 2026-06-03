import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/custom_text_field.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/qr_scanner_page.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';

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

    final l10n = ref.read(l10nProvider);
    if (name.isEmpty) {
      setState(() => _error = l10n.addHardwareAccountNameRequired);
      return;
    }
    if (!_substrateService.isValidSS58Address(address)) {
      setState(() => _error = l10n.addHardwareAccountInvalidAddress);
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
    final l10n = ref.watch(l10nProvider);
    final title = widget.isNewWallet ? l10n.addHardwareAccountAddWallet : l10n.addHardwareAccountAddAccount;

    return ScaffoldBase(
      appBar: V2AppBar(title: title),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Text(title, style: context.themeText.smallTitle),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _name,
            labelText: l10n.addHardwareAccountNameLabel,
            hintText: widget.isNewWallet
                ? l10n.addHardwareAccountNameHintWallet
                : l10n.addHardwareAccountNameHintAccount,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _address,
            labelText: l10n.addHardwareAccountAddressLabel,
            hintText: l10n.addHardwareAccountAddressHint,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: QuantusButton.simple(
                  label: l10n.componentQrScannerTitle,
                  variant: ButtonVariant.secondary,
                  onTap: _scanQRCode,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: QuantusButton.simple(
                    label: l10n.addHardwareAccountDebugFill,
                    variant: ButtonVariant.secondary,
                    onTap: _fillDebugAddress,
                  ),
                ),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: context.themeText.tiny?.copyWith(color: Colors.red)),
          ],
          const Spacer(),
          QuantusButton.simple(label: title, onTap: _isSaving ? null : _save, isLoading: _isSaving),
          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }
}
