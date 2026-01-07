import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:resonance_network_wallet/features/components/basic_card.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/features/main/screens/quests/account_associations_screen.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/account_associations_providers.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class AccountAssociationsStatus extends ConsumerWidget {
  const AccountAssociationsStatus({super.key});

  final titleEth = 'ETH Address';
  final titleX = 'X Account';

  void refreshAssociationsData(WidgetRef ref) {
    ref.invalidate(accountAssociationsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final associationsAsync = ref.watch(accountAssociationsProvider);

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
          Button(
            variant: ButtonVariant.neutral,
            label: 'Try again',
            onPressed: () {
              refreshAssociationsData(ref);
            },
          ),
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
}
