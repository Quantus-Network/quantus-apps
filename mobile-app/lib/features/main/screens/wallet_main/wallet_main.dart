import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/shared_address_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/accounts_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/notifications_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/account_details.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/action_button.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/history_section.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class WalletMain extends ConsumerStatefulWidget {
  final String? address;

  const WalletMain({super.key, this.address});

  @override
  ConsumerState<WalletMain> createState() => _WalletMainState();
}

class _WalletMainState extends ConsumerState<WalletMain> {
  final NumberFormattingService _formattingService = NumberFormattingService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    if (widget.address != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSharedAddressActionSheet(context, widget.address!);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeAccountAsync = ref.watch(activeAccountProvider);
    final balanceAsync = ref.watch(balanceProvider);
    final activeAccountTransactionsAsync = ref.watch(
      activeAccountTransactionsProvider,
    );

    return activeAccountAsync.when(
      data: (activeAccount) {
        if (activeAccount == null) {
          return const Center(child: Text('No active account. Please log in.'));  // Safe empty state
        }
        return ScaffoldBase(
          dim: 0,
          decorations: [
            Positioned(
              left: context.getHorizontalCenterPosition(252),
              bottom: -30,
              child: const Sphere(variant: 6, size: 252),
            ),
          ],
          child: RefreshIndicator(
            onRefresh: () async {
              // Refresh balances with loading indicator
              final activeAccount = ref.read(activeAccountProvider).value;
              if (activeAccount != null) {
                ref.invalidate(balanceProviderFamily);
                // Trigger a loading refresh on the filtered controller
                // used by active transactions
                await ref
                    .read(
                      filteredPaginationControllerProviderFamily(
                        AccountIdListCache.get([activeAccount.accountId]),
                      ).notifier,
                    )
                    .loadingRefresh();
              }
              ref.invalidate(balanceProviderRaw);
              // Invalidate combined active account provider to recompute
              ref.invalidate(activeAccountTransactionsProvider);
            },
            color: const Color(0xFF0CE6ED),
            backgroundColor: Colors.black,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 31.0),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SvgPicture.asset(
                                'assets/logo/logo.svg',
                                height: context.isTablet ? 45 : 25,
                              ),
                              const SizedBox(width: 9.0),
                              SvgPicture.asset(
                                'assets/logo/logo-name.svg',
                                height: context.isTablet ? 35.6 : 15.6,
                              ),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              InkWell(
                                child: Image.asset(
                                  'assets/notification/notification_top_icon.png',
                                  width: 26,
                                  height: 26,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    PageRouteBuilder(
                                      pageBuilder: (context, animation, secondaryAnimation) =>
                                          const NotificationsScreen(),
                                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                        const begin = Offset(1.0, 0.0);
                                        const end = Offset.zero;
                                        const curve = Curves.easeInOut;
                                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                                        return SlideTransition(
                                          position: animation.drive(tween),
                                          child: child,
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 16.0),
                              InkWell(
                                child: SvgPicture.asset(
                                  'assets/wallet_icon.svg',
                                  width: 26,
                                  height: 26,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const AccountsScreen(),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          AccountDetails(activeAccount: activeAccount),
                          const SizedBox(height: 20),
                          balanceAsync.when(
                            data: (balance) => Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: _formattingService.formatBalance(balance),
                                    style: context.themeText.extraLargeTitle
                                        ?.copyWith(
                                          color: context.themeColors.light,
                                        ),
                                  ),
                                  TextSpan(
                                    text: ' ${AppConstants.tokenSymbol}',
                                    style: context.themeText.smallTitle?.copyWith(
                                      color: context.themeColors.light,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            loading: () => CircularProgressIndicator(
                              color: context.themeColors.circularLoader,
                            ),
                            error: (err, stack) => SizedBox(
                              width: 250,
                              child: Text(
                                textAlign: TextAlign.center,
                                'Error loading balance',
                                style: context.themeText.detail?.copyWith(
                                  color: context.themeColors.textError,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ActionButton(
                            type: ActionType.send,
                            onPressed: () {
                              Navigator.pushNamed(context, '/send');
                            },
                          ),
                          const SizedBox(width: 33),
                          ActionButton(
                            type: ActionType.receive,
                            onPressed: () {
                              showReceiveSheet(context);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
                SliverToBoxAdapter(
                  child: HistorySection(
                    allTransactionsAsync: activeAccountTransactionsAsync,
                    activeAccount: activeAccount,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const ScaffoldBase(
        child: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF0CE6ED),
          ),
        ),
      ),
      error: (error, stack) => ScaffoldBase(
        child: Center(
          child: Text(
            'Error loading account: ${error.toString()}',
            style: context.themeText.detail?.copyWith(
              color: context.themeColors.textError,
            ),
          ),
        ),
      ),
    );
  }

}
