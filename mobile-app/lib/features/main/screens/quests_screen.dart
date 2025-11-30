import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/basic_card.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/loading_text_animation.dart';
import 'package:resonance_network_wallet/features/components/quests_promo_video.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/account_associations_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_stats_providers.dart';
import 'package:resonance_network_wallet/providers/opt_in_position_providers.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/clipboard_extensions.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> with WidgetsBindingObserver {
  final ReferralService _referralService = ReferralService();
  final ScrollController _scrollController = ScrollController();

  String? _referralCode;
  bool _isRewardProgramParticipant = false;
  bool _isLoadingParticipation = true;
  bool _isLastPromo = false;
  bool _isSubmitting = false;
  bool _isVisible = true;

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

  Future<void> _loadParticipationStatus() async {
    try {
      final isParticipant = await _referralService.getRewardProgramParticiation();
      setState(() {
        _isRewardProgramParticipant = isParticipant;
        _isLoadingParticipation = false;
      });
    } catch (e) {
      debugPrint('Error loading participation status: $e');
      setState(() {
        _isLoadingParticipation = false;
      });
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
    _loadParticipationStatus();
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

  void setVideoVisibility(bool isVisible) {
    if (mounted) {
      setState(() {
        _isVisible = isVisible;
      });
    }
  }

  void _setIsFinalVideo(bool isFinalVideo) {
    setState(() {
      _isLastPromo = isFinalVideo;
    });
  }

  Future<void> _handleOptIn(BuildContext context) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      await _referralService.optInRewardProgram();
      ref.invalidate(optInPositionProvider);

      setState(() {
        _isSubmitting = false;
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          this.context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'navbar'),
            builder: (context) => const Navbar(initialIndex: 3),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      print('Failed opting in reward program: $e');
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(accountsStatsProvider);
    final associationsAsync = ref.watch(accountAssociationsProvider);
    final positionAsync = ref.watch(optInPositionProvider);

    // Show videos for users who haven't opted in to the reward program
    if (_isLoadingParticipation) {
      return ScaffoldBase(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [_buildQuestTitle(), const LoadingTextAnimation()],
          ),
        ),
      );
    }

    if (!_isRewardProgramParticipant) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            QuestsPromoVideo(
              isSubmitting: _isSubmitting,
              closeSheet: null, // No close button for inline use
              setIsFinalVideo: _setIsFinalVideo,
              startFromBeginning: true,
              showCloseButton: false,
              isVisible: _isVisible,
            ),
            if (_isLastPromo)
              Positioned(
                bottom: 100, // Move down to avoid video text overlap
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.useOpacity(0.8)],
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Button(
                        label: "I'm In",
                        isLoading: _isSubmitting,
                        variant: ButtonVariant.primary,
                        onPressed: () {
                          _handleOptIn(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return ScaffoldBase.refreshable(
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
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [_buildOptInPosition(context, positionAsync), const SizedBox(width: 71)],
                                ),
                                SizedBox(height: context.isSmallHeight ? 18 : 37.0),
                                _buildAccountAssociations(context, associationsAsync),
                                SizedBox(height: context.isSmallHeight ? 18 : 37.0),
                                ..._buildAccountStats(context, statsAsync),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  child: Text(
                                    'Learn more about QQ',
                                    style: context.themeText.smallParagraph?.copyWith(
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  onTap: () {
                                    final Uri url = Uri.parse(AppConstants.questsPageUrl);
                                    launchUrl(url);
                                  },
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
                              Icon(Icons.copy, color: Colors.white, size: context.isTablet ? 26 : 22),
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
              Padding(padding: const EdgeInsets.only(top: 24), child: _buildQuestTitle()),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestTitle() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 11,
      children: [
        Image.asset('assets/navbar/qcat_navbar_icon.png', width: 82),
        Image.asset('assets/qq-logo.png', width: 226.35),
      ],
    );
  }

  Widget _buildOptInPosition(BuildContext context, AsyncValue<OptedInPosition> positionAsync) {
    return positionAsync.when(
      data: (pos) => Text(
        'Rewards no. #${pos.position}',
        style: context.themeText.smallParagraph?.copyWith(fontWeight: FontWeight.w600),
      ),
      loading: () => Row(
        children: [
          Text('Rewards no. ', style: context.themeText.smallParagraph?.copyWith(fontWeight: FontWeight.w600)),
          const Skeleton(width: 30, height: 16),
        ],
      ),
      error: (error, stack) => Text(
        'Error fetching opted in position.',
        style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
      ),
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

  Widget _buildAccountAssociations(BuildContext context, AsyncValue<AccountAssociations> associationsAsync) {
    final titleEth = 'ETH Address';
    final titleX = 'X Account';

    return associationsAsync.when(
      data: (associations) => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 12.0,
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAssociationCard(
                  context,
                  title: titleEth,
                  isLoading: false,
                  isAssociated: associations.ethAddress != null,
                ),
                _buildAssociationCard(
                  context,
                  title: titleX,
                  isLoading: false,
                  isAssociated: associations.xUsername != null,
                ),
              ],
            ),
          ),
          InkWell(
            child: SvgPicture.asset(
              'assets/settings_icon_off.svg',
              width: context.isTablet ? 28 : 21,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountAssociationsScreen()));
            },
          ),
        ],
      ),
      loading: () => Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        spacing: 12.0,
        children: [
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAssociationCard(context, title: titleEth, isLoading: true),
                _buildAssociationCard(context, title: titleX, isLoading: true),
              ],
            ),
          ),
          InkWell(
            child: SvgPicture.asset(
              'assets/settings_icon_off.svg',
              width: context.isTablet ? 28 : 21,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ],
      ),
      error: (error, stack) => Column(
        children: [
          Text(
            'Error fetching associated accounts.',
            style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
          ),
          const SizedBox(height: 12),
          Button(variant: ButtonVariant.neutral, label: 'Try again', onPressed: refreshAssociationsData),
        ],
      ),
    );
  }

  Widget _buildAssociationCard(
    BuildContext context, {
    required String title,
    required bool isLoading,
    bool isAssociated = false,
  }) {
    Widget getIcon() {
      if (isLoading) return const Skeleton(width: 40, height: 16);
      if (isAssociated == false) return Icon(Icons.close, color: context.themeColors.buttonDanger);

      return Icon(Icons.check, color: context.themeColors.buttonSuccess);
    }

    return BasicCard(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: context.themeText.paragraph),
          getIcon(),
        ],
      ),
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
