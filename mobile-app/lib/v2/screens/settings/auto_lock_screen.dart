import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/services/local_auth_service.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class AutoLockScreen extends StatefulWidget {
  const AutoLockScreen({super.key});

  @override
  State<AutoLockScreen> createState() => _AutoLockScreenState();
}

class _AutoLockScreenState extends State<AutoLockScreen> {
  final _authService = LocalAuthService();
  late int _selected;

  static const _options = [
    (value: 0, label: '30 Seconds'),
    (value: 1, label: '1 minute'),
    (value: 5, label: '5 minutes'),
    (value: 15, label: '15 minutes'),
    (value: 60, label: '1 hour'),
    (value: -1, label: 'Never'),
  ];

  @override
  void initState() {
    super.initState();
    _selected = _authService.getAuthTimeoutMinutes();
  }

  void _confirm() {
    _authService.setAuthTimeoutMinutes(_selected);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Scaffold(
      backgroundColor: colors.background,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppBackButton(),
                    Text('Auto-Lock', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
                    const SizedBox(width: 24),
                  ],
                ),
                const SizedBox(height: 80),
                Text(
                  'Automatically lock wallet after\nperiod of inactivity',
                  style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500, height: 1.35),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: colors.surfaceGlass, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    children: [
                      for (var i = 0; i < _options.length; i++) ...[
                        if (i > 0) Divider(color: colors.separator, height: 1),
                        _optionRow(_options[i].value, _options[i].label, colors, text),
                      ],
                    ],
                  ),
                ),
                const Spacer(),
                GlassContainer(
                  asset: GlassContainer.wideAsset,
                  onTap: _confirm,
                  child: Center(
                    child: Text(
                      'Confirm',
                      style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionRow(int value, String label, AppColorsV2 colors, AppTextTheme text) {
    final selected = _selected == value;
    return GestureDetector(
      onTap: () => setState(() => _selected = value),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: selected ? colors.textPrimary : colors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(label, style: text.paragraph?.copyWith(color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
