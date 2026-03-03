import 'package:collection/collection.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/features/main/screens/add_hardware_account_screen.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/account_shared_components.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/create_account_view.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/edit_account_view.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

Future<T?> showAccountsSheet<T>(BuildContext context) async {
  return BottomSheetContainer.show<T>(context, builder: (_) => const AccountsSheet());
}

class AccountsSheet extends ConsumerStatefulWidget {
  const AccountsSheet({super.key});

  @override
  ConsumerState<AccountsSheet> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsSheet> {
  final AccountsService _accountsService = AccountsService();
  final NumberFormattingService _formattingService = NumberFormattingService();
  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _createNameController = TextEditingController();

  bool _isCreatingAccount = false;
  bool _isSavingCreatedAccount = false;
  bool _isEditingName = false;
  bool _isEditingCreatedName = false;
  bool _isSavingName = false;
  bool _isCreateViewOpen = false;
  String? _editingAccountId;
  String _editingAccountChecksum = 'Loading...';
  Account? _draftAccount;
  String _draftChecksum = 'Loading...';

  bool _isHardwareWallet(List<Account> accounts) {
    return accounts.isNotEmpty && accounts.every((a) => a.accountType == AccountType.keystone);
  }

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

  List<Account> _displayAccounts(List<Account> accounts) {
    final sorted = [...accounts];
    sorted.sort((a, b) {
      final walletCmp = a.walletIndex.compareTo(b.walletIndex);
      if (walletCmp != 0) return walletCmp;
      return a.index.compareTo(b.index);
    });
    return sorted;
  }

  Future<void> _createNewAccount() async {
    if (_isCreatingAccount) return;

    setState(() => _isCreatingAccount = true);
    try {
      final accounts = ref.read(accountsProvider).value ?? <Account>[];
      final activeDisplayAccount = ref.read(activeAccountProvider).value;
      final walletIndex = _walletIndexForActiveAccount(accounts, activeDisplayAccount);
      final selectedWalletAccounts = accounts.where((a) => a.walletIndex == walletIndex).toList();

      if (_isHardwareWallet(selectedWalletAccounts)) {
        final created = await Navigator.push<bool?>(
          context,
          MaterialPageRoute(builder: (context) => AddHardwareAccountScreen(walletIndex: walletIndex)),
        );
        if (created == true) {
          ref.invalidate(accountsProvider);
          ref.invalidate(activeAccountProvider);
        }
      } else {
        final draft = await _accountsService.createNewAccount(walletIndex: walletIndex);
        final checksum = await _checksumService.getHumanReadableName(draft.accountId);
        if (!mounted) return;
        _createNameController.text = draft.name;
        setState(() {
          _draftAccount = draft;
          _draftChecksum = checksum;
          _isCreateViewOpen = true;
          _isEditingCreatedName = false;
        });
      }
    } catch (_) {
      if (mounted) {
        context.showErrorToaster(message: 'Could not add account.');
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingAccount = false);
      }
    }
  }

  Future<void> _switchAccount(Account account) async {
    await ref.read(activeAccountProvider.notifier).setActiveAccount(RegularAccount(account));
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openEdit(Account account) async {
    _nameController.text = account.name;

    setState(() {
      _editingAccountId = account.accountId;
      _isEditingName = false;
    });

    final checksum = await _checksumService.getHumanReadableName(account.accountId);
    if (!mounted) return;
    setState(() {
      _editingAccountChecksum = checksum;
    });
  }

  void _closeEdit() {
    setState(() {
      _editingAccountId = null;
      _isEditingName = false;
      _isSavingName = false;
      _editingAccountChecksum = 'Loading...';
    });
  }

  void _closeCreateView() {
    setState(() {
      _isCreateViewOpen = false;
      _isEditingCreatedName = false;
      _isSavingCreatedAccount = false;
      _draftAccount = null;
      _draftChecksum = 'Loading...';
      _createNameController.clear();
    });
  }

  Future<void> _saveEditedName(Account account) async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      context.showErrorToaster(message: "Account name can't be empty");
      return;
    }
    if (name == account.name) {
      setState(() => _isEditingName = false);
      return;
    }

    setState(() => _isSavingName = true);
    try {
      await _accountsService.updateAccountName(account, name);
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
      if (mounted) {
        setState(() {
          _isEditingName = false;
        });
      }
    } catch (_) {
      if (mounted) {
        context.showErrorToaster(message: 'Failed to rename account.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingName = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _createNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final activeDisplayAccountAsync = ref.watch(activeAccountProvider);

    final accounts = accountsAsync.value ?? <Account>[];
    final activeDisplayAccount = activeDisplayAccountAsync.value;
    final displayAccounts = _displayAccounts(accounts);
    final activeAccountId = activeDisplayAccount?.account.accountId;
    final editingAccount = _editingAccountId == null
        ? null
        : displayAccounts.firstWhereOrNull((a) => a.accountId == _editingAccountId);

    String title = 'Accounts';
    VoidCallback? onBack;
    Widget titleBuilder(String title) => Row(
      spacing: 12,
      children: [
        SizedBox(
          width: 32.0,
          height: 32.0,
          child: AccountGradientImage(accountId: activeAccountId ?? 'loading..', width: 32.0, height: 32.0),
        ),
        Text(
          title,
          style: context.themeText.smallTitle?.copyWith(color: context.colors.textPrimary, fontSize: 20),
          textAlign: TextAlign.center,
        ),
      ],
    );

    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 20;
    final sheetHeight = math.min(610.0, maxHeight);

    if (_isCreateViewOpen && _draftAccount != null) {
      title = 'New Account';
      onBack = _closeCreateView;
    } else if (editingAccount != null) {
      title = 'Edit Account';
      onBack = _closeEdit;
    }

    return BottomSheetContainer(
      title: title,
      titleBuilder: editingAccount == null && !_isCreateViewOpen ? titleBuilder : null,
      onBack: onBack,
      height: sheetHeight,
      child: _buildContent(
        accountsAsync: accountsAsync,
        activeDisplayAccountAsync: activeDisplayAccountAsync,
        displayAccounts: displayAccounts,
        activeAccountId: activeAccountId,
        editingAccount: editingAccount,
      ),
    );
  }

  Widget _buildContent({
    required AsyncValue<List<Account>> accountsAsync,
    required AsyncValue<DisplayAccount?> activeDisplayAccountAsync,
    required List<Account> displayAccounts,
    required String? activeAccountId,
    required Account? editingAccount,
  }) {
    if (accountsAsync.isLoading || activeDisplayAccountAsync.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (accountsAsync.hasError) {
      return Center(
        child: Text(
          'Failed to load accounts.',
          style: context.themeText.smallParagraph?.copyWith(color: Colors.white70),
        ),
      );
    }

    if (activeDisplayAccountAsync.hasError) {
      return Center(
        child: Text(
          'Failed to load active account.',
          style: context.themeText.smallParagraph?.copyWith(color: Colors.white70),
        ),
      );
    }

    if (_isCreateViewOpen && _draftAccount != null) {
      return CreateAccountView(
        draftAccount: _draftAccount!,
        draftChecksum: _draftChecksum,
        isSaving: _isSavingCreatedAccount,
        isEditingName: _isEditingCreatedName,
        nameController: _createNameController,
        onToggleEditingName: () => setState(() => _isEditingCreatedName = !_isEditingCreatedName),
        onSubmit: _submitCreatedAccount,
      );
    }

    if (editingAccount != null) {
      if (!_isEditingName && _nameController.text != editingAccount.name) {
        _nameController.text = editingAccount.name;
      }

      return EditAccountView(
        account: editingAccount,
        checksum: _editingAccountChecksum,
        isEditingName: _isEditingName,
        isSavingName: _isSavingName,
        nameController: _nameController,
        onToggleEditingName: () => setState(() => _isEditingName = !_isEditingName),
        onSaveName: () => _saveEditedName(editingAccount),
      );
    }

    return _buildAccountsListView(displayAccounts, activeAccountId);
  }

  Widget _buildAccountsListView(List<Account> displayAccounts, String? activeAccountId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: displayAccounts.isEmpty
              ? Center(
                  child: Text(
                    'No accounts found.',
                    style: context.themeText.smallParagraph?.copyWith(color: Colors.white70),
                  ),
                )
              : ListView.separated(
                  itemCount: displayAccounts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 20),
                  itemBuilder: (_, index) {
                    final account = displayAccounts[index];
                    return _buildAccountRow(account, account.accountId == activeAccountId);
                  },
                ),
        ),
        const SizedBox(height: 24),
        Button.simple(label: 'Add Account', onTap: _createNewAccount, isLoading: _isCreatingAccount),
      ],
    );
  }

  Widget _buildAccountRow(Account account, bool isActive) {
    final balanceAsync = ref.watch(balanceProviderFamily(account.accountId));
    final balanceText = balanceAsync.when(
      loading: () => 'Loading...',
      error: (_, _) => 'Balance unavailable',
      data: (balance) => '${_formattingService.formatBalance(balance)} ${AppConstants.tokenSymbol}',
    );

    return GestureDetector(
      onTap: () => _switchAccount(account),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colors.borderSubtle, width: 0.9),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    account.name,
                    style: context.themeText.paragraph!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isActive ? context.colors.accentPink : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(balanceText, style: context.themeText.detail!.copyWith(color: context.colors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            AccountIconActionButton(icon: Icons.edit_outlined, onTap: () => _openEdit(account)),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCreatedAccount() async {
    final draft = _draftAccount;
    if (draft == null) return;
    final name = _createNameController.text.trim();
    if (name.isEmpty) {
      context.showErrorToaster(message: "Account name can't be empty");
      return;
    }

    setState(() => _isSavingCreatedAccount = true);
    try {
      final accountToSave = draft.copyWith(name: name);
      await _accountsService.addAccount(accountToSave);
      ref.invalidate(accountsProvider);
      ref.invalidate(activeAccountProvider);
      ref.read(firebaseMessagingServiceProvider).insertNewAddress(accountToSave.accountId);

      if (mounted) {
        _closeCreateView();
      }
    } catch (_) {
      if (mounted) {
        context.showErrorToaster(message: 'Failed to create account.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingCreatedAccount = false);
      }
    }
  }
}
