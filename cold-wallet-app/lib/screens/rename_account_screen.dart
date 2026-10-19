import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

/// Every account name is local to this device: the hot wallet keeps its own.
const accountNameHelper = 'Only stored on this device. Your phone shows its own name for the same account.';

String? nameTakenMessage(WidgetRef ref, String name, {ColdAccount? except}) {
  final taken = ref.read(accountsProvider).any((a) => a.label == name && !(except?.derivesSameKey(a) ?? false));
  return taken ? 'Another account is already named $name.' : null;
}

class RenameAccountScreen extends ConsumerStatefulWidget {
  final ColdAccount account;

  const RenameAccountScreen({super.key, required this.account});

  @override
  ConsumerState<RenameAccountScreen> createState() => _RenameAccountScreenState();
}

class _RenameAccountScreenState extends ConsumerState<RenameAccountScreen> {
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

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name == widget.account.label) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(walletControllerProvider.notifier).renameAccount(widget.account, name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Rename account failed: $e');
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not rename the account: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final name = _name.text.trim();
    final nameError = nameTakenMessage(ref, name, except: widget.account);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Rename'),
      mainContent: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            QuantusTextField(
              controller: _name,
              hint: 'Account name',
              error: nameError ?? _error,
              showClearButton: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            Text(accountNameHelper, style: text.caption.copyWith(color: colors.textMuted)),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: 'Save',
          padding: coldButtonPadding,
          isLoading: _busy,
          isDisabled: name.isEmpty || nameError != null,
          onTap: _save,
        ),
      ),
    );
  }
}
