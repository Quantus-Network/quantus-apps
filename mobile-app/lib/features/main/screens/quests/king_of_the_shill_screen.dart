import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/basic_card.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/copy_icon.dart';
import 'package:resonance_network_wallet/features/components/link_text.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/account_associations_status.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/optin_position_status.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/quest_title.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_stats_providers.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:share_plus/share_plus.dart';

class KingOfTheShillScreen extends ConsumerStatefulWidget {
  const KingOfTheShillScreen({super.key});

  @override
  ConsumerState<KingOfTheShillScreen> createState() => _KingOfTheShillScreenState();
}

class _KingOfTheShillScreenState extends ConsumerState<KingOfTheShillScreen> with WidgetsBindingObserver {
  final ReferralService _referralService = ReferralService();
  final ScrollController _scrollController = ScrollController();

  String? _referralCode;

  Future<void> _loadReferralCode() async {
    try {
      final myReferralCode = await _referralService.getMyInviteCode();
      setState(() {
        _referralCode = myReferralCode;
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _shareReferralLink() async {
    final params = await _referralService.getShareLinkParameters(context.sharePositionRect());
    SharePlus.instance.share(params);
  }

  void _copyReferralCode() {
    if (_referralCode != null) {
      ClipboardExtensions.copyTextWithSnackbar(context, _referralCode!, message: 'Referral code copied to clipboard');
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReferralCode();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void refreshStatsData() {
    ref.invalidate(accountsStatsProvider);
  }

  void refreshAssociationsData() {
    ref.invalidate(accountAssociationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(accountsStatsProvider);

    return ScaffoldBase.refreshable(
      appBar: WalletAppBar(title: 'King of The Shill'),
      padding: const EdgeInsetsGeometry.all(0),
      onRefresh: () async {
        refreshStatsData();
        refreshAssociationsData();
      },
      scrollController: _scrollController,
      decorations: [
        const Positioned(top: 180, right: -34, child: Sphere(variant: 2, size: 194)),
        const Positioned(left: -60, bottom: 0, child: Sphere(variant: 7, size: 240.68)),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 11),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 44),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 17,
                        children: [
                          _buildDecoration(),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 96),
                                const Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [OptinPositionStatus(), SizedBox(width: 71)],
                                ),
                                SizedBox(height: context.isSmallHeight ? 18 : 37.0),
                                const AccountAssociationsStatus(),
                                SizedBox(height: context.isSmallHeight ? 18 : 37.0),
                                ..._buildAccountStats(context, statsAsync),
                                const SizedBox(height: 16),
                                LinkText(
                                  label: 'Learn more about QQ',
                                  url: AppConstants.shillQuestsPageUrl,
                                  textStyle: context.themeText.smallParagraph,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.isSmallHeight ? 18 : 40),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: InkWell(
                        onTap: _copyReferralCode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          decoration: ShapeDecoration(
                            color: context.themeColors.background,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          ),
                          child: Row(
                            spacing: 12.0,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _referralCode ?? 'Loading...',
                                style: context.themeText.smallParagraph,
                                textAlign: TextAlign.center,
                              ),
                              const CopyIcon(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Button(
                        variant: ButtonVariant.glassOutline,
                        label: 'Share Referral Link',
                        onPressed: _shareReferralLink,
                      ),
                    ),
                  ],
                ),
              ),
              const QuestTitle(),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildAccountStats(BuildContext context, AsyncValue<AccountStats> statsAsync) {
    return statsAsync.when(
      data: (stats) => [
        _buildStatCard(context, 'Referrals:', stats.referralCount),
        const SizedBox(height: 9),
        _buildStatCard(context, 'Sends:', stats.sendCount),
        const SizedBox(height: 9),
        _buildStatCard(context, 'Reversals:', stats.reversalCount),
        const SizedBox(height: 9),
        _buildStatCard(context, 'Mining:', stats.miningCount),
      ],
      loading: () => [
        _buildStatCard(context, 'Referrals:', null),
        const SizedBox(height: 9),
        _buildStatCard(context, 'Sends:', null),
        const SizedBox(height: 9),
        _buildStatCard(context, 'Reversals:', null),
        const SizedBox(height: 9),
        _buildStatCard(context, 'Mining:', null),
      ],
      error: (error, stack) => [
        Text(
          'Error fetching account stats.',
          style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
        ),
        const SizedBox(height: 12),
        Button(variant: ButtonVariant.neutral, label: 'Try again', onPressed: refreshStatsData),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, String title, int? stat) {
    final isLoading = stat == null;

    return BasicCard(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: context.themeText.smallTitle),
          isLoading ? const Skeleton(width: 40, height: 16) : Text('$stat', style: context.themeText.smallTitle),
        ],
      ),
    );
  }

  Widget _buildDecoration() {
    return Container(
      width: 85,
      height: context.isSmallHeight ? 415 : 480,
      decoration: const ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.03, -1.00),
          end: Alignment(-0.03, 1),
          colors: [Color(0xFF0000FF), Color(0xFFED4CCE), Color(0xFFFFE91F)],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(topRight: Radius.circular(10), bottomRight: Radius.circular(10)),
        ),
      ),
    );
  }
}
