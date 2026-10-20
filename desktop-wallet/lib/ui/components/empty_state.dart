import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final List<Widget> actions;

  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(icon, size: 40, color: colors.textMuted2),
          const SizedBox(height: 16),
          Text(
            title,
            style: text.titleScreen.copyWith(color: colors.textContent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              body,
              style: text.body.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center,
            ),
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 24),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: actions),
          ],
        ],
      ),
    );
  }
}
