import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/select.dart';
import 'package:resonance_network_wallet/features/components/select_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/tree_list.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/account_settings_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/add_hardware_account_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/create_account_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/create_wallet_and_backup_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/import_wallet_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/entrusted_account_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/utils/feature_flags.dart';
import 'dart:math';

enum _WalletMoreAction { createWallet, importWallet, addHardwareWallet }

class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final HumanReadableChecksumService _checksumService = HumanReadableChecksumService();
  final NumberFormattingService _formattingService = NumberFormattingService();

  bool _isCreatingAccount = false;
  int? _selectedWalletIndex;

  bool _isHardwareWallet(List<Account> accounts) {
    return accounts.isNotEmpty && accounts.every((a) => a.accountType == AccountType.keystone);
  }

  int _nextWalletIndex(List<Account> accounts) {
    if (accounts.isEmpty) return 0;
    final maxIndex = accounts.map((a) => a.walletIndex).reduce((a, b) => a > b ? a : b);
    return maxIndex + 1;
  }

  Map<int, List<Account>> _groupByWallet(List<Account> accounts) {
    final grouped = <int, List<Account>>{};
    for (final a in accounts) {
      grouped.putIfAbsent(a.walletIndex, () => []).add(a);
    }
    for (final entry in grouped.entries) {
      entry.value.sort((a, b) => a.index.compareTo(b.index));
    }
    return Map.fromEntries(grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  String _walletLabel(int walletIndex, List<Account> accounts) {
    if (_isHardwareWallet(accounts)) return 'Hardware Wallet';
    return 'Wallet ${walletIndex + 1}';
  }

  Future<void> _createNewAccount() async {
    setState(() {
      _isCreatingAccount = true;
    });
    try {
      final accounts = ref.read(accountsProvider).value ?? <Account>[];
      int selectedWallet = getSelectedWalletIndex(accounts);
      final grouped = _groupByWallet(accounts);
      final selectedWalletAccounts = grouped[selectedWallet] ?? const <Account>[];

      if (_isHardwareWallet(selectedWalletAccounts)) {
        await Navigator.push<bool?>(
          context,
          MaterialPageRoute(builder: (context) => AddHardwareAccountScreen(walletIndex: selectedWallet)),
        );
      } else {
        await Navigator.push<bool?>(
          context,
          MaterialPageRoute(builder: (context) => CreateAccountScreen(walletIndex: selectedWallet)),
        );
      }
      // Providers will automatically refresh when a new account is added
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingAccount = false;
        });
      }
    }
  }

  int getSelectedWalletIndex(List<Account> accounts) {
    final selectedWallet = _selectedWalletIndex ?? (accounts.isNotEmpty ? accounts.first.walletIndex : 0);
    return selectedWallet;
  }

  Future<void> _openWalletMoreActions() async {
    final accounts = ref.read(accountsProvider).value ?? <Account>[];
    final nextWalletIndex = _nextWalletIndex(accounts);

    final items = [
      Item(value: _WalletMoreAction.createWallet, label: 'Create new wallet'),
      Item(value: _WalletMoreAction.importWallet, label: 'Import wallet'),
    ];

    if (FeatureFlags.enableKeystoneHardwareWallet) {
      items.add(Item(value: _WalletMoreAction.addHardwareWallet, label: 'Add hardware wallet'));
    }

    showSelectActionSheet<_WalletMoreAction>(context, items, (item) async {
      final result = await (switch (item.value) {
        _WalletMoreAction.createWallet => Navigator.push<bool?>(
          context,
          MaterialPageRoute(
            builder: (context) => CreateWalletAndBackupScreen(walletIndex: nextWalletIndex, popOnComplete: true),
          ),
        ),
        _WalletMoreAction.importWallet => Navigator.push<bool?>(
          context,
          MaterialPageRoute(
            builder: (context) => ImportWalletScreen(walletIndex: nextWalletIndex, popOnComplete: true),
          ),
        ),
        _WalletMoreAction.addHardwareWallet => Navigator.push<bool?>(
          context,
          MaterialPageRoute(
            builder: (context) => AddHardwareAccountScreen(walletIndex: nextWalletIndex, isNewWallet: true),
          ),
        ),
      });
      if (result == true && mounted) {
        ref.invalidate(accountsProvider);
        ref.invalidate(activeAccountProvider);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      decorations: [
        Positioned(
          right: -40,
          top: MediaQuery.of(context).size.height * 0.3,
          child: const Sphere(variant: 2, size: 194),
        ),
        const Positioned(left: -40, bottom: 0, child: Sphere(variant: 7, size: 240.681)),
      ],
      appBar: WalletAppBar(
        title: 'Your Accounts',
        actions: [IconButton(onPressed: _openWalletMoreActions, icon: const Icon(Icons.more_horiz))],
      ),
      child: Column(
        children: [
          // _buildWalletSelector(),
          Expanded(child: _buildAccountsList()),

          Button(
            variant: ButtonVariant.glassOutline,
            label: _walletActionLabel(),
            onPressed: _isCreatingAccount ? null : _createNewAccount,
          ),

          SizedBox(height: context.themeSize.bottomButtonSpacing),
        ],
      ),
    );
  }

  String _walletActionLabel() {
    final accounts = ref.watch(accountsProvider).value ?? <Account>[];
    final grouped = _groupByWallet(accounts);
    final selectedWallet = getSelectedWalletIndex(accounts);
    final selectedAccounts = grouped[selectedWallet] ?? const <Account>[];
    return _isHardwareWallet(selectedAccounts) ? 'Add Hardware Account' : 'Add Account';
  }

  Widget _buildAccountsList() {
    final accountsAsync = ref.watch(accountsProvider);
    final activeAccountAsync = ref.watch(activeAccountProvider);

    return accountsAsync.when(
      loading: () => Center(child: CircularProgressIndicator(color: context.themeColors.circularLoader)),
      error: (error, _) => Center(
        child: Text(
          'Failed to load accounts: $error',
          style: context.themeText.smallParagraph?.copyWith(color: Colors.white70),
        ),
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return Center(
            child: Text('No accounts found.', style: context.themeText.smallParagraph?.copyWith(color: Colors.white70)),
          );
        }

        return activeAccountAsync.when(
          loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
          error: (error, _) => Center(
            child: Text('Failed to load active account: $error', style: const TextStyle(color: Colors.white70)),
          ),
          data: (activeAccount) {
            if (_selectedWalletIndex == null) {
              final initial = activeAccount?.walletIndex ?? accounts.first.walletIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedWalletIndex == null) setState(() => _selectedWalletIndex = initial);
              });
            }

            final grouped = _groupByWallet(accounts);
            if (grouped.length <= 1) {
              final walletAccounts = grouped.values.first;
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                itemCount: walletAccounts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 25),
                itemBuilder: (context, index) {
                  final account = walletAccounts[index];
                  final bool isActive = account.accountId == activeAccount?.accountId;
                  return _buildAccountListItem(account, isActive, index);
                },
              );
            }

            final selectedWallet = _selectedWalletIndex ?? grouped.keys.first;
            final children = <Widget>[];
            var sectionIndex = 0;
            for (final entry in grouped.entries) {
              final walletIndex = entry.key;
              final walletAccounts = entry.value;

              if (sectionIndex > 0) children.add(const SizedBox(height: 18));
              children.add(
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _walletLabel(walletIndex, walletAccounts),
                    style: context.themeText.detail?.copyWith(
                      color: walletIndex == selectedWallet
                          ? context.themeColors.textPrimary
                          : context.themeColors.textMuted,
                    ),
                  ),
                ),
              );

              for (var i = 0; i < walletAccounts.length; i++) {
                if (i > 0) children.add(const SizedBox(height: 25));
                final account = walletAccounts[i];
                final bool isActive = account.accountId == activeAccount?.accountId;
                children.add(_buildAccountListItem(account, isActive, i));
              }
              sectionIndex++;
            }

            return ListView(padding: const EdgeInsets.symmetric(vertical: 16.0), children: children);
          },
        );
      },
    );
  }

  Widget _buildAccountListItem(Account account, bool isActive, int index) {
    final entrustedAccountsAsync = ref.watch(entrustedAccountsProvider(account));
    final entrustedAccountsData = entrustedAccountsAsync.value ?? [];

    final entrustedNodes = entrustedAccountsData.map((entrusted) => TreeNode<Account>(data: entrusted)).toList();

    final double constraintMaxHeight = min(entrustedNodes.length * 52, 104);

    return InkWell(
      onTap: () async {
        await ref.read(activeAccountProvider.notifier).setActiveAccount(account);
        if (mounted) Navigator.pop(context);
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: context.isTablet ? 20 : 8, vertical: 8),
                      height: context.themeSize.accountListItemHeight,
                      decoration: ShapeDecoration(
                        color: isActive ? context.themeColors.surfaceActive : context.themeColors.surface,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(width: 1, color: context.themeColors.borderLight),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 24),
                          Expanded(
                            child: Consumer(
                              builder: (context, ref, child) {
                                final balanceAsync = ref.watch(balanceProviderFamily(account.accountId));

                                return FutureBuilder<String>(
                                  future: _checksumService.getHumanReadableName(account.accountId),
                                  builder: (context, checksumSnapshot) {
                                    final humanChecksum = checksumSnapshot.data ?? '';

                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              account.name,
                                              style: context.themeText.smallParagraph?.copyWith(
                                                color: isActive ? Colors.black : Colors.white,
                                              ),
                                            ),
                                            if (entrustedNodes.isNotEmpty)
                                              const AccountTag('Guardian', color: Color(0xFF9747FF)),
                                          ],
                                        ),
                                        Text(
                                          humanChecksum,
                                          style: context.themeText.detail?.copyWith(
                                            color: isActive
                                                ? context.themeColors.checksumDarker
                                                : context.themeColors.checksum,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              context.isTablet
                                                  ? account.accountId
                                                  // ignore: lines_longer_than_80_chars
                                                  : AddressFormattingService.formatAddress(account.accountId),
                                              style: context.themeText.tiny?.copyWith(
                                                color: isActive
                                                    ? context.themeColors.darkGray
                                                    : context.themeColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        balanceAsync.when(
                                          loading: () => Text(
                                            'loading balance...',
                                            style: context.themeText.detail?.copyWith(
                                              color: isActive
                                                  ? context.themeColors.darkGray
                                                  : context.themeColors.light,
                                            ),
                                          ),
                                          error: (error, _) => Text(
                                            'error loading',
                                            style: context.themeText.detail?.copyWith(
                                              color: isActive
                                                  ? context.themeColors.darkGray
                                                  : context.themeColors.textPrimary,
                                            ),
                                          ),
                                          data: (balance) => Text.rich(
                                            TextSpan(
                                              children: [
                                                TextSpan(
                                                  text: _formattingService.formatBalance(balance),
                                                  style: context.themeText.detail?.copyWith(
                                                    color: isActive
                                                        ? context.themeColors.darkGray
                                                        : context.themeColors.textPrimary,
                                                  ),
                                                ),
                                                TextSpan(
                                                  text: ' ${AppConstants.tokenSymbol}',
                                                  style: context.themeText.tiny?.copyWith(
                                                    color: isActive
                                                        ? context.themeColors.darkGray
                                                        : context.themeColors.textPrimary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: SvgPicture.asset(
                      'assets/settings_icon_off.svg',
                      width: context.isTablet ? 28 : 21,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    onPressed: () async {
                      // Get current data from providers
                      final balanceAsync = ref.read(balanceProviderFamily(account.accountId));
                      final checksumName = await _checksumService.getHumanReadableName(account.accountId);

                      balanceAsync.when(
                        loading: () {
                          // Show loading or handle appropriately
                        },
                        error: (error, _) {
                          // Handle error
                        },
                        data: (balance) async {
                          if (!mounted) return;
                          await Navigator.push<bool?>(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(name: AppConstants.accountSettingsRouteName),
                              builder: (context) => AccountSettingsScreen(
                                account: account,
                                balance: _formattingService.formatBalance(balance, addSymbol: true),
                                checksumName: checksumName,
                              ),
                            ),
                          );
                          // Providers will automatically refresh if needed
                        },
                      );
                    },
                  ),
                ],
              ),
              if (entrustedNodes.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: constraintMaxHeight),
                  child: TreeListView<Account>(
                    showExpandCollapse: false,
                    nodes: entrustedNodes,
                    nodeBuilder: (context, node, depth) {
                      final entrusted = node.data;
                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: ShapeDecoration(
                                color: context.themeColors.darkGray,
                                shape: RoundedRectangleBorder(
                                  side: const BorderSide(color: Color(0x26FFFFFF)),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(entrusted.name, style: context.themeText.smallParagraph),
                                  const AccountTag('Entrusted'),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: SvgPicture.asset(
                              'assets/settings_icon_off.svg',
                              width: context.isTablet ? 28 : 21,
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            ),
                            onPressed: () async {
                              // Get current data from providers
                              final balanceAsync = ref.read(balanceProviderFamily(entrusted.accountId));
                              final checksumName = await _checksumService.getHumanReadableName(entrusted.accountId);

                              balanceAsync.when(
                                loading: () {},
                                error: (error, _) {},
                                data: (balance) async {
                                  if (!mounted) return;
                                  await Navigator.push<bool?>(
                                    context,
                                    MaterialPageRoute(
                                      settings: const RouteSettings(name: AppConstants.accountSettingsRouteName),
                                      builder: (context) => AccountSettingsScreen(
                                        account: entrusted,
                                        balance: _formattingService.formatBalance(balance, addSymbol: true),
                                        checksumName: checksumName,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
          Positioned(
            // calculating the middle point
            top: (context.themeSize.accountListItemHeight / 2) - (context.themeSize.accountListItemLogoWidth / 2),
            left: (context.themeSize.accountListItemLogoWidth / 2) * -1,
            child: AccountGradientImage(
              accountId: account.accountId,
              width: context.themeSize.accountListItemLogoWidth,
              height: context.themeSize.accountListItemLogoWidth,
            ),
          ),
        ],
      ),
    );
  }
}

class AccountTag extends StatelessWidget {
  final String label;
  final Color? color;

  const AccountTag(this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFFFFD541), // Default to Entrusted color (Yellow-ish)
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: context.themeText.tiny?.copyWith(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }
}
