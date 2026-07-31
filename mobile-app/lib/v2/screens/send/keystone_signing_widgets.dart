import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

/// Orange mono "STEP n/3" label shared by the Keystone signing screens.
class KeystoneStepLabel extends ConsumerWidget {
  final int current;
  final int total;

  const KeystoneStepLabel({super.key, required this.current, required this.total});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    return Text(
      l10n.keystoneSignStep(current, total),
      style: context.themeText.detail?.copyWith(
        fontFamily: AppTextTheme.fontFamilySecondary,
        color: context.colors.accentOrange,
        letterSpacing: 0.96,
      ),
    );
  }
}

/// Red gradient warning card shared by the Keystone verify and reject screens.
class KeystoneWarningCard extends StatelessWidget {
  final String text;
  final String? title;

  const KeystoneWarningCard({super.key, required this.text, this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.themeText;
    final warningIcon = SvgPicture.asset('assets/v2/keystone_warning.svg', width: 16, height: 16);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: colors.textError.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.textError.withValues(alpha: 0.1), const Color(0xFF5A1B14).withValues(alpha: 0.1)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                warningIcon,
                const SizedBox(width: 8),
                Text(title!, style: textTheme.paragraph?.copyWith(color: colors.textError)),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: textTheme.detail?.copyWith(color: colors.textMuted)),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFFF5B5B).withValues(alpha: 0.1)),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: warningIcon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: textTheme.detail?.copyWith(color: colors.textError)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
