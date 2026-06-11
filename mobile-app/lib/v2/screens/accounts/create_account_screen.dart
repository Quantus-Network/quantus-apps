import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/components/name_field.dart';
import 'package:resonance_network_wallet/v2/components/quantus_button.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base_bottom_content.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_ready_screen.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/add_hardware_account_screen.dart';

class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  ConsumerState<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  final _accountName = TextEditingController();
  final _accountsService = AccountsService();

  List<Account> _accounts = [];
  int _walletIndex = 0;
  bool _isLoading = false;

  bool get _isDisabled => _accountName.text.trim().isEmpty || _isLoading;

  int _walletIndexForActiveAccount(List<Account> accounts, DisplayAccount? activeDisplayAccount) {
    if (activeDisplayAccount is RegularAccount) {
      return activeDisplayAccount.account.walletIndex;
    }
    if (activeDisplayAccount is EntrustedDisplayAccount) {
      final parent = accounts.firstWhereOrNull((a) => a.accountId == activeDisplayAccount.account.parentAccountId);
      if (parent != null) return parent.walletIndex;
    }
    return accounts.isNotEmpty ? accounts.first.walletIndex : 0;
  }

  bool _isHardwareWallet(List<Account> accounts) {
    return accounts.isNotEmpty && accounts.every((a) => a.accountType == AccountType.keystone);
  }

  Future<void> _createAccount() async {
    setState(() => _isLoading = true);

    try {
      final selectedWalletAccounts = _accounts.where((a) => a.walletIndex == _walletIndex).toList();

      if (_isHardwareWallet(selectedWalletAccounts)) {
        final created = await Navigator.push<bool?>(
          context,
          MaterialPageRoute(builder: (context) => AddHardwareAccountScreen(walletIndex: _walletIndex)),
        );
        if (created == true) {
          ref.invalidate(accountsProvider);
          ref.invalidate(activeAccountProvider);
          if (mounted) Navigator.of(context).pop();
        }
      } else {
        final draft = await _accountsService.createNewAccount(walletIndex: _walletIndex);
        final accountToSave = draft.copyWith(name: _accountName.text.trim());
        await _accountsService.addAccount(accountToSave);

        ref.invalidate(accountsProvider);
        ref.invalidate(activeAccountProvider);
        ref.read(firebaseMessagingServiceProvider).insertNewAddress(accountToSave.accountId);

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AccountReadyScreen(
                origin: AccountReadyOverviewOrigin.accountCreated,
                accountName: accountToSave.name,
                accountId: accountToSave.accountId,
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        final l10n = ref.read(l10nProvider);
        context.showErrorToaster(message: l10n.createAccountErrorCouldNotAdd);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    final activeAccount = ref.read(activeAccountProvider).value;
    _accounts = ref.read(accountsProvider).value ?? <Account>[];
    _walletIndex = _walletIndexForActiveAccount(_accounts, activeAccount);

    final l10n = ref.read(l10nProvider);
    _accountName.text = l10n.createAccountDefaultName(_accounts.length + 1);
    _accountName.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _accountName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.createAccountAppBarTitle),
      mainContent: NameField(controller: _accountName, subtitle: l10n.createAccountSubtitle),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: l10n.createAccountButton,
          onTap: _createAccount,
          isLoading: _isLoading,
          isDisabled: _isDisabled,
        ),
      ),
    );
  }
}
