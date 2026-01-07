import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/list_item.dart';
import 'package:resonance_network_wallet/features/components/loading_text_animation.dart';
import 'package:resonance_network_wallet/features/components/quests_promo_video.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/account_associations_status.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/king_of_the_raider_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/king_of_the_shill_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/optin_position_status.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/quest_title.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_stats_providers.dart';
import 'package:resonance_network_wallet/providers/opt_in_position_providers.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  final bool playPromoVideo;
  const QuestsScreen({super.key, required this.playPromoVideo});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  final ReferralService _referralService = ReferralService();
  final ScrollController _scrollController = ScrollController();

  bool _isRewardProgramParticipant = false;
  bool _isLoadingParticipation = true;
  bool _isLastPromo = false;
  bool _isSubmitting = false;
  bool _isVisible = true;

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

  @override
  void initState() {
    super.initState();
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
    // Show loading state for users who haven't opted in to the reward program or if the promo video is not playing yet
    if (_isLoadingParticipation || !widget.playPromoVideo) {
      return const ScaffoldBase(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              QuestTitle(padding: EdgeInsetsGeometry.zero),
              LoadingTextAnimation(),
            ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const QuestTitle(),
              const OptinPositionStatus(),
              SizedBox(height: context.isSmallHeight ? 18 : 37.0),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text('Associated Accounts', style: context.themeText.smallParagraph, textAlign: TextAlign.start),
                  const AccountAssociationsStatus(),
                ],
              ),
            ],
          ),
        ),

        SliverToBoxAdapter(child: SizedBox(height: context.isSmallHeight ? 18 : 37.0)),
        SliverToBoxAdapter(child: Text('Quests', style: context.themeText.smallParagraph)),
        const SliverToBoxAdapter(child: SizedBox(height: 4)),
        SliverList(
          delegate: SliverChildListDelegate([
            ListItem(
              title: 'King of The Raider',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const KingOfTheRaiderScreen()));
              },
            ),
            const SizedBox(height: 12),
            ListItem(
              title: 'King of The Shill',
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const KingOfTheShillScreen()));
              },
            ),
          ]),
        ),
      ],
    );
  }
}
