import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/constants/e2e_keys.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';

class MiningRewardsSubmittedScreen extends ConsumerWidget {
  const MiningRewardsSubmittedScreen({super.key});

  void _done(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done(context);
      },
      child: ScaffoldBase(
        key: const Key(E2EKeys.miningRewardsSubmittedScreen),
        appBar: V2AppBar(
          title: l10n.miningRewardsSubmittedTitle,
          leading: AppBackButton(onTap: () => _done(context)),
        ),
        mainContent: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SuccessCheck(),
              const SizedBox(height: 32),
              Text(
                l10n.miningRewardsSubmittedBody,
                textAlign: TextAlign.center,
                style: text.bodyLarge.copyWith(color: colors.textContent),
              ),
            ],
          ),
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: QuantusButton.simple(
            key: const Key(E2EKeys.miningRewardsSubmittedDoneButton),
            label: l10n.commonDone,
            onTap: () => _done(context),
          ),
        ),
      ),
    );
  }
}
