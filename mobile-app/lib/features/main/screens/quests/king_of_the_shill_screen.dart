import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/features/components/inner_shadow_container.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/wallet_app_bar.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/quest_constants.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/raid_submission_action_sheet.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/raider_quest_providers.dart';
import 'package:url_launcher/url_launcher.dart';

class KingOfTheShillScreen extends ConsumerStatefulWidget {
  const KingOfTheShillScreen({super.key});

  @override
  ConsumerState<KingOfTheShillScreen> createState() => _KingOfTheShillScreenState();
}

class _KingOfTheShillScreenState extends ConsumerState<KingOfTheShillScreen> {
  final TaskmasterService _taskmasterService = TaskmasterService();
  int? _rank;
  int? _totalImpressions;

  @override
  void initState() {
    super.initState();
    final asyncValue = ref.read(raiderSubmissionsProvider);
    if (asyncValue.value is RaiderSubmissionsOk) {
      _loadRaidStats((asyncValue.value as RaiderSubmissionsOk).activeRaid.id);
    }
  }

  Future<void> _loadRaidStats(int raidId) async {
    try {
      final stats = await _taskmasterService.getRaidStats(raidId);
      if (mounted) {
        setState(() {
          _rank = stats.rank;
          _totalImpressions = stats.totalImpressions;
        });
      }
    } catch (e) {
      debugPrint('Error loading raid stats: $e');
    }
  }

  void _showHowItWorksDialog() {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: GestureDetector(
              onTap: () {},
              child: Container(
                width: 280,
                padding: const EdgeInsets.all(24),
                decoration: ShapeDecoration(
                  color: context.themeColors.background2,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Color(0x66F4F6F9)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('HOW IT WORKS', style: context.themeText.paragraph),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: const Icon(Icons.close, color: Colors.white, size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _buildStep('Step 1', 'Find an active raid on X (Twitter)'),
                    const SizedBox(height: 16),
                    _buildStep('Step 2', 'Reply to the raid post with your shill'),
                    const SizedBox(height: 16),
                    _buildStep('Step 3', 'Submit your reply URL here to get verified and earn rewards'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.50),
            fontSize: 14,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  void refreshRaiderSubmissions() {
    ref.invalidate(raiderSubmissionsProvider);
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final raiderSubmissionsAsync = ref.watch(raiderSubmissionsProvider);

    ref.listen(raiderSubmissionsProvider, (prev, next) {
      final state = next.value;
      if (state is RaiderSubmissionsOk && _rank == null) {
        _loadRaidStats(state.activeRaid.id);
      }
    });

    return ScaffoldBase(
      appBar: WalletAppBar(
        title: 'King of The Shill',
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showHowItWorksDialog,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: ShapeDecoration(
                  color: context.themeColors.background2,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Color(0x7F6734BA)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: InnerShadowContainer.standard(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ImageFiltered(
                          imageFilter: ImageFilter.blur(sigmaX: 52, sigmaY: 52),
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: RadialGradient(
                                center: Alignment(0.77, -0.56),
                                radius: 2.8,
                                colors: questKingOfTheShillGradient,
                                stops: [0.45, 0.54, 0.57],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(
                              child: Column(
                                children: [
                                  Text('KING OF THE SHILL', style: context.themeText.paragraph),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Join social raids. Get rewarded for\nverified posts.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.50),
                                      fontSize: 14,
                                      fontFamily: 'Inter',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 40),
                            raiderSubmissionsAsync.when(
                              loading: () => const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                ),
                              ),
                              error: (_, _) => _buildStatsBox(0, _totalImpressions, _rank),
                              data: (state) {
                                if (state is RaiderSubmissionsOk) {
                                  return _buildStatsBox(state.submissions.length, _totalImpressions, _rank);
                                }
                                return _buildStatsBox(0, _totalImpressions, _rank);
                              },
                            ),
                            const SizedBox(height: 24),
                            _buildPastSubmissionsSection(raiderSubmissionsAsync),
                            const Spacer(),
                            _buildSubmitSection(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            GestureDetector(
              onTap: () => showRaidSubmissionActionSheet(context),
              child: InnerShadowContainer.standard(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: ShapeDecoration(
                    color: const Color(0x33F4F6F9),
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: Color(0x33F4F6F9)),
                      borderRadius: BorderRadius.circular(42),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Add Raid Submission',
                    style: context.themeText.smallTitle?.copyWith(color: context.themeColors.textPrimary),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBox(int submissions, int? totalImpressions, int? rank) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        color: context.themeColors.background2.useOpacity(0.4),
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0x33F4F6F9)),
          borderRadius: BorderRadius.circular(8),
        ),
        shadows: const [BoxShadow(color: Color(0x3F000000), blurRadius: 4, offset: Offset(4, 4))],
      ),
      child: Column(
        children: [
          _buildStatRow(
            'Submissions',
            Text(
              '$submissions',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildStatRow('Total impressions', _buildLoadingOrValue(totalImpressions, Colors.white)),
          const SizedBox(height: 16),
          _buildStatRow('Rank', _buildLoadingOrValue(rank, context.themeColors.pink, isRank: true)),
        ],
      ),
    );
  }

  Widget _buildLoadingOrValue(int? value, Color color, {bool isRank = false}) {
    if (value == null) {
      return SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: color));
    }
    final text = isRank ? (value > 0 ? '#$value' : '#-') : '$value';
    return Text(
      text,
      style: TextStyle(color: color, fontSize: 14, fontFamily: 'Fira Code', fontWeight: FontWeight.w400),
    );
  }

  Widget _buildStatRow(String label, Widget valueWidget) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFF4F6F9),
            fontSize: 14,
            fontFamily: 'Fira Code',
            fontWeight: FontWeight.w400,
          ),
        ),
        valueWidget,
      ],
    );
  }

  Widget _buildPastSubmissionsSection(AsyncValue<RaiderSubmissionsState> raiderSubmissionsAsync) {
    return Column(
      children: [
        const Text(
          'Past Submissions',
          style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Fira Code', fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: Color(0x33F4F6F9)),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: raiderSubmissionsAsync.when(
            loading: () => const SizedBox(
              height: 80,
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
            error: (_, _) => Text(
              'Failed to load submissions',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontFamily: 'Inter'),
            ),
            data: (state) {
              if (state is RaiderSubmissionsOk && state.submissions.isNotEmpty) {
                return Column(children: state.submissions.take(4).map((url) => _buildSubmissionRow(url)).toList());
              }
              return Text(
                'No submissions yet',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontFamily: 'Inter'),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionRow(String url) {
    final displayUrl = url.length > 30 ? '${url.substring(0, 30)}...' : url;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openUrl(url),
              child: Text(
                displayUrl,
                style: const TextStyle(
                  color: Color(0xFFF4F6F9),
                  fontSize: 12,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  decoration: TextDecoration.underline,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitSection() {
    return Column(
      children: [
        const Text(
          'Submit Your Reply',
          style: TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'Fira Code', fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => showRaidSubmissionActionSheet(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: ShapeDecoration(
              color: Colors.white.withValues(alpha: 0.24),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              '|https://x.com/....',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontSize: 12,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
