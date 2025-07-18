import 'package:flutter/material.dart';

class ResetConfirmationBottomSheet extends StatefulWidget {
  final VoidCallback onReset;

  const ResetConfirmationBottomSheet({super.key, required this.onReset});

  @override
  State<ResetConfirmationBottomSheet> createState() =>
      _ResetConfirmationBottomSheetState();
}

class _ResetConfirmationBottomSheetState
    extends State<ResetConfirmationBottomSheet> {
  bool _isCheckboxChecked = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 16),
        decoration: ShapeDecoration(
          color: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Confirm Reset',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontFamily: 'Fira Code',
                fontWeight: FontWeight.w300,
              ),
            ),
            const SizedBox(height: 13),
            const SizedBox(
              width: 309,
              child: Text(
                'Are you sure you want to proceed? This will delete all local wallet data. Make sure you have backed up your recovery phrase.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: _isCheckboxChecked,
                  onChanged: (bool? value) {
                    setState(() {
                      _isCheckboxChecked = value ?? false;
                    });
                  },
                  activeColor: const Color(0xFF8AF9A8),
                  checkColor: Colors.black,
                  side: const BorderSide(color: Colors.white),
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'I have backed up my recovery phrase',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontFamily: 'Fira Code',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _isCheckboxChecked
                  ? widget.onReset
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF2D53),
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
                disabledBackgroundColor:
                    const Color(0xFFFF2D53).withOpacity(0.5),
              ),
              child: const Text(
                'Reset & Clear Data',
                style: TextStyle(
                  color: Color(0xFF0E0E0E),
                  fontSize: 18,
                  fontFamily: 'Fira Code',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'Fira Code',
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 