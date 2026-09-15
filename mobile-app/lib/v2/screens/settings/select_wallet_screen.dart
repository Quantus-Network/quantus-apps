import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart' hide ScaffoldBase;
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/providers/account_providers.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/shared/utils/account_utils.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

/// The wallet's custom name, or the numbered fallback wallet lists show.
String walletDisplayName(WidgetRef ref, AppLocalizations l10n, int walletIndex) =>
    ref.watch(walletNameProvider(walletIndex)) ?? l10n.settingsSelectWalletItem(walletIndex + 1);

/// Opens [destination] for a software wallet: straight in when there is only
/// one, through [SelectWalletScreen] when there are several.
void pushForSoftwareWallet(
  BuildContext context,
  WidgetRef ref,
  List<Account> accounts, {
  required Widget Function(int walletIndex) destination,
}) {
  final walletIndices = getNonHardwareWalletIndices(accounts);
  if (walletIndices.isEmpty) {
    context.showErrorToaster(message: ref.read(l10nProvider).settingsWalletNoWalletsFound);
    return;
  }
  final page = walletIndices.length == 1
      ? destination(walletIndices.first)
      : SelectWalletScreen(destination: destination);
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
}

class SelectWalletScreen extends ConsumerWidget {
  final Widget Function(int walletIndex) destination;

  const SelectWalletScreen({super.key, required this.destination});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final accountsAsync = ref.watch(accountsProvider);

    return ScaffoldBase(
      appBar: V2AppBar(title: l10n.settingsSelectWalletTitle),
      mainContent: accountsAsync.when(
        loading: () => const Center(child: Loader()),
        error: (e, _) => Center(
          child: Text(l10n.settingsWalletFailedToLoad, style: text.body.copyWith(color: colors.textMuted)),
        ),
        data: (accounts) {
          final indices = getNonHardwareWalletIndices(accounts);
          if (indices.isEmpty) {
            return Center(
              child: Text(l10n.settingsSelectWalletNoWallets, style: text.body.copyWith(color: colors.textMuted)),
            );
          }
          return ListView.separated(
            itemCount: indices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _walletItem(context, ref, l10n, indices[i], colors, text),
          );
        },
      ),
    );
  }

  Widget _walletItem(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    int walletIndex,
    AppColorsV3 colors,
    AppTextThemeV3 text,
  ) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination(walletIndex))),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: colors.bgSurface, borderRadius: context.radiusV3.mdBorder),
        child: Row(
          children: [
            Expanded(
              child: Text(
                walletDisplayName(ref, l10n, walletIndex),
                style: text.bodyLarge.copyWith(color: colors.textContent),
              ),
            ),
            QuantusIcon(QuantusIcons.chevronRight, color: colors.textMuted),
          ],
        ),
      ),
    );
  }
}
