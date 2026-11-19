import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/shell_providers.dart';

/// How wide the panel at the right that shows one transaction or proposal
/// is, in points: what the person dragged it to, kept for the next start.
final inspectorWidthProvider = NotifierProvider<InspectorWidthNotifier, double>(InspectorWidthNotifier.new);

class InspectorWidthNotifier extends SavedWidthNotifier {
  static const double initial = 380;
  static const double minimum = 360;
  static const double maximum = 480;

  /// Where the width is kept between runs.
  static const settingsKey = 'desktop_inspector_width';

  @override
  double get startWidth => initial;

  @override
  double get minWidth => minimum;

  @override
  double get maxWidth => maximum;

  @override
  String get key => settingsKey;

  @override
  String get panelName => 'transaction panel';
}
