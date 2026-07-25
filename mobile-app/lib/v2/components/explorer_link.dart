import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/shared/utils/open_external_url.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Underlined "View in Explorer ↗" link that opens [url] in an external
/// browser. Shared across the send terminal, POS receipt and the
/// transaction/proposal detail sheets. Renders disabled (non-tappable) when
/// [url] is null or [enabled] is false; [color] defaults to the tertiary text.
class ExplorerLink extends ConsumerWidget {
  final String? url;
  final Color? color;
  final bool enabled;

  const ExplorerLink({super.key, required this.url, this.color, this.enabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final linkColor = color ?? context.colors.textTertiary;
    final active = enabled && url != null;

    return GestureDetector(
      onTap: active ? () => openUrl(url!) : null,
      child: Container(
        padding: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: linkColor, width: 1)),
        ),
        child: Text(
          l10n.activityDetailViewExplorer,
          style: context.themeText.smallParagraph?.copyWith(color: linkColor, fontWeight: FontWeight.w400),
        ),
      ),
    );
  }
}
