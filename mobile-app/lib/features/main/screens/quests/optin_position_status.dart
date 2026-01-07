import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/skeleton.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/providers/opt_in_position_providers.dart';

class OptinPositionStatus extends ConsumerWidget {
  const OptinPositionStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final positionAsync = ref.watch(optInPositionProvider);

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
}
