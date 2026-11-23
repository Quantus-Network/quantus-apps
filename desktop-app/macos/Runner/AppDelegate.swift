import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  /// A click on the Dock icon brings back a window that was closed with the
  /// app still running.
  override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    if !flag {
      (mainFlutterWindow as? MainFlutterWindow)?.bringToFront()
    }
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  /// A secret the app copied leaves with the app, unless something else has
  /// been copied over it since.
  override func applicationWillTerminate(_ notification: Notification) {
    SensitiveClipboard.shared.clearIfUnchanged()
    super.applicationWillTerminate(notification)
  }
}
