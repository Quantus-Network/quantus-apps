import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/utils/hidden_amount.dart';

/// What stands for an amount while balances are hidden, in [style]; a screen
/// reader hears it as hidden.
class HiddenAmountText extends ConsumerWidget {
  const HiddenAmountText({super.key, required this.style, this.prefix = ''});

  final TextStyle style;

  /// Drawn before the mask, as "≈ " before an amount in dollars.
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      label: ref.watch(l10nProvider).desktopAmountHidden,
      excludeSemantics: true,
      child: Text('$prefix$hiddenAmountText', style: style, maxLines: 1),
    );
  }
}
