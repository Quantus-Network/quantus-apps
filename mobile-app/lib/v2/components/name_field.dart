import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';

class NameField extends ConsumerWidget {
  final TextEditingController controller;
  final String? subtitle;
  final String? error;
  final String? hint;

  const NameField({super.key, required this.controller, this.subtitle, this.error, this.hint});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ref.watch(l10nProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        QuantusTextField(
          controller: controller,
          hint: hint ?? l10n.componentNameFieldHint,
          error: error,
          showClearButton: true,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted)),
        ],
      ],
    );
  }
}
