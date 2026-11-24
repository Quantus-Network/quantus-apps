import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  /// macOS counts hiding the only window as closing it, so a window hidden
  /// with work under way must not quit the app.
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return (mainFlutterWindow as? MainFlutterWindow)?.isHiddenForWork != true
  }

  /// A logout, restart or shutdown goes through at once. Flutter otherwise
  /// cancels every request to quit while it asks the app, and a cancelled one
  /// stops the whole logout or shutdown.
  override func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    if isSessionEnding { return .terminateNow }
    return super.applicationShouldTerminate(sender)
  }

  /// Whether the system is quitting the app because the session is ending.
  private var isSessionEnding: Bool {
    guard
      let reason = NSAppleEventManager.shared().currentAppleEvent?
        .attributeDescriptor(forKeyword: AEKeyword(kAEQuitReason))?.typeCodeValue
    else { return false }
    return [OSType(kAEReallyLogOut), OSType(kAERestart), OSType(kAEShutDown)].contains(reason)
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
