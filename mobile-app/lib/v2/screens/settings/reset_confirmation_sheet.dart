import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/bottom_sheet_container.dart';
import 'package:resonance_network_wallet/v2/components/button.dart';
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
  bool _isResetting = false;

  @override
  Widget build(BuildContext context) {
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
          Button(
            label: 'Confirm',
            onTap: () {
              setState(() => _isResetting = true);
              widget.onReset();
            },
            isDisabled: !_isCheckboxChecked,
            variant: ButtonVariant.secondary,
            isLoading: _isResetting,
          ),
          const SizedBox(height: 16),
          Button(
            padding: const EdgeInsets.all(0),
            label: 'Cancel',
            onTap: () => Navigator.pop(context),
            variant: ButtonVariant.transparent,
            textStyle: context.themeText.paragraph?.copyWith(color: context.colors.textPrimary.useOpacity(0.5)),
          ),
        ],
      ),
    );
  }
}

void showResetConfirmationSheetV2(BuildContext context, VoidCallback onReset) {
  BottomSheetContainer.show(context, builder: (_) => ResetConfirmationSheet(onReset: onReset));
}
