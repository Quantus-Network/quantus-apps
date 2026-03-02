import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/account_gradient_image.dart';
import 'package:resonance_network_wallet/features/components/shared_address_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
import 'package:resonance_network_wallet/v2/components/button_icon.dart';
import 'package:resonance_network_wallet/v2/screens/home/accounts_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/receive/receive_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_sheet.dart';
import 'package:resonance_network_wallet/v2/screens/settings/settings_screen.dart';
import 'package:resonance_network_wallet/utils/feature_flags.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_screen.dart';
import 'package:resonance_network_wallet/providers/account_id_list_cache.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/active_account_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/filtered_all_transactions_provider.dart';
import 'package:resonance_network_wallet/providers/route_intent_providers.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';
import 'package:resonance_network_wallet/v2/screens/home/activity_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final NumberFormattingService _fmt = NumberFormattingService();

  Future<void> _refresh() async {
    final active = ref.read(activeAccountProvider).value;
    ref.invalidate(balanceProviderFamily);
    ref.invalidate(balanceProviderRaw);
    ref.invalidate(activeAccountTransactionsProvider);
    if (active != null) {
      await ref
          .read(filteredPaginationControllerProviderFamily(AccountIdListCache.get([active.account.accountId])).notifier)
          .loadingRefresh();
    }
  }

  void _processIntentIfAvailable() {
    final shared = ref.read(sharedAccountIntentProvider);
    if (shared != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(sharedAccountIntentProvider.notifier).state = null;
        showSharedAddressActionSheet(context, shared);
      });
    }
  }

  Future<void> toggleBalanceHidden(bool isBalanceHidden) async {
    final isBalanceHiddenNotifier = ref.read(isBalanceHiddenProvider.notifier);
    await isBalanceHiddenNotifier.setIsBalanceHidden(!isBalanceHidden);
  }

  @override
  Widget build(BuildContext context) {
    _processIntentIfAvailable();

    final isBalanceHidden = ref.watch(isBalanceHiddenProvider);
    final accountAsync = ref.watch(activeAccountProvider);
    final balanceAsync = ref.watch(balanceProvider);
    final txAsync = ref.watch(activeAccountTransactionsProvider);
    final colors = context.colors;
    final text = context.themeText;

    return accountAsync.when(
      loading: () => Scaffold(
        backgroundColor: colors.background,
        body: Center(child: CircularProgressIndicator(color: colors.textPrimary)),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: colors.background,
        body: Center(
          child: Text('Error: $e', style: text.detail?.copyWith(color: colors.textError)),
        ),
      ),
      data: (active) {
        if (active == null) {
          return Scaffold(
            backgroundColor: colors.background,
            body: const Center(child: Text('No active account')),
          );
        }
        return Scaffold(
          backgroundColor: colors.background,
          body: RefreshIndicator(
            color: colors.textPrimary,
            backgroundColor: colors.surface,
            onRefresh: _refresh,
            child: GradientBackground(
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _buildContent(active, balanceAsync, isBalanceHidden, colors, text)),
                  SliverToBoxAdapter(
                    child: ActivitySection(txAsync: txAsync, activeAccount: active.account, onRetry: _refresh),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 58)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    DisplayAccount active,
    AsyncValue<BigInt> balanceAsync,
    bool isBalanceHidden,
    AppColorsV2 colors,
    AppTextTheme text,
  ) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
            _buildTopBar(active, isBalanceHidden, colors),
            const SizedBox(height: 64),
            _buildBalance(balanceAsync, isBalanceHidden, colors, text),
            const SizedBox(height: 64),
            if (active is RegularAccount) _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(DisplayAccount active, bool isBalanceHidden, AppColorsV2 colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => showAccountsSheet(context),
          child: AccountGradientImage(accountId: active.account.accountId, width: 40.0, height: 40.0),
        ),
        Row(
          children: [
            _glassCircleButton(
              icon: isBalanceHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              colors: colors,
              onTap: () => toggleBalanceHidden(isBalanceHidden),
            ),
            const SizedBox(width: 12),
            _glassCircleButton(
              icon: Icons.settings_outlined,
              colors: colors,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreenV2())),
            ),
          ],
        ),
      ],
    );
  }

  Widget _glassCircleButton({required IconData icon, required AppColorsV2 colors, required VoidCallback onTap}) {
    return ButtonIcon.circular(icon: icon, onTap: onTap);
  }

  Widget _buildBalance(AsyncValue<BigInt> balanceAsync, bool isBalanceHidden, AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        balanceAsync.when(
          data: (balance) {
            final formatted = isBalanceHidden ? '-----' : _fmt.formatBalance(balance);
            final usdFormatted = isBalanceHidden ? '-----' : '\$${_fmt.formatBalance(balance)}';
            return Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Text(
                        '$formatted ${AppConstants.tokenSymbol}',
                        style: text.extraLargeTitle?.copyWith(color: colors.textSecondary),
                      ),
                    ),
                    Text(
                      '$formatted ${AppConstants.tokenSymbol}',
                      style: text.extraLargeTitle?.copyWith(color: colors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('≈ $usdFormatted', style: text.paragraph?.copyWith(color: colors.textSecondary)),
              ],
            );
          },
          loading: () => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Skeleton(width: 200, height: 36),
              Text(' ${AppConstants.tokenSymbol}', style: text.smallTitle?.copyWith(color: colors.textPrimary)),
            ],
          ),
          error: (_, _) => Text('Error loading balance', style: text.detail?.copyWith(color: colors.textError)),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final receiveCard = _actionCard(
      iconAsset: 'assets/v2/action_receive.svg',
      label: 'Receive',
      onTap: () => showReceiveSheetV2(context),
    );

    final sendCard = _actionCard(
      iconAsset: 'assets/v2/action_send.svg',
      label: 'Send',
      onTap: () => showSendSheetV2(context),
    );

    if (!FeatureFlags.enableSwap) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(width: 104, child: receiveCard),
          const SizedBox(width: 32),
          SizedBox(width: 104, child: sendCard),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: receiveCard),
        const SizedBox(width: 15),
        Expanded(child: sendCard),
        const SizedBox(width: 15),
        Expanded(
          child: _actionCard(
            iconAsset: 'assets/v2/action_swap.svg',
            label: 'Swap',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SwapScreen())),
          ),
        ),
      ],
    );
  }

  Widget _actionCard({required String iconAsset, required String label, required VoidCallback onTap}) {
    return Button(
      label: label,
      onTap: onTap,
      icon: SvgPicture.asset(iconAsset, width: 24, height: 24),
      iconPlacement: IconPlacement.top,
      padding: const EdgeInsets.all(14),
    );
  }
}
