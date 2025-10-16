import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/features/components/scaffold_base.dart';
import 'package:resonance_network_wallet/features/components/sphere.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  @override
  Widget build(BuildContext context) {
    return ScaffoldBase(
      decorations: [
        Positioned(
          left: context.getHorizontalCenterPosition(252),
          bottom: -30,
          child: const Sphere(variant: 6, size: 252),
        ),
      ],
      screenTitle: ScreenTitle(title: 'Quests'),
      child: const Center(
        child: Text(
          'Quests coming soon!',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    );
  }
}
