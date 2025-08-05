import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/base_with_background.dart';
import 'package:resonance_network_wallet/features/components/dropdown_select.dart';
import 'package:resonance_network_wallet/features/components/transactions_list.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  final bool showAccountFilter;
  final String? fixedAccountId; // if set, hide filter popdown

  const TransactionsScreen({
    super.key,
    this.showAccountFilter = true,
    this.fixedAccountId,
  });

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final ScrollController _scrollController = ScrollController();
  List<String>?
  _selectedAccountIds; // List of account IDs to show transactions for

  @override
  void initState() {
    super.initState();

    // Initialize selection based on widget parameters
    if (widget.fixedAccountId != null) {
      _selectedAccountIds = [widget.fixedAccountId!];
    } else if (!widget.showAccountFilter) {
      // If not showing filter, use active account
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final activeAccount = ref.read(activeAccountProvider).value;
        if (activeAccount != null && mounted) {
          setState(() {
            _selectedAccountIds = [activeAccount.accountId];
          });
        }
      });
    } else {
      // If showing account filter, initialize with all accounts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final accounts = ref.read(accountsProvider).value;
        if (accounts != null && accounts.isNotEmpty && mounted) {
          setState(() {
            _selectedAccountIds = accounts.map((a) => a.accountId).toList();
          });
        }
      });
    }

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      // Use the current filter state
      if (_selectedAccountIds != null) {
        ref
            .read(
              filteredPaginationControllerProviderFamily(
                _selectedAccountIds,
              ).notifier,
            )
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
    if (widget.showAccountFilter) {
      // Full transactions screen with dropdown (accessed via navbar)
      return BaseWithBackground(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 27.0),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Transaction History',
                  style: TextStyle(
                    color: Color(0xFFE6E6E6),
                    fontSize: 16,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 13),
                Row(
                  children: [
                    Expanded(
                      child: ref
                          .watch(accountsProvider)
                          .when(
                            loading: () => const CircularProgressIndicator(),
                            error: (error, stack) => Text('Error: $error'),
                            data: (accounts) => DropdownSelect<String>(
                              initialValue: '_all_',
                              items: [
                                Item<String>(
                                  value: '_all_',
                                  label: 'All Accounts',
                                ),
                                ...accounts.map((Account account) {
                                  return Item<String>(
                                    value: account.accountId,
                                    label: account.name,
                                  );
                                }),
                              ],
                              onChanged: (selectedItem) {
                                final accounts = ref
                                    .read(accountsProvider)
                                    .value;
                                if (accounts == null) return;

                                setState(() {
                                  if (selectedItem?.value == '_all_') {
                                    _selectedAccountIds = accounts
                                        .map((a) => a.accountId)
                                        .toList();
                                  } else {
                                    _selectedAccountIds = [selectedItem!.value];
                                  }
                                });

                                // Immediately refresh data for new selection
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (_selectedAccountIds != null) {
                                    ref
                                        .read(
                                          // ignore: lines_longer_than_80_chars
                                          filteredPaginationControllerProviderFamily(
                                            _selectedAccountIds,
                                          ).notifier,
                                        )
                                        .loadingRefresh();
                                  }
                                });
                              },
                              disabled: false,
                            ),
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 13),
                Expanded(child: _buildBody()),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    } else {
      // Simple transactions screen with back button (accessed from main screen)
      return Scaffold(
        appBar: const WalletAppBar(title: 'Transaction History'),
        backgroundColor: const Color(0xFF0E0E0E),
        body: SafeArea(child: _buildBody()),
      );
    }
  }

  Widget _buildBody() {
    final accountsAsync = ref.watch(accountsProvider);

    return accountsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Text(
          'Error loading accounts: $error',
          style: const TextStyle(color: Colors.red),
        ),
      ),
      data: (accounts) {
        if (accounts.isEmpty) {
          return const Center(
            child: Text(
              'No accounts found.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        // Use the current account selection
        if (_selectedAccountIds == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // Watch the filtered transactions provider
        final filteredTransactionsAsync = ref.watch(
          filteredTransactionsProviderFamily(_selectedAccountIds),
        );
        final paginationState = ref.watch(
          filteredPaginationControllerProviderFamily(_selectedAccountIds),
        );

        return filteredTransactionsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text(
              'Error: $error',
              style: const TextStyle(color: Colors.red),
            ),
          ),
          data: (combinedData) {
            // Combine all transaction types for display
            final allTransactions = <TransactionEvent>[
              ...combinedData.pendingTransactions.cast<TransactionEvent>(),
              ...combinedData.reversibleTransfers.cast<TransactionEvent>(),
              ...combinedData.otherTransfers,
            ];

            if (allTransactions.isEmpty) {
              return const Center(
                child: Text(
                  'No transactions found.',
                  style: TextStyle(color: Colors.white),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(
                      filteredPaginationControllerProviderFamily(
                        _selectedAccountIds,
                      ).notifier,
                    )
                    .loadingRefresh();
              },
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: RecentTransactionsList(
                      transactions: allTransactions,
                      accountIds: _selectedAccountIds!,
                    ),
                  ),

                  // Show loading indicator when fetching more
                  if (paginationState.hasMore)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Center(
                          child: paginationState.isFetching
                              ? const CircularProgressIndicator()
                              : const SizedBox.shrink(),
                        ),
                      ),
                    ),

                  // Add bottom padding to ensure scroll can reach the threshold
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
