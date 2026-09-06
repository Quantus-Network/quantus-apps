import 'package:flutter/material.dart';

/// Scrollable modal-sheet body kept clear of the keyboard and the system navigation bar.
class SheetBody extends StatelessWidget {
  final Widget child;

  const SheetBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 40), child: child),
      ),
    );
  }
}
