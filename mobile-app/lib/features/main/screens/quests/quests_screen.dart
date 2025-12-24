import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/basic_card.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/link_text.dart';
import 'package:resonance_network_wallet/features/components/loading_text_animation.dart';
import 'package:resonance_network_wallet/features/components/quests_promo_video.dart';
import 'package:resonance_network_wallet/features/components/raid_submission_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/main/screens/navbar.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/account_associations_status.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/optin_position_status.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/quest_title.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_stats_providers.dart';
import 'package:resonance_network_wallet/providers/opt_in_position_providers.dart';
import 'package:resonance_network_wallet/providers/raider_quest_providers.dart';
import 'package:resonance_network_wallet/services/referral_service.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/snackbar_extensions.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  final TaskmasterService _taskmasterService = TaskmasterService();
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

  void refreshRaiderSubmissions() {
    ref.invalidate(raiderSubmissionsProvider);
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

  String? extractXStatusId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // Expected path: /{username}/status/{id}
    final segments = uri.pathSegments;

    if (segments.length >= 3 && segments[1] == 'status') {
      final id = segments[2];
      return RegExp(r'^\d+$').hasMatch(id) ? id : null;
    }

    return null;
  }

  Future<void> _handleRemoveSubmission(String id) async {
    try {
      await _taskmasterService.removeRaidSubmission(id);
      if (mounted) {
        context.showSuccessSnackbar(title: 'Success removed!', message: 'Success removing raid submission!');
      }
      ref.invalidate(raiderSubmissionsProvider);
    } catch (e) {
      print('Failed removing raid submission: $e');

      if (mounted) {
        context.showErrorSnackbar(title: 'Failed removing!', message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show videos for users who haven't opted in to the reward program
    if (_isLoadingParticipation) {
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

    final raiderSubmissionsAsync = ref.watch(raiderSubmissionsProvider);
    final effectiveSpacing = context.isSmallHeight ? 24.0 : 36.0;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const QuestTitle(),
              const Center(child: OptinPositionStatus()),
              SizedBox(height: effectiveSpacing),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text('Associated Accounts', style: context.themeText.smallParagraph, textAlign: TextAlign.start),
                  const AccountAssociationsStatus(),
                ],
              ),
              SizedBox(height: effectiveSpacing),
              ...raiderSubmissionsAsync.when(
                loading: () => [Center(child: CircularProgressIndicator(color: context.themeColors.circularLoader))],
                error: (error, stackTrace) => [
                  Text(
                    'Error fetching raider submissions.',
                    style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
                  ),
                  const SizedBox(height: 12),
                  Button(variant: ButtonVariant.neutral, label: 'Try again', onPressed: refreshRaiderSubmissions),
                ],
                data: (state) {
                  switch (state) {
                    case RaiderSubmissionsOk():
                      return [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            Text('Active Raid', style: context.themeText.smallParagraph, textAlign: TextAlign.start),
                            BasicCard(child: Text('Alpha', style: context.themeText.smallTitle)),
                            LinkText(
                              label: 'Learn more about QQ',
                              url: AppConstants.raidQuestsPageUrl,
                              textStyle: context.themeText.smallParagraph,
                            ),
                          ],
                        ),
                        SizedBox(height: effectiveSpacing),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Raid Submissions', style: context.themeText.smallTitle),
                            const SizedBox(width: 12),
                            InkWell(
                              child: Container(
                                decoration: ShapeDecoration(
                                  color: context.themeColors.buttonNeutral,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadiusGeometry.circular(8)),
                                ),
                                child: const Icon(Icons.add, color: Colors.black),
                              ),
                              onTap: () {
                                showRaidSubmissionActionSheet(context);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (state.submissions.isNotEmpty)
                          Column(
                            spacing: 4,
                            children: state.submissions.asMap().entries.map((entry) {
                              final index = entry.key + 1;
                              final value = entry.value;
                              final label = extractXStatusId(value) ?? 'Unknown';

                              return Row(
                                children: [
                                  Text('$index. '),
                                  LinkText(label: label, url: value, textStyle: context.themeText.smallParagraph),
                                  InkWell(
                                    child: Icon(Icons.delete, color: context.themeColors.buttonDanger),
                                    onTap: () {
                                      _handleRemoveSubmission(label);
                                    },
                                  ),
                                ],
                              );
                            }).toList(),
                          )
                        else
                          Text("You haven't submitted anything yet", style: context.themeText.smallParagraph),
                      ];

                    case NoActiveRaid():
                      return [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 4,
                          children: [
                            BasicCard(
                              child: Row(children: [Text('No Active Raid: ', style: context.themeText.smallTitle)]),
                            ),
                            LinkText(
                              label: 'Learn more about QQ',
                              url: AppConstants.raidQuestsPageUrl,
                              textStyle: context.themeText.smallParagraph,
                            ),
                          ],
                        ),
                      ];

                    case NoTwitterLinked():
                      return [Text('Please link your X account', style: context.themeText.smallTitle)];
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
