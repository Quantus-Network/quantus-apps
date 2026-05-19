import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class NameField extends ConsumerWidget {
  final TextEditingController controller;
  final String? subtitle;
  final String? error;

  const NameField({super.key, required this.controller, this.subtitle, this.error});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);
    final textStyle = context.themeText.smallTitle!.copyWith(fontWeight: FontWeight.w400);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: context.colors.surfaceDeep, borderRadius: BorderRadius.circular(14)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: textStyle,
                  decoration: InputDecoration.collapsed(
                    hintText: l10n.componentNameFieldHint,
                    hintStyle: textStyle.copyWith(color: context.colors.textSecondary),
                  ),
                ),
              ),
              if (controller.text.isNotEmpty) ...[
                const SizedBox(width: 8),
                _EditAccountClearButton(onTap: () => controller.clear()),
              ],
            ],
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 16),
          Text(subtitle!, style: context.themeText.smallParagraph?.copyWith(color: context.colors.textSecondary)),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          Text(
            error!,
            style: context.themeText.detail?.copyWith(color: context.colors.textError),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

class _EditAccountClearButton extends StatelessWidget {
  final VoidCallback onTap;

  const _EditAccountClearButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final size = 20.0;
    final borderRadius = 16.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.colors.textMuted,
            border: Border.all(color: context.colors.borderButton, width: 0.5),
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          child: Icon(Icons.close, size: 12, color: context.colors.background),
        ),
      ),
    );
  }
}
