import 'package:flutter/foundation.dart';

/// True when the app is running on a desktop platform (Linux, macOS, Windows).
bool get isDesktopPlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows);
