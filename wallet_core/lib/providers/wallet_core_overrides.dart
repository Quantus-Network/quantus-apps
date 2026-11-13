import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/push_registration.dart';
import 'package:wallet_core/services/telemetry.dart';

/// The overrides that bind wallet_core's platform seams to an app's
/// implementations. Every app passes the result to its root `ProviderScope`.
///
/// Each seam is a required argument, so an app that forgets one does not
/// compile.
List<Override> walletCoreOverrides({
  required Telemetry Function(Ref ref) telemetry,
  required PushRegistration Function(Ref ref) pushRegistration,
  required LocalNotifications Function(Ref ref) localNotifications,
}) => [
  telemetryProvider.overrideWith(telemetry),
  pushRegistrationProvider.overrideWith(pushRegistration),
  localNotificationsProvider.overrideWith(localNotifications),
];
