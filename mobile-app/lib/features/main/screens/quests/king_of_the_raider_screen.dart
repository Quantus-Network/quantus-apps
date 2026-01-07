import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/basic_card.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/link_text.dart';
import 'package:resonance_network_wallet/features/components/raid_submission_action_sheet.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/account_associations_status.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/optin_position_status.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/quest_title.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/raider_quest_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/snackbar_extensions.dart';

class KingOfTheRaiderScreen extends ConsumerStatefulWidget {
  const KingOfTheRaiderScreen({super.key});

  @override
  ConsumerState<KingOfTheRaiderScreen> createState() => _KingOfTheRaiderScreenState();
}

class _KingOfTheRaiderScreenState extends ConsumerState<KingOfTheRaiderScreen> with WidgetsBindingObserver {
  final _taskmasterService = TaskmasterService();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void refreshRaiderSubmissions() {
    ref.invalidate(raiderSubmissionsProvider);
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
    final raiderSubmissionsAsync = ref.watch(raiderSubmissionsProvider);
    final effectiveSpacing = context.isSmallHeight ? 24.0 : 36.0;

    return ScaffoldBase.refreshable(
      appBar: WalletAppBar(title: 'King of The Raider'),
      onRefresh: () async {
        refreshRaiderSubmissions();
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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 17,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 96),
                              const Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [OptinPositionStatus()],
                              ),
                              SizedBox(height: effectiveSpacing),
                              const AccountAssociationsStatus(),
                              SizedBox(height: effectiveSpacing),
                              ...raiderSubmissionsAsync.when(
                                loading: () => [
                                  Center(child: CircularProgressIndicator(color: context.themeColors.circularLoader)),
                                ],
                                error: (error, stackTrace) => [
                                  Text(
                                    'Error fetching raider submissions.',
                                    style: context.themeText.detail?.copyWith(color: context.themeColors.textError),
                                  ),
                                  const SizedBox(height: 12),
                                  Button(
                                    variant: ButtonVariant.neutral,
                                    label: 'Try again',
                                    onPressed: refreshRaiderSubmissions,
                                  ),
                                ],
                                data: (state) {
                                  switch (state) {
                                    case RaiderSubmissionsOk():
                                      return [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          spacing: 4,
                                          children: [
                                            BasicCard(
                                              child: Row(
                                                children: [
                                                  Text('Active Raid: ', style: context.themeText.smallTitle),
                                                  Text('Alpha', style: context.themeText.smallTitle),
                                                ],
                                              ),
                                            ),
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
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadiusGeometry.circular(8),
                                                  ),
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
                                                  LinkText(
                                                    label: label,
                                                    url: value,
                                                    textStyle: context.themeText.smallParagraph,
                                                  ),
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
                                          Text(
                                            "You haven't submitted anything yet",
                                            style: context.themeText.smallParagraph,
                                          ),
                                      ];

                                    case NoActiveRaid():
                                      return [
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          spacing: 4,
                                          children: [
                                            BasicCard(
                                              child: Row(
                                                children: [
                                                  Text('No Active Raid: ', style: context.themeText.smallTitle),
                                                ],
                                              ),
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
                    ),
                    SizedBox(height: context.isSmallHeight ? 18 : 40),
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
}
