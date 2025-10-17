import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/basic_card.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/quests_promo_video.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/loading_text_animation.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_stats_providers.dart';
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

class _QuestsScreenState extends ConsumerState<QuestsScreen>
    with WidgetsBindingObserver {
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
      final isParticipant = await _referralService
          .getRewardProgramParticiation();
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
    final params = await _referralService.getShareLinkParameters();
    SharePlus.instance.share(params);
  }

  void _copyReferralCode() {
    if (_referralCode != null) {
      ClipboardExtensions.copyTextWithSnackbar(
        context,
        _referralCode!,
        message: 'Referral code copied to clipboard',
      );
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

  void refreshData() {
    ref.invalidate(accountsStatsProvider);
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.useOpacity(0.8),
                      ],
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

    return ScaffoldBase(
      padding: const EdgeInsetsGeometry.all(0),
      decorations: [
        const Positioned(
          top: 180,
          right: -34,
          child: Sphere(variant: 2, size: 194),
        ),
        const Positioned(
          left: -60,
          bottom: 0,
          child: Sphere(variant: 7, size: 240.68),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsStatsProvider);
        },
        color: const Color(0xFF0CE6ED),
        backgroundColor: Colors.black,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
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
                                  children: [
                                     SizedBox(height:  context.isSmallHeight? 132: 163),
                                    ..._buildAccountStats(context, statsAsync),
                                    const SizedBox(height: 16),
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          TextSpan(
                                            text:
                                                'Want to start mining ${AppConstants.tokenSymbol} token and earn rewards? ',
                                            style: context
                                                .themeText
                                                .smallParagraph,
                                          ),
                                          TextSpan(
                                            text: 'Learn more here',
                                            style: context
                                                .themeText
                                                .smallParagraph
                                                ?.copyWith(
                                                  decoration:
                                                      TextDecoration.underline,
                                                ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () {
                                                final Uri url = Uri.parse(
                                                  AppConstants
                                                      .tutorialsAndGuidesUrl,
                                                );
                                                launchUrl(url);
                                              },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                         SizedBox(height: context.isSmallHeight ? 18: 40),
                        Text(
                          'Click to Copy Referral Code',
                          style: context.themeText.smallParagraph,
                        ),
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: _copyReferralCode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 21,
                              vertical: 11,
                            ),
                            decoration: ShapeDecoration(
                              color: context.themeColors.background,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              _referralCode ?? 'Loading...',
                              style: context.themeText.paragraph,
                            ),
                          ),
                        ),
                        const SizedBox(height: 27),
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
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: _buildQuestTitle(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  List<Widget> _buildAccountStats(
    BuildContext context,
    AsyncValue<AccountStats> statsAsync,
  ) {
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
          'Error loading account: ${error.toString()}',
          style: context.themeText.detail?.copyWith(
            color: context.themeColors.textError,
          ),
        ),
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
          isLoading
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    color: Color(0xFF0CE6ED),
                    strokeWidth: 1,
                  ),
                )
              : Text('$stat', style: context.themeText.smallTitle),
        ],
      ),
    );
  }

  Widget _buildDecoration() {
    return Container(
      width: 85,
      height: context.isSmallHeight ? 380: 462,
      decoration: const ShapeDecoration(
        gradient: LinearGradient(
          begin: Alignment(0.03, -1.00),
          end: Alignment(-0.03, 1),
          colors: [Color(0xFF0000FF), Color(0xFFED4CCE), Color(0xFFFFE91F)],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(10),
            bottomRight: Radius.circular(10),
          ),
        ),
      ),
    );
  }
}
