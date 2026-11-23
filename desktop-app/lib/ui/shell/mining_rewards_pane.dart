import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// Where claiming mining rewards will live: a panel of its own, empty until
/// the feature arrives.
class MiningRewardsPane extends ConsumerWidget {
  const MiningRewardsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      Panel(title: ref.watch(l10nProvider).settingsMiningRewards, child: const SizedBox.expand());
}
