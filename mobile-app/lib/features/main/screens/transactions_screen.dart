import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/base_with_background.dart';
import 'package:resonance_network_wallet/features/components/dropdown_select.dart';
import 'package:resonance_network_wallet/features/components/transactions_list.dart';
import 'package:resonance_network_wallet/models/wallet_state_manager.dart';
import 'package:resonance_network_wallet/providers/transaction_history_provider.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final provider = Provider.of<TransactionHistoryProvider>(
      context,
      listen: false,
    );
    provider.fetchInitialTransactions();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        provider.fetchMoreTransactions();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Provider.of<TransactionHistoryProvider>(
        context,
        listen: false,
      ).refreshTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Consumer<TransactionHistoryProvider>(
                    builder: (context, provider, child) {
                      return Expanded(
                        child: DropdownSelect<String>(
                          initialValue: '_all_',
                          items: [
                            Item<String>(value: '_all_', label: 'All Accounts'),
                            ...provider.accounts.map((Account value) {
                              return Item<String>(
                                value: value.accountId,
                                label: value.name,
                              );
                            }),
                          ],
                          onChanged: (selectedItem) {
                            final provider =
                                Provider.of<TransactionHistoryProvider>(
                                  context,
                                  listen: false,
                                );

                            if (selectedItem?.value == '_all_') {
                              provider.setAccountIds(
                                provider.accounts
                                    .map((a) => a.accountId)
                                    .toList(),
                              );
                            } else {
                              provider.setAccountIds([selectedItem!.value]);
                            }
                          },
                          disabled: provider.isLoading,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),
                  Consumer<TransactionHistoryProvider>(
                    builder: (context, provider, child) {
                      return SizedBox(
                        width: 75,
                        child: DropdownSelect<int>(
                          initialValue: provider.pageSize,
                          items: AppConstants.pageSizeList.map((int value) {
                            return Item<int>(value: value, label: '$value');
                          }).toList(),
                          onChanged: (selectedItem) {
                            if (selectedItem != null) {
                              provider.setPageSize(selectedItem.value);
                            }
                          },
                          disabled: provider.isLoading,
                        ),
                      );
                    },
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
  }

  Widget _buildBody() {
    return Consumer<TransactionHistoryProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.transactions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (provider.error != null) {
          return Center(
            child: Text(
              provider.error!,
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        if (provider.transactions.isEmpty) {
          return const Center(
            child: Text(
              'No transactions found.',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final manager = Provider.of<WalletStateManager>(context, listen: false);

        return RefreshIndicator(
          onRefresh: () => provider.refreshTransactions(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: RecentTransactionsList(
                  transactions: provider.transactions,
                  currentWalletAddress:
                      manager.walletData.data!.account.accountId,
                ),
              ),

              if (provider.isLoading && provider.hasMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),

              // Add some bottom padding to ensure scroll can reach the threshold
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );
      },
    );
  }
}
