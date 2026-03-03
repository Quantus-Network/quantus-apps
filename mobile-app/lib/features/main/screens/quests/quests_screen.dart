import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/complete_setup_action_sheet.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/quest_card.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/king_of_the_shill_screen.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/referrals_quest_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/providers/account_stats_providers.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showSetupTooltip = true;

  void refreshStatsData() {
    ref.invalidate(accountsStatsProvider);
  }

  void refreshAssociationsData() {
    ref.invalidate(accountAssociationsProvider);
  }

  void _dismissTooltip() {
    setState(() {
      _showSetupTooltip = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final associationsAsync = ref.watch(accountAssociationsProvider);

    final hasEthAddress = associationsAsync.maybeWhen(
      data: (associations) => associations.ethAddress != null,
      orElse: () => false,
    );

    final hasXUsername = associationsAsync.maybeWhen(
      data: (associations) => associations.xUsername != null,
      orElse: () => false,
    );

    final showTooltip = !hasEthAddress && _showSetupTooltip;

    return ScaffoldBase.refreshable(
      onRefresh: () async {
        refreshStatsData();
        refreshAssociationsData();
      },
      scrollController: _scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildHeader(context, hasEthAddress, showTooltip),
              const SizedBox(height: 48),
              _buildQuestCards(context, hasEthAddress, hasXUsername),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, bool hasEthAddress, bool showTooltip) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Image.asset('assets/quests/quests_top_logo.png', height: 24, fit: BoxFit.contain),
            GestureDetector(
              onTap: () => showCompleteSetupActionSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: ShapeDecoration(
                  color: context.themeColors.settingCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: Text(hasEthAddress ? 'Setup' : 'Complete Setup', style: context.themeText.smallParagraph),
              ),
            ),
          ],
        ),
        if (showTooltip) ...[const SizedBox(height: 8), _buildSetupTooltip()],
      ],
    );
  }

  Widget _buildSetupTooltip() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: ShapeDecoration(
        color: context.themeColors.background2,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0x66F4F6F9)),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 149,
            child: Text(
              'Complete setup to unlock quests.',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _dismissTooltip,
            child: const Icon(Icons.close, color: Colors.white, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestCards(BuildContext context, bool hasEthAddress, bool hasXUsername) {
    return Column(
      children: [
        QuestCard.referFriends(
          isDisabled: !hasEthAddress,
          onDisabledTap: () => showCompleteSetupActionSheet(context),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReferralsQuestScreen()));
          },
        ),
        const SizedBox(height: 40),
        QuestCard.kingOfTheShill(
          isDisabled: !hasXUsername,
          onDisabledTap: () => showCompleteSetupActionSheet(context),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const KingOfTheShillScreen()));
          },
        ),
      ],
    );
  }
}
