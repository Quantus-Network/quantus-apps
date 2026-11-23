import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

/// Offers [text] to the system share picker, which macOS opens beside
/// [origin], the global rect of the control that asked.
typedef ShareText = Future<void> Function(String text, {Rect? origin});

final shareTextProvider = Provider<ShareText>(
  (ref) =>
      (text, {origin}) async => SharePlus.instance.share(ShareParams(text: text, sharePositionOrigin: origin)),
);
