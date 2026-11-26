import Cocoa
import FlutterMacOS
import Security
import UserNotifications

/// Pushed notifications, which macOS shows while the app is closed: what
/// Apple's push service knows this Mac by, and the clicks on what was pushed.
/// Asked by `ChannelMacPush` in `lib/services/mac_push.dart`.
///
/// The app's own notifications belong to the notifications plugin. It makes
/// itself the notification center's delegate, and asked about a notification
/// it did not show it never answers. So this takes the delegate's place,
/// answers for what was pushed and hands the plugin everything else.
final class PushNotifications: NSObject, UNUserNotificationCenterDelegate {
  static let shared = PushNotifications()

  /// What a build signed to receive pushes carries: `development` or
  /// `production`, the one of Apple's two push services its token is good at.
  private static let environmentEntitlement = "com.apple.developer.aps-environment"

  /// What a pushed notification carries for its click, as the app's own
  /// notifications do in their payload.
  private static let clickKeys = ["extrinsicHash", "proposalId"]

  private var channel: FlutterMethodChannel?

  /// The notifications plugin, the delegate until this took its place.
  private var plugin: UNUserNotificationCenterDelegate?

  /// Each waits for macOS to answer with this Mac's token.
  private var tokenRequests: [FlutterResult] = []

  /// Whether the app has asked for clicks. A click that launched the app
  /// comes before that, and is kept for when it asks.
  private var isAppListening = false
  private var clickBeforeListening: String?

  /// Takes the delegate's place. Called once the plugins are registered, and
  /// before the app has finished launching: macOS hands the click that
  /// launched the app to whoever is the delegate by then.
  func install(with messenger: FlutterBinaryMessenger) {
    let center = UNUserNotificationCenter.current()
    plugin = center.delegate
    if plugin == nil {
      NSLog("PushNotifications: no notifications plugin to hand the app's own notifications to")
    }
    center.delegate = self

    let channel = FlutterMethodChannel(name: "com.quantus.desktop-wallet/push", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "environment":
        result(self.environment)
      case "token":
        self.tokenRequests.append(result)
        NSApplication.shared.registerForRemoteNotifications()
      case "takeLaunchClick":
        self.isAppListening = true
        result(self.clickBeforeListening)
        self.clickBeforeListening = nil
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  /// Which push service the build was signed for; nil when for neither, as
  /// a build without a provisioning profile is.
  private var environment: String? {
    guard let task = SecTaskCreateFromSelf(nil) else { return nil }
    return SecTaskCopyValueForEntitlement(task, PushNotifications.environmentEntitlement as CFString, nil) as? String
  }

  /// macOS answered with this Mac's token.
  func didRegister(deviceToken: Data) {
    answerTokenRequests(deviceToken.map { String(format: "%02x", $0) }.joined())
  }

  /// macOS could not get this Mac a token.
  func didFailToRegister(error: Error) {
    answerTokenRequests(FlutterError(code: "token-failed", message: error.localizedDescription, details: nil))
  }

  private func answerTokenRequests(_ answer: Any) {
    onMain {
      let waiting = self.tokenRequests
      self.tokenRequests = []
      for result in waiting {
        result(answer)
      }
    }
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// Asked only while the app is in front. What is pushed is not shown
  /// then: the running app notifies the same event itself, with the
  /// account's name.
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if PushNotifications.isPushed(notification) {
      completionHandler([])
      return
    }
    let handed: Void? = plugin?.userNotificationCenter?(
      center, willPresent: notification, withCompletionHandler: completionHandler)
    if handed == nil { completionHandler([]) }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    guard PushNotifications.isPushed(response.notification) else {
      let handed: Void? = plugin?.userNotificationCenter?(
        center, didReceive: response, withCompletionHandler: completionHandler)
      if handed == nil { completionHandler() }
      return
    }
    if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
      if let payload = PushNotifications.clickPayload(of: response.notification.request.content.userInfo) {
        onMain { self.deliverClick(payload) }
      } else {
        NSLog("PushNotifications: a clicked pushed notification named no account")
      }
    }
    completionHandler()
  }

  private func deliverClick(_ payload: String) {
    if isAppListening {
      channel?.invokeMethod("click", arguments: payload)
    } else {
      clickBeforeListening = payload
    }
  }

  private static func isPushed(_ notification: UNNotification) -> Bool {
    return notification.request.trigger is UNPushNotificationTrigger
  }

  /// What the app needs to open what a pushed notification was about, as
  /// JSON: the account, and its transaction or proposal when the push named
  /// one. Nil when the push named no account.
  private static func clickPayload(of userInfo: [AnyHashable: Any]) -> String? {
    guard let accountId = userInfo["accountId"] as? String else { return nil }
    var payload = ["accountId": accountId]
    for key in clickKeys {
      if let value = userInfo[key] as? String { payload[key] = value }
    }
    guard let json = try? JSONSerialization.data(withJSONObject: payload) else { return nil }
    return String(data: json, encoding: .utf8)
  }

  /// The app is only ever spoken to on the main thread.
  private func onMain(_ work: @escaping () -> Void) {
    if Thread.isMainThread {
      work()
    } else {
      DispatchQueue.main.async(execute: work)
    }
  }
}
