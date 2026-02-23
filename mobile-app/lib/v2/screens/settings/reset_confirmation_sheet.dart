import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class ResetConfirmationSheet extends StatefulWidget {
  final VoidCallback onReset;
  const ResetConfirmationSheet({super.key, required this.onReset});

  @override
  State<ResetConfirmationSheet> createState() => _ResetConfirmationSheetState();
}

class _ResetConfirmationSheetState extends State<ResetConfirmationSheet> {
  bool _isCheckboxChecked = false;

  @override
  Widget build(BuildContext context) {
    final buttonTextStyle = context.themeText.paragraph?.copyWith(fontWeight: FontWeight.w500);

    return BottomSheetContainer(
      title: 'Confirm Reset',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 32),
          Text(
            'Are you sure you want to proceed? This will delete all local wallet data. Make sure you have backed up your recovery phrase.',
            style: context.themeText.smallParagraph,
          ),
          const SizedBox(height: 64),
          CheckboxListTile(
            contentPadding: const EdgeInsets.all(0),
            controlAffinity: ListTileControlAffinity.leading,
            value: _isCheckboxChecked,
            onChanged: (bool? value) {
              setState(() {
                _isCheckboxChecked = value ?? false;
              });
            },
            activeColor: context.colors.success,
            checkColor: context.colors.success,
            side: const BorderSide(color: Colors.white),
            title: Text('I have backed up my recovery phrase', style: context.themeText.smallParagraph),
          ),
          const SizedBox(height: 64),
          GlassContainer(
            asset: GlassContainer.wideAsset,
            onTap: _isCheckboxChecked ? widget.onReset : null,
            child: Center(child: Text('Confirm', style: buttonTextStyle)),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => Navigator.pop(context),
            child: Center(
              child: Text(
                'Cancel',
                style: buttonTextStyle?.copyWith(color: context.colors.textPrimary.useOpacity(0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void showResetConfirmationSheetV2(BuildContext context, VoidCallback onReset) {
  BottomSheetContainer.show(context, builder: (_) => ResetConfirmationSheet(onReset: onReset));
}
