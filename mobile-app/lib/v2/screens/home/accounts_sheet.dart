import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/main/screens/add_hardware_account_screen.dart';
import 'package:resonance_network_wallet/services/firebase_messaging_service.dart';
import 'package:resonance_network_wallet/shared/utils/share_utils.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

Future<T?> showAccountsSheet<T>(BuildContext context) {
  return showAppModalBottomSheet(context: context, builder: (_) => const AccountsSheet());
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
  }

  void _closeEdit() {
    setState(() {
      _editingAccountId = null;
      _isEditingName = false;
      _isSavingName = false;
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
    final media = MediaQuery.of(context);
    final maxHeight = media.size.height - media.padding.top - 20;
    final sheetHeight = math.min(610.0, maxHeight);

    final accountsAsync = ref.watch(accountsProvider);
    final activeDisplayAccountAsync = ref.watch(activeAccountProvider);

    final accounts = accountsAsync.value ?? <Account>[];
    final activeDisplayAccount = activeDisplayAccountAsync.value;
    final displayAccounts = _displayAccounts(accounts);
    final activeAccountId = activeDisplayAccount?.account.accountId;
    final editingAccount = _editingAccountId == null
        ? null
        : displayAccounts.firstWhereOrNull((a) => a.accountId == _editingAccountId);

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
        child: SizedBox(
          height: sheetHeight,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            decoration: BoxDecoration(
              color: context.colors.sheetBackground,
              border: Border.all(color: context.colors.toasterBorder),
              borderRadius: BorderRadius.circular(24),
            ),
            child: _buildContent(
              accountsAsync: accountsAsync,
              activeDisplayAccountAsync: activeDisplayAccountAsync,
              displayAccounts: displayAccounts,
              activeAccountId: activeAccountId,
              editingAccount: editingAccount,
            ),
          ),
        ),
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
      return _buildCreateAccountView();
    }

    if (editingAccount != null) {
      return _buildEditAccountView(editingAccount);
    }

    return _buildAccountsListView(displayAccounts, activeAccountId);
  }

  Widget _buildAccountsListView(List<Account> displayAccounts, String? activeAccountId) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 32.0,
                  height: 32.0,
                  child: activeAccountId == null
                      ? const SizedBox()
                      : AccountGradientImage(accountId: activeAccountId, width: 32.0, height: 32.0),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Accounts',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minHeight: 20, minWidth: 20),
            ),
          ],
        ),
        const SizedBox(height: 40),
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
        _buildPrimarySheetButton(label: 'Add Account', isLoading: _isCreatingAccount, onTap: _createNewAccount),
      ],
    );
  }

  Widget _buildEditAccountView(Account account) {
    if (!_isEditingName && _nameController.text != account.name) {
      _nameController.text = account.name;
    }

    return FutureBuilder<String>(
      future: _checksumService.getHumanReadableName(account.accountId),
      builder: (context, snapshot) {
        final checksum = snapshot.connectionState == ConnectionState.done ? (snapshot.data ?? '-') : 'Loading...';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _closeEdit,
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minHeight: 20, minWidth: 20),
                ),
                const Text(
                  'Edit Account',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 20,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minHeight: 20, minWidth: 20),
                ),
              ],
            ),
            const SizedBox(height: 40),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account Name', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                    const SizedBox(height: 12),
                    _buildAccountNameField(account),
                    const SizedBox(height: 40),
                    Text('Address Details', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                    const SizedBox(height: 12),
                    _buildAddressDetails(account, checksum),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildPrimarySheetButton(
              label: 'Share Account Details',
              onTap: () => shareAccountDetails(context, account.accountId, checksum: checksum),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCreateAccountView() {
    final draft = _draftAccount!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSheetHeader(title: 'New Account', onBack: _closeCreateView),
        const SizedBox(height: 40),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Wallet Name', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                _buildCreatedNameField(),
                const SizedBox(height: 40),
                Text('Wallet Address', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                _buildCreateField(
                  value: AddressFormattingService.formatAddress(draft.accountId),
                  onCopy: () => context.copyTextWithToaster(draft.accountId),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 40),
                Text('Wallet Checkphrase', style: context.themeText.smallParagraph?.copyWith(color: Colors.white)),
                const SizedBox(height: 12),
                _buildCreateField(
                  value: _draftChecksum,
                  onCopy: () => context.copyTextWithToaster(_draftChecksum),
                  textStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: context.colors.accentPink,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildPrimarySheetButton(
          label: 'Create Account',
          isLoading: _isSavingCreatedAccount,
          onTap: _submitCreatedAccount,
        ),
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
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isActive ? context.colors.accentPink : Colors.white,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    balanceText,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: context.colors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _buildIconActionButton(icon: Icons.edit_outlined, iconSize: 20, onTap: () => _openEdit(account)),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountNameField(Account account) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _nameController,
              readOnly: !_isEditingName || _isSavingName,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: context.colors.accentPink,
                height: 1.35,
              ),
              cursorColor: context.colors.accentPink,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) {
                if (_isEditingName && !_isSavingName) {
                  _saveEditedName(account);
                }
              },
              onTap: () {
                if (!_isEditingName) {
                  setState(() => _isEditingName = true);
                }
              },
            ),
          ),
          _isSavingName
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                )
              : _buildIconActionButton(
                  icon: _isEditingName ? Icons.check : Icons.edit_outlined,
                  iconSize: 20,
                  onTap: () {
                    if (_isEditingName) {
                      _saveEditedName(account);
                    } else {
                      setState(() => _isEditingName = true);
                    }
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildCreatedNameField() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _createNameController,
              readOnly: !_isEditingCreatedName || _isSavingCreatedAccount,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white,
              ),
              cursorColor: Colors.white,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          _buildIconActionButton(
            icon: _isEditingCreatedName ? Icons.check : Icons.edit_outlined,
            iconSize: 20,
            onTap: () {
              setState(() => _isEditingCreatedName = !_isEditingCreatedName);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCreateField({required String value, required VoidCallback onCopy, required TextStyle textStyle}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: textStyle),
          ),
          const SizedBox(width: 8),
          _buildIconActionButton(icon: Icons.copy_outlined, iconSize: 20, onTap: onCopy),
        ],
      ),
    );
  }

  Widget _buildSheetHeader({required String title, VoidCallback? onBack}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: onBack == null
              ? const SizedBox()
              : IconButton(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
                ),
        ),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            height: 1,
          ),
        ),
        SizedBox(
          width: 24,
          height: 24,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minHeight: 24, minWidth: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressDetails(Account account, String checksum) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          _buildCopyRow(
            value: account.accountId,
            onCopy: () => context.copyTextWithToaster(account.accountId),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.35,
            ),
            maxLines: null,
            overflow: TextOverflow.visible,
          ),
          const SizedBox(height: 8),
          _buildCopyRow(
            value: checksum,
            onCopy: () => context.copyTextWithToaster(checksum),
            textStyle: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: context.colors.accentPink,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCopyRow({
    required String value,
    required VoidCallback onCopy,
    required TextStyle textStyle,
    int? maxLines = 1,
    TextOverflow overflow = TextOverflow.ellipsis,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(value, maxLines: maxLines, overflow: overflow, style: textStyle),
        ),
        const SizedBox(width: 8),
        _buildIconActionButton(icon: Icons.copy_outlined, isTiny: true, iconSize: 12, onTap: onCopy),
      ],
    );
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required double iconSize,
    required VoidCallback onTap,
    bool isTiny = false,
  }) {
    final double size = isTiny ? 20 : 40;
    final asset = isTiny ? GlassContainer.tinyAsset : GlassContainer.smallAsset;
    return SizedBox(
      width: size,
      height: size,
      child: GlassContainer(
        asset: asset,
        onTap: onTap,
        child: Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }

  Widget _buildPrimarySheetButton({required String label, required VoidCallback onTap, bool isLoading = false}) {
    return Button(label: label, onTap: onTap, isLoading: isLoading);
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
