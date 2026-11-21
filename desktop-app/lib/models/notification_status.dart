/// What the system lets the app do with notifications.
sealed class NotificationStatus {
  const NotificationStatus();
}

/// The system's notifications have not been started yet.
final class NotificationsStarting extends NotificationStatus {
  const NotificationsStarting();
}

/// macOS: started, but the person has not been asked yet whether the app may
/// show notifications.
final class NotificationsNotAsked extends NotificationStatus {
  const NotificationsNotAsked();
}

/// The app may show notifications.
final class NotificationsAllowed extends NotificationStatus {
  const NotificationsAllowed();
}

/// macOS: the person said no, when asked or later in System Settings.
final class NotificationsDenied extends NotificationStatus {
  const NotificationsDenied();
}

/// The system's notifications could not be used; [reason] says why.
final class NotificationsUnavailable extends NotificationStatus {
  const NotificationsUnavailable(this.reason);

  final String reason;
}
