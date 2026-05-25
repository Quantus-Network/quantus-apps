import 'package:flutter/material.dart';

extension CurrentRouteExtensions on BuildContext {
  String? get peekTopRouteName {
    String? topRouteName;

    Navigator.popUntil(this, (route) {
      topRouteName = route.settings.name;
      return true;
    });

    return topRouteName;
  }
}
