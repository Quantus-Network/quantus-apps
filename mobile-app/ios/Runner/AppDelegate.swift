import Flutter
import UIKit
import flutter_local_notifications
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
        GeneratedPluginRegistrant.register(with: registry)
    }

    // Set the notification center delegate for flutter_local_notifications
    // foreground presentation. Must happen before Firebase configures.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // Register for remote notifications (required when swizzling is disabled).
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Bridges `SecureClipboardService.copyWithExpiry` to `UIPasteboard`'s
  /// `expirationDate`, which the OS enforces even while the app is suspended
  /// or terminated — so sensitive values (e.g. recovery phrases) never outlive
  /// their TTL on the system pasteboard.
  private func setupSecureClipboardChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "app.quantus/secure_clipboard",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { call, result in
      guard call.method == "copyWithExpiry" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let text = args["text"] as? String,
        let ttlSeconds = args["ttlSeconds"] as? Int
      else {
        result(
          FlutterError(
            code: "bad_args",
            message: "Expected 'text' (String) and 'ttlSeconds' (Int)",
            details: nil
          )
        )
        return
      }

      let expiration = Date().addingTimeInterval(TimeInterval(ttlSeconds))
      // "public.utf8-plain-text" is the UTI for plain text on the pasteboard.
      let items: [[String: Any]] = [["public.utf8-plain-text": text]]
      UIPasteboard.general.setItems(
        items,
        options: [.expirationDate: expiration]
      )
      result(true)
    }
  }

  // With FirebaseAppDelegateProxyEnabled = NO, we must manually forward
  // the APNs device token to Firebase Messaging.
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecureClipboard") {
      setupSecureClipboardChannel(messenger: registrar.messenger())
    }
  }
}
