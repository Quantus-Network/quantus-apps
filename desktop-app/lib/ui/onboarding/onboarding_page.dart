import 'package:flutter/material.dart';
import 'package:quantus_desktop_wallet/services/window_chrome.dart';
import 'package:quantus_desktop_wallet/ui/components/window_header_row.dart';

/// The frame of an onboarding page: [child] in a column of readable width in
/// the middle of the window, under a top row that holds the way back.
class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key, required this.child, this.leading});

  final Widget child;

  /// The control at the start of the top row, when the page has a way back.
  final Widget? leading;

  static const double _contentWidth = 360;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        WindowHeaderRow(leadsTheWindow: true, children: [?leading]),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              // The bottom padding matches the top row, so the content sits in
              // the middle of the window, not of the space under the row.
              padding: const EdgeInsets.fromLTRB(24, 0, 24, shellHeaderHeight),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentWidth),
                child: child,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
