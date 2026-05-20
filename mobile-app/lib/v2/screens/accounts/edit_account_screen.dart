import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/name_field.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';

class EditAccountScreen extends ConsumerStatefulWidget {
  final Account initialAccount;

  const EditAccountScreen({super.key, required this.initialAccount});

  @override
  ConsumerState<EditAccountScreen> createState() => EditAccountScreenState();
}

class EditAccountScreenState extends ConsumerState<EditAccountScreen> {
  late final TextEditingController _controller;
  final _accountsService = AccountsService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialAccount.name);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      final l10n = ref.read(l10nProvider);
      context.showErrorToaster(message: l10n.editAccountNameEmpty);
      return;
    }
    if (name == widget.initialAccount.name) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await _accountsService.updateAccountName(widget.initialAccount, name);
      if (mounted) {
        ref.invalidate(accountsProvider);
        ref.invalidate(activeAccountProvider);
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        final l10n = ref.read(l10nProvider);
        context.showErrorToaster(message: l10n.editAccountRenameFailed);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.editAccountAppBarTitle),
      mainContent: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [NameField(controller: _controller)],
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          variant: ButtonVariant.primary,
          label: l10n.editAccountDone,
          onTap: _save,
          isLoading: _saving,
        ),
      ),
    );
  }
}
