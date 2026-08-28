import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class MenuRow extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;

  const MenuRow({super.key, required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(label, style: text.amountRow.copyWith(color: colors.textContent)),
              ),
              Row(
                children: [
                  if (value != null) ...[
                    Text(value!, style: text.body.copyWith(color: colors.textMuted)),
                    const SizedBox(width: 4),
                  ],
                  QuantusIcon(QuantusIcons.chevronRight, color: colors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
