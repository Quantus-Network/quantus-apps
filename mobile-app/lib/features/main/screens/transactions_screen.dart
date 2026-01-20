import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/select.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/transaction_list_item.dart';
import 'package:resonance_network_wallet/features/components/transactions_list.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/services/transaction_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final bool showAccountFilter;
  final String? fixedAccountId; // if set, hide filter popdown

  const TransactionsScreen({super.key, this.showAccountFilter = true, this.fixedAccountId});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<String>? _selectedAccountIds;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _initialize(BuildContext context, WidgetRef ref) {
    if (_isInitialized) return;

    final txService = ref.read(transactionServiceProvider);
    final accountsValue = ref.watch(accountsProvider);
    accountsValue.when(
      data: (accounts) {
        if (!_isInitialized) {
          List<String> accountIds;
          if (widget.fixedAccountId != null) {
            accountIds = [widget.fixedAccountId!];
          } else if (!widget.showAccountFilter) {
            final activeDisplayAccount = ref.read(activeAccountProvider).value;
            accountIds = activeDisplayAccount != null ? [activeDisplayAccount.account.accountId] : [];
          } else {
            accountIds = accounts.map((a) => a.accountId).toList();
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _selectedAccountIds = accountIds;
              _isInitialized = true;
            });
            ref
                .read(filteredPaginationControllerProviderFamily(AccountIdListCache.get(accountIds)).notifier)
                .loadingRefresh();

            final txIntent = ref.read(transactionIntentProvider);
            if (txIntent != null) {
              ref.read(transactionIntentProvider.notifier).state = null;
              final role = txService.getTransactionRole(txIntent);
              final activeAccount = ref.read(activeAccountProvider).value;
              showTransactionActionSheet(
                context,
                transaction: txIntent,
                role: role,
                config: TransactionService.getTransactionDetailViewConfig(
                  transaction: txIntent,
                  role: role,
                  activeAccount: activeAccount,
                ),
              );
            }
          });
        }
      },
      loading: () {},
      error: (error, stack) {
        if (!_isInitialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _isInitialized = true;
              _selectedAccountIds = [];
            });
          });
        }
      },
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_selectedAccountIds != null) {
        ref
            .read(filteredPaginationControllerProviderFamily(AccountIdListCache.get(_selectedAccountIds!)).notifier)
            .fetchMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _initialize(context, ref);

    if (!_isInitialized) {
      return ScaffoldBase(
        decorations: [
          Positioned(
            bottom: -20,
            left: context.getHorizontalCenterPosition(251.62),
            child: const Sphere(variant: 8, size: 251.62),
          ),
        ],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_selectedAccountIds == null) {
      // Handles the case where initialization is complete but there are no
      // accounts
      return widget.showAccountFilter ? _buildFilterableScaffold() : _buildSimpleScaffold();
    }

    if (widget.showAccountFilter) {
      return _buildFilterableScaffold();
    } else {
      return _buildSimpleScaffold();
    }
  }

  Widget _buildSimpleScaffold() {
    return ScaffoldBase(
      decorations: [
        Positioned(
          bottom: -20,
          left: context.getHorizontalCenterPosition(251.62),
          child: const Sphere(variant: 8, size: 251.62),
        ),
      ],
      appBar: WalletAppBar(title: 'Transaction History'),
      child: _buildBody(),
    );
  }

  Widget _buildFilterableScaffold() {
    final accountsAsync = ref.watch(accountsProvider);

    return ScaffoldBase(
      extendBodyBehindNavBar: true,
      decorations: [
        Positioned(
          bottom: -20,
          left: context.getHorizontalCenterPosition(251.62),
          child: const Sphere(variant: 8, size: 251.62),
        ),
      ],
      appBar: WalletAppBar.simple(title: 'Transaction History'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 13),
          accountsAsync.when(
            data: (accounts) {
              if (accounts.isEmpty) {
                return Text('No accounts found.', style: context.themeText.smallParagraph);
              }
              return _buildAccountSelect();
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, st) => Text('Error loading accounts.', style: TextStyle(color: context.themeColors.textError)),
          ),
          const SizedBox(height: 13),
          Expanded(child: _buildBody()),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAccountSelect() {
    final accounts = ref.read(accountsProvider).value!;
    final allAccountsSelected = _selectedAccountIds != null && _selectedAccountIds!.length == accounts.length;

    return Select<String>(
      initialValue: allAccountsSelected ? '_all_' : _selectedAccountIds?.firstOrNull,
      items: [
        Item<String>(value: '_all_', label: 'All Accounts'),
        ...accounts.map((account) => Item<String>(value: account.accountId, label: account.name)),
      ],
      onSelect: (selectedItem) {
        final newSelectedIds = selectedItem.value == '_all_'
            ? accounts.map((a) => a.accountId).toList()
            : [selectedItem.value];

        setState(() {
          _selectedAccountIds = newSelectedIds;
        });

        ref
            .read(filteredPaginationControllerProviderFamily(AccountIdListCache.get(newSelectedIds)).notifier)
            .loadingRefresh();
      },
      disabled: false,
    );
  }

  Widget _buildBody() {
    if (_selectedAccountIds == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_selectedAccountIds!.isEmpty) {
      return Center(child: Text('No accounts selected.', style: context.themeText.smallParagraph));
    }

    final accountIds = _selectedAccountIds!;
    final filteredTransactionsAsync = ref.watch(filteredTransactionsProviderFamily(AccountIdListCache.get(accountIds)));
    final paginationState = ref.watch(filteredPaginationControllerProviderFamily(AccountIdListCache.get(accountIds)));

    return filteredTransactionsAsync.when(
      loading: () => ShaderMask(
        shaderCallback: (Rect bounds) {
          return const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.center,
            colors: [Colors.transparent, Colors.white],
            stops: [0.0, 0.5],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: ShapeDecoration(
                  color: const Color(0x0d0c1014),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      const TransactionSkeleton(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: context.themeColors.darkGray, thickness: 1),
                      ),
                      const TransactionSkeleton(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: context.themeColors.darkGray, thickness: 1),
                      ),
                      const TransactionSkeleton(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: context.themeColors.darkGray, thickness: 1),
                      ),
                      const TransactionSkeleton(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: context.themeColors.darkGray, thickness: 1),
                      ),
                      const TransactionSkeleton(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(color: context.themeColors.darkGray, thickness: 1),
                      ),
                      const TransactionSkeleton(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
      data: (combinedData) {
        final txService = ref.read(transactionServiceProvider);
        final allTransactions = txService.combineAndDeduplicateTransactions(
          pendingCancellationIds: combinedData.pendingCancellationIds,
          pendingTransactions: combinedData.pendingTransactions,
          reversibleTransfers: combinedData.reversibleTransfers,
          otherTransfers: combinedData.otherTransfers,
        );

        if (allTransactions.isEmpty && !paginationState.isFetching) {
          return Center(child: Text('No transactions found.', style: context.themeText.smallParagraph));
        }

        return RefreshIndicator(
          onRefresh: () => ref
              .read(filteredPaginationControllerProviderFamily(AccountIdListCache.get(accountIds)).notifier)
              .loadingRefresh(),
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Colors.transparent, Colors.white],
                stops: [0.0, 0.5],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                if (allTransactions.isNotEmpty)
                  SliverToBoxAdapter(
                    child: RecentTransactionsList(
                      backgroundColor: const Color(0x0d0c1014),
                      transactions: allTransactions,
                      accountIds: accountIds,
                    ),
                  ),
                if (paginationState.isFetching && allTransactions.isEmpty)
                  const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
                if (paginationState.hasMore && paginationState.isFetching)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
