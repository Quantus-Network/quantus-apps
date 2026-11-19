import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/generated/version.g.dart';
import 'package:quantus_desktop_wallet/providers/chain_status_providers.dart';
import 'package:quantus_desktop_wallet/providers/sync_status_provider.dart';
import 'package:quantus_desktop_wallet/ui/components/terminal_line.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/connectivity_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The line along the window's foot: the network, how current the wallet
/// is, the chain's latest block, and at the right the app's version.
///
/// Offline, it says so, keeps how long ago the wallet last synced, and
/// leaves the block out: there is no network to read it from.
class ShellFooter extends ConsumerStatefulWidget {
  const ShellFooter({super.key});

  /// Its height, with the space above it that parts it from the panels.
  static const double height = 34;

  /// The space between its ends and what it holds.
  static const double edgePadding = 18;

  /// How often "how long ago" is worked out again.
  static const tick = Duration(seconds: 30);

  /// The space above the items, inside [height].
  static const double _spaceAbove = 4;

  /// The space between one item and the next.
  static const double _itemGap = 22;

  @override
  ConsumerState<ShellFooter> createState() => _ShellFooterState();
}

class _ShellFooterState extends ConsumerState<ShellFooter> {
  /// Works "how long ago" out again as time passes.
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(ShellFooter.tick, (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final isOnline = ref.watch(isOnlineProvider);
    final isTestnet = ref.watch(isTestnetProvider);
    final sync = ref.watch(syncStatusProvider);
    final block = ref.watch(latestBlockProvider);
    final now = ref.watch(currentTimeProvider)();
    final lastSyncedAt = sync.lastSyncedAt;

    final items = <Widget>[
      _Item(
        mark: _Dot(
          color: !isOnline
              ? colors.semanticEmber
              : isTestnet
              ? colors.semanticSand
              : colors.semanticSage,
        ),
        label: !isOnline
            ? l10n.desktopFooterOffline
            : isTestnet
            ? l10n.desktopFooterTestnet
            : l10n.desktopFooterMainnet,
        color: isOnline ? null : colors.semanticEmber,
      ),
      if (isOnline && sync.isSyncing)
        _Item(
          mark: MediaQuery.disableAnimationsOf(context) ? null : TerminalSpinner(style: _spinnerStyle(context)),
          label: l10n.desktopFooterSyncing,
          color: colors.semanticGlacier,
        )
      else if (isOnline && sync.hasFailed)
        _Item(
          mark: _Symbol(CupertinoIcons.exclamationmark_circle, color: colors.semanticEmber),
          label: l10n.desktopFooterSyncFailed,
          color: colors.semanticEmber,
        )
      else if (lastSyncedAt != null)
        _Item(
          mark: _Symbol(isOnline ? CupertinoIcons.checkmark_alt : CupertinoIcons.clock),
          label: syncedAgoLabel(l10n, now.difference(lastSyncedAt)),
        ),
      if (isOnline && block != null)
        _Item(
          mark: const _Symbol(CupertinoIcons.cube),
          label: l10n.desktopFooterBlock(ref.watch(numberFormattingServiceProvider).formatInteger(block)),
        ),
    ];

    return SizedBox(
      height: ShellFooter.height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ShellFooter.edgePadding,
          ShellFooter._spaceAbove,
          ShellFooter.edgePadding,
          0,
        ),
        child: Row(
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(right: ShellFooter._itemGap),
                child: item,
              ),
            const Spacer(),
            Text(
              l10n.desktopFooterVersion(appVersion),
              style: context.themeTextV3.body.copyWith(color: colors.textMuted2),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _spinnerStyle(BuildContext context) =>
      context.themeTextV3.dataAddressLarge.copyWith(height: 1, color: context.colorsV3.semanticGlacier);
}

/// How long ago the wallet last synced, [ago], in the footer's words.
String syncedAgoLabel(AppLocalizations l10n, Duration ago) {
  if (ago.inMinutes < 1) return l10n.desktopFooterSyncedJustNow;
  if (ago.inHours < 1) return l10n.desktopFooterSyncedMinutesAgo(ago.inMinutes);
  if (ago.inDays < 1) return l10n.desktopFooterSyncedHoursAgo(ago.inHours);
  return l10n.desktopFooterSyncedDaysAgo(ago.inDays);
}

/// A mark, then a few words.
class _Item extends StatelessWidget {
  const _Item({required this.mark, required this.label, this.color});

  final Widget? mark;
  final String label;

  /// The words' colour; muted unless given.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (mark case final mark?) ...[mark, const SizedBox(width: 7)],
        Text(label, style: context.themeTextV3.body.copyWith(color: color ?? context.colorsV3.textMuted)),
      ],
    );
  }
}

class _Symbol extends StatelessWidget {
  const _Symbol(this.icon, {this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(icon, size: 13, color: color ?? context.colorsV3.textMuted);
}

/// The network's mark: a small round dot.
class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}
