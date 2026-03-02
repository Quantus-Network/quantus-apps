import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/shared_address_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/accounts/accounts_sheet.dart';
import 'package:resonance_network_wallet/features/main/screens/receive_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/notifications_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/send/send_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/account_details.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/action_button.dart';
import 'package:resonance_network_wallet/features/main/screens/wallet_main/history_section.dart';
import 'package:resonance_network_wallet/features/components/emergency_button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/notification_provider.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class WalletMain extends ConsumerStatefulWidget {
  const WalletMain({super.key});

  @override
  ConsumerState<WalletMain> createState() => _WalletMainState();
}

class _WalletMainState extends ConsumerState<WalletMain> {
  final NumberFormattingService _formattingService = NumberFormattingService();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    // Refresh balances with loading indicator
    final activeDisplayAccount = ref.read(activeAccountProvider).value;
    if (activeDisplayAccount != null) {
      ref.invalidate(balanceProviderFamily);
      // Trigger a loading refresh on the filtered controller
      // used by active transactions
      await ref
          .read(
            filteredPaginationControllerProviderFamily(
              AccountIdListCache.get([activeDisplayAccount.account.accountId]),
            ).notifier,
          )
          .loadingRefresh();
    }
    ref.invalidate(balanceProviderRaw);
    // Invalidate combined active display account provider to recompute
    ref.invalidate(activeAccountTransactionsProvider);
  }

  void _processIntentIfAvailable() {
    final sharedAccount = ref.read(sharedAccountIntentProvider);

    if (sharedAccount != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Clean up intent after consumption
        ref.read(sharedAccountIntentProvider.notifier).state = null;
        showSharedAddressActionSheet(context, sharedAccount);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    _processIntentIfAvailable();

    final activeDisplayAccountAsync = ref.watch(activeAccountProvider);
    final balanceAsync = ref.watch(balanceProvider);
    final activeAccountTransactionsAsync = ref.watch(activeAccountTransactionsProvider);
    final hasNotifications = ref.watch(notificationProvider).isNotEmpty;

    return activeDisplayAccountAsync.when(
      data: (activeDisplayAccount) {
        if (activeDisplayAccount == null) {
          return const Center(child: Text('No active account. Please log in.')); // Safe empty state
        }
        return ScaffoldBase.refreshable(
          appBar: WalletAppBar.custom(
            titleWidget: Row(
              children: [
                SvgPicture.asset('assets/logo/logo.svg', height: context.isTablet ? 45 : 25),
                const SizedBox(width: 9.0),
                SvgPicture.asset('assets/logo/logo-name.svg', height: context.isTablet ? 35.6 : 15.6),
              ],
            ),
            actions: [
              InkWell(
                child: Image.asset(
                  hasNotifications
                      ? 'assets/notification/notification_settings_icon.png'
                      : 'assets/notification/notification_top_icon.png',
                  width: 26,
                  height: 26,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) => const NotificationsScreen(),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;
                        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                        return SlideTransition(position: animation.drive(tween), child: child);
                      },
                    ),
                  );
                },
              ),
              const SizedBox(width: 16.0),
              InkWell(
                child: SvgPicture.asset('assets/wallet_icon.svg', width: 26, height: 26),
                onTap: () {
                  showAccountsSheet(context);
                },
              ),
            ],
          ),
          dim: 0,
          decorations: [
            Positioned(
              left: context.getHorizontalCenterPosition(252),
              bottom: -30,
              child: const Sphere(variant: 6, size: 252),
            ),
          ],
          scrollController: _scrollController,
          onRefresh: _refreshData,
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AccountDetails(
                        activeAccount: activeDisplayAccount.account,
                        isEntrustedAccount: activeDisplayAccount is EntrustedDisplayAccount,
                      ),
                      const SizedBox(height: 20),
                      balanceAsync.when(
                        data: (balance) => Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: _formattingService.formatBalance(balance),
                                style: context.themeText.extraLargeTitle?.copyWith(color: context.themeColors.light),
                              ),
                              TextSpan(
                                text: ' ${AppConstants.tokenSymbol}',
                                style: context.themeText.smallTitle?.copyWith(color: context.themeColors.light),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        loading: () => Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Skeleton(width: 200, height: 36),
                            Text(
                              ' ${AppConstants.tokenSymbol}',
                              style: context.themeText.smallTitle?.copyWith(color: context.themeColors.light),
                            ),
                          ],
                        ),
                        error: (err, stack) => SizedBox(
                          width: 250,
                          child: Text(
                            textAlign: TextAlign.center,
                            'Error loading balance',
                            style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (activeDisplayAccount is RegularAccount)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ActionButton(
                          type: ActionType.send,
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SendScreen()));
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
                    )
                  else if (activeDisplayAccount is EntrustedDisplayAccount)
                    const EmergencyButton(),
                  const SizedBox(height: 30),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: HistorySection(
                allTransactionsAsync: activeAccountTransactionsAsync,
                activeAccount: activeDisplayAccount.account,
                onRetry: _refreshData,
              ),
            ),
          ],
        );
      },
      loading: () => const ScaffoldBase(
        child: Center(child: CircularProgressIndicator(color: Color(0xFF0CE6ED))),
      ),
      error: (error, stack) => ScaffoldBase(
        child: Center(
          child: Text(
            'Error loading account: ${error.toString()}',
            style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
          ),
        ),
      ),
    );
  }
}
