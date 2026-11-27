import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';
import 'package:quantus_desktop_wallet/ui/components/panel.dart';

/// How wide the panels side by side are shown, from the widths they were
/// made and the window's room. The account's lists keep at least
/// [listsLeast]: where there is not room, the sidebar gives way first, down
/// to its least, then the panel at the right, down to its least. What was
/// made is kept; a wider window gives it back. In the smallest window (960)
/// the three least widths (200, 308 and 360) fit with room to spare.

/// The least the account's lists keep: what they are at the smallest window
/// with the widths the panels start at, where every row's form fits.
const double listsLeast = 308;

/// The sidebar's width as shown in a window [windowWidth] wide, made [made]
/// wide, beside an account whose panel at the right is [inspector] wide when
/// one is open.
double shownSidebarWidth({required double windowWidth, required double made, double? inspector}) {
  // The window's gaps at either side, and the sidebar's handle.
  final room = windowWidth - 3 * Panel.gap;
  final pane = listsLeast + (inspector == null ? 0 : Panel.gap + inspector);
  return math.max(SidebarWidthNotifier.minimum, math.min(made, room - pane));
}

/// The sidebar's width as shown now, as the window and what is open in the
/// account have it.
double shownSidebarWidthOf(BuildContext context, WidgetRef ref) {
  final isInspectorOpen = ref.watch(openedActivityViewProvider) != null;
  return shownSidebarWidth(
    windowWidth: MediaQuery.sizeOf(context).width,
    made: ref.watch(sidebarWidthProvider),
    inspector: isInspectorOpen ? ref.watch(inspectorWidthProvider) : null,
  );
}

/// The panel at the right's width as shown in an account pane [paneWidth]
/// wide, made [made] wide.
double shownInspectorWidth({required double paneWidth, required double made}) =>
    math.max(InspectorWidthNotifier.minimum, math.min(made, paneWidth - Panel.gap - listsLeast));
