import 'package:flutter/material.dart';
import 'package:resonance_network_wallet/services/telemetry_service.dart';

/// Global navigator observer that reports screen transitions to TelemetryDeck.
class TelemetryNavigatorObserver extends RouteObserver<PageRoute<dynamic>> {
  final TelemetryService _telemetry = TelemetryService();

  String? _routeNameOf(Route<dynamic>? route) {
    if (route == null) return null;
    final settings = route.settings;
    return settings.name ?? settings.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      final to = _routeNameOf(route);
      if (to != null) {
        _telemetry.trackScreenView(to);
      }
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute is PageRoute) {
      final to = _routeNameOf(newRoute);
      if (to != null) {
        _telemetry.trackScreenView(to);
      }
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute is PageRoute) {
      final to = _routeNameOf(previousRoute);
      if (to != null) {
        _telemetry.trackScreenView(to);
      }
    }
  }
}
