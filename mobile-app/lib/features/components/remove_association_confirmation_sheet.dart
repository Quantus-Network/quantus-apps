import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/features/components/app_modal_bottom_sheet.dart';
import 'package:resonance_network_wallet/features/components/button.dart';
import 'package:resonance_network_wallet/features/styles/app_colors_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_size_theme.dart';
import 'package:resonance_network_wallet/features/styles/app_text_theme.dart';
import 'package:resonance_network_wallet/shared/extensions/media_query_data_extension.dart';
import 'package:resonance_network_wallet/shared/extensions/toaster_extensions.dart';

class RemoveAssociationConfirmationSheet extends StatefulWidget {
  final Future<void> Function() onRemove;

  const RemoveAssociationConfirmationSheet({super.key, required this.onRemove});

  @override
  State<RemoveAssociationConfirmationSheet> createState() => _RemoveAssociationConfirmationSheetState();
}

class _RemoveAssociationConfirmationSheetState extends State<RemoveAssociationConfirmationSheet> {
  bool isLoading = false;

  void handleAction() async {
    try {
      setState(() {
        isLoading = true;
      });

      await widget.onRemove();

      if (mounted) {
        context.showSuccessToaster(message: 'Your association is successfully removed');
      }

      _closeSheet();
    } catch (e) {
      print('Failed removing association: $e');
      // ignore: use_build_context_synchronously
      if (mounted) {
        context.showErrorToaster(message: 'Failed removing: $e');
      }
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _closeSheet() {
    Navigator.of(context).pop();
  }

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
                    onPressed: () => _closeSheet(),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Confirm Removal', style: context.themeText.mediumTitle),
                const SizedBox(height: 13),
                SizedBox(
                  width: context.isTablet ? null : 309,
                  child: Text('Are you sure you want to proceed?', style: context.themeText.smallParagraph),
                ),
                const SizedBox(height: 28),
                Button(
                  variant: ButtonVariant.danger,
                  label: 'Remove',
                  onPressed: handleAction,
                  textStyle: context.themeText.smallTitle?.copyWith(color: context.themeColors.textSecondary),
                  isLoading: isLoading,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => isLoading ? null : _closeSheet(),
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

void showRemoveAssociationConfirmationSheet(BuildContext context, Future<void> Function() onRemove) {
  showAppModalBottomSheet(
    context: context,
    builder: (context) {
      return RemoveAssociationConfirmationSheet(onRemove: onRemove);
    },
  );
}
