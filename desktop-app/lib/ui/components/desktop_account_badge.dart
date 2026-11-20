import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/wallet_providers.dart';

/// The badge that stands for [account]: the lock for the encrypted account,
/// which is always told apart, and the account's initials for any other.
///
/// What is inside grows with the badge: the lock is half of it, and the
/// initials are 10pt beside a line of text (24) and 12pt in the sidebar (32),
/// never under the 10pt the desktop allows.
///
/// A [count] of things that need a look sits on its top right corner, in
/// glacier, cut out of what is behind it; a screen reader hears what it
/// counts from the row that names the account.
class DesktopAccountBadge extends StatelessWidget {
  const DesktopAccountBadge({super.key, required this.account, required this.size, this.count = 0});

  final BaseAccount account;
  final double size;

  /// How many things of the account need a look; none shows nothing.
  final int count;

  static const countKey = Key('account-badge-count');

  @override
  Widget build(BuildContext context) {
    final badge = isEncryptedAccount(account)
        ? EncryptedLockBadge(size: size, iconSize: size / 2)
        : AccountBadge(
            name: account.name,
            size: size,
            textStyle: context.themeTextV3.labelMonogram.copyWith(fontSize: math.max(10, size * 0.375)),
          );
    if (count == 0) return badge;

    final colors = context.colorsV3;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        badge,
        Positioned(
          right: -5,
          top: -4,
          child: ExcludeSemantics(
            child: Container(
              key: countKey,
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.semanticGlacier,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colors.bgSurface, width: 2),
              ),
              child: Text(
                '$count',
                style: context.themeTextV3.labelChip.copyWith(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: colors.bgVoid,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
