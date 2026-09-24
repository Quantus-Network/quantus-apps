import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/scheme_picker.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

/// Renames an account, or disconnects it from this wallet. Disconnecting only
/// drops the entry: the seed still derives the key, so adding the same
/// derivation path brings the account back.
class EditAccountScreen extends ConsumerStatefulWidget {
  final String address;
  final ColdAccount account;

  const EditAccountScreen({super.key, required this.address, required this.account});

  @override
  ConsumerState<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends ConsumerState<EditAccountScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.account.label);
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _nameTakenBy {
    final name = _name.text.trim();
    final taken = ref.read(accountsProvider).any((a) => a.label == name && !a.derivesSameKey(widget.account));
    return taken ? 'Another account is already named $name.' : null;
  }

  Future<void> _run(String action, Future<void> Function(WalletController controller) change) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await change(ref.read(walletControllerProvider.notifier));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('$action failed: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not ${action.toLowerCase()}: $e';
        });
      }
    }
  }

  Future<void> _save() {
    final name = _name.text.trim();
    if (name == widget.account.label) {
      Navigator.pop(context);
      return Future.value();
    }
    return _run('Rename account', (c) => c.renameAccount(widget.account, name));
  }

  Future<void> _disconnect() async {
    final confirmed = await showConfirmActionSheet(
      context,
      title: 'Disconnect ${widget.account.label}?',
      message:
          'This removes the account from this cold wallet. Your seed phrase and funds are not affected.\n\n'
          'You can always add the account back by adding an account with the same derivation path '
          'and signature type:\n${widget.account.derivationPath}\n${schemeLabel(widget.account.scheme)}',
      confirmLabel: 'Disconnect',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _run('Disconnect account', (c) => c.removeAccount(widget.account));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final nameError = _nameTakenBy;
    final isLastAccount = ref.watch(accountsProvider).length <= 1;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Edit account'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            Text('NAME', style: text.labelMonogram.copyWith(color: colors.textMuted)),
            const SizedBox(height: 6),
            QuantusTextField(
              controller: _name,
              hint: 'Account name',
              error: nameError,
              showClearButton: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),
            Text('DERIVATION PATH', style: text.labelMonogram.copyWith(color: colors.textMuted)),
            const SizedBox(height: 6),
            Text(widget.account.derivationPath, style: text.dataAddress.copyWith(color: colors.textContent)),
            AddressWithCheckphrase(label: 'Address', address: widget.address),
            const SizedBox(height: 32),
            if (isLastAccount)
              Text(
                'This is the only account in this wallet, so it cannot be disconnected.',
                style: text.caption.copyWith(color: colors.textMuted),
              )
            else
              QuantusButton.simple(
                label: 'Disconnect account',
                variant: ButtonVariant.danger,
                isDisabled: _busy,
                onTap: _disconnect,
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: text.caption.copyWith(color: colors.semanticEmber)),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: 'Save',
          isLoading: _busy,
          isDisabled: _name.text.trim().isEmpty || nameError != null,
          onTap: _save,
        ),
      ),
    );
  }
}
