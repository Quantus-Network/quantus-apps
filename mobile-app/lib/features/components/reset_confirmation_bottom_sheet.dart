import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';

class ResetConfirmationBottomSheet extends StatefulWidget {
  final VoidCallback onReset;

  const ResetConfirmationBottomSheet({super.key, required this.onReset});

  @override
  State<ResetConfirmationBottomSheet> createState() => _ResetConfirmationBottomSheetState();
}

class _ResetConfirmationBottomSheetState extends State<ResetConfirmationBottomSheet> {
  bool _isCheckboxChecked = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
          decoration: ShapeDecoration(
            color: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(Icons.close, size: context.themeSize.overlayCloseIconSize),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Confirm Reset', style: context.themeText.mediumTitle),
                const SizedBox(height: 13),
                SizedBox(
                  width: context.isTablet ? null : 309,
                  child: Text(
                    'Are you sure you want to proceed? This will delete all'
                    ' local '
                    'wallet data. Make sure you have backed up your recovery '
                    'phrase.',
                    style: context.themeText.smallParagraph,
                  ),
                ),
                const SizedBox(height: 28),
                CheckboxListTile(
                  contentPadding: const EdgeInsets.all(0),
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _isCheckboxChecked,
                  onChanged: (bool? value) {
                    setState(() {
                      _isCheckboxChecked = value ?? false;
                    });
                  },
                  activeColor: context.themeColors.buttonSuccess,
                  checkColor: context.themeColors.buttonSuccess,
                  side: const BorderSide(color: Colors.white),
                  title: Text('I have backed up my recovery phrase', style: context.themeText.detail),
                ),
                const SizedBox(height: 28),
                Button(
                  variant: ButtonVariant.danger,
                  label: 'Reset & Clear Data',
                  onPressed: _isCheckboxChecked ? widget.onReset : null,
                  textStyle: context.themeText.smallTitle?.copyWith(color: context.themeColors.textSecondary),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: context.themeText.smallParagraph?.copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
