import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// The smallest content size at which the sidebar and the account panes fit.
  private static let minimumContentSize = NSSize(width: 960, height: 640)
  private static let initialContentSize = NSSize(width: 1200, height: 800)

  /// Height of the header row the app draws where the title bar was. Keep in
  /// step with `shellHeaderHeight` in `lib/services/window_chrome.dart`.
  private static let headerHeight: CGFloat = 52

  /// Where the close button starts and how far apart the three buttons are.
  /// Keep in step with `trafficLightsInset` in `lib/services/window_chrome.dart`.
  private static let trafficLightsLeading: CGFloat = 20
  private static let trafficLightsSpacing: CGFloat = 20

  /// How far in from the window's top, left and right edges a press still
  /// belongs to the system, which resizes the window from there.
  private static let resizeMargin: CGFloat = 6

  private var windowChannel: FlutterMethodChannel?
  private var flutterViewController: FlutterViewController?

  /// Whether a press that began in the header is being handed to Flutter
  /// until its mouse-up.
  private var isHeaderPressInFlutter = false

  /// Whether closing the window leaves the app running. The app says so once
  /// it has started; until then, closing the window quits it.
  private var keepsRunning = false

  /// Whether the window is to leave the screen once it is out of full screen.
  private var hidesAfterFullScreen = false

  private lazy var statusItem = BackgroundStatusItem(onOpen: { [weak self] in self?.bringToFront() })

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.flutterViewController = flutterViewController
    self.contentViewController = flutterViewController

    // The app's content runs to the top edge and its header takes the title
    // bar's place. The title bar itself stays, see-through, so the traffic
    // lights are still the system's own.
    self.styleMask.insert(.fullSizeContentView)
    self.titlebarAppearsTransparent = true
    self.titleVisibility = .hidden

    self.contentMinSize = MainFlutterWindow.minimumContentSize
    self.setContentSize(MainFlutterWindow.initialContentSize)
    self.center()

    let channel = FlutterMethodChannel(
      name: "com.quantus.desktop-wallet/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "startDrag":
        self?.startDrag()
        result(nil)
      case "titleBarDoubleClick":
        self?.performTitleBarDoubleClick()
        result(nil)
      case "bringToFront":
        self?.bringToFront()
        result(nil)
      case "setBackgroundMode":
        guard let arguments = call.arguments as? [String: Any],
          let keepRunning = arguments["keepRunning"] as? Bool,
          let openLabel = arguments["openLabel"] as? String,
          let quitLabel = arguments["quitLabel"] as? String
        else {
          result(
            FlutterError(
              code: "arguments", message: "setBackgroundMode needs keepRunning, openLabel and quitLabel", details: nil))
          return
        }
        self?.keepsRunning = keepRunning
        self?.statusItem.update(isShown: keepRunning, openLabel: openLabel, quitLabel: quitLabel)
        result(nil)
      case "hideWindow":
        self?.hideKeepingAppRunning()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannel = channel

    SensitiveClipboard.shared.register(with: flutterViewController.engine.binaryMessenger)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // The system lays the title bar out again on these events and puts the
    // traffic lights back where a standard title bar has them.
    for name in [
      NSWindow.didResizeNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didDeminiaturizeNotification,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(layoutTrafficLights), name: name, object: self)
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(finishHidingAfterFullScreen), name: NSWindow.didExitFullScreenNotification,
      object: self)

    super.awakeFromNib()

    layoutTrafficLights()
  }

  /// Hands presses in the header straight to Flutter.
  ///
  /// The header lies under the system's title bar, which is see-through but
  /// still there. Left to itself the title bar acts on a press as well: it
  /// starts moving or zooming the window, and the press never ends for the
  /// button under the cursor. The app decides what a press on its header
  /// does, so the title bar is not asked. The traffic lights and the edges
  /// the window is resized from stay with the system.
  override func sendEvent(_ event: NSEvent) {
    switch event.type {
    case .leftMouseDown where isHeaderPressForFlutter(event):
      isHeaderPressInFlutter = true
      flutterViewController?.mouseDown(with: event)
    case .leftMouseDragged where isHeaderPressInFlutter:
      flutterViewController?.mouseDragged(with: event)
    case .leftMouseUp where isHeaderPressInFlutter:
      isHeaderPressInFlutter = false
      flutterViewController?.mouseUp(with: event)
    default:
      super.sendEvent(event)
    }
  }

  private func isHeaderPressForFlutter(_ event: NSEvent) -> Bool {
    // A press on a window that is not in front only brings it to the front,
    // which is the system's to do. In full screen there is no title bar over
    // the header.
    guard self.isKeyWindow, !self.styleMask.contains(.fullScreen), flutterViewController != nil else {
      return false
    }

    let location = event.locationInWindow
    let size = self.frame.size
    let header = NSRect(
      x: MainFlutterWindow.resizeMargin,
      y: size.height - MainFlutterWindow.headerHeight,
      width: size.width - 2 * MainFlutterWindow.resizeMargin,
      height: MainFlutterWindow.headerHeight - MainFlutterWindow.resizeMargin)
    guard header.contains(location) else { return false }

    let trafficLights: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    return !trafficLights.contains { type in
      guard let button = self.standardWindowButton(type) else { return false }
      return button.convert(button.bounds, to: nil).insetBy(dx: -4, dy: -4).contains(location)
    }
  }

  /// The close button. With the app to keep running, the app first takes off
  /// the screen what must not be there when the window returns, and the
  /// window then leaves. If the app cannot do that, the window closes for
  /// real, which quits the app.
  override func performClose(_ sender: Any?) {
    guard keepsRunning, let windowChannel else {
      super.performClose(sender)
      return
    }
    windowChannel.invokeMethod("windowWillClose", arguments: nil) { [weak self] answer in
      guard let self else { return }
      if answer is FlutterError || (answer as? NSObject) === FlutterMethodNotImplemented {
        NSLog("MainFlutterWindow: the app did not get ready for its window to close, so it quits: \(String(describing: answer))")
        self.closeAndQuit(sender)
        return
      }
      self.hideKeepingAppRunning()
    }
  }

  private func closeAndQuit(_ sender: Any?) {
    super.performClose(sender)
  }

  /// Takes the window off the screen, the app still running. A window in
  /// full screen comes out of it first, or its empty space would stay.
  private func hideKeepingAppRunning() {
    if self.styleMask.contains(.fullScreen) {
      hidesAfterFullScreen = true
      self.toggleFullScreen(nil)
      return
    }
    self.orderOut(nil)
  }

  @objc private func finishHidingAfterFullScreen() {
    guard hidesAfterFullScreen else { return }
    hidesAfterFullScreen = false
    self.orderOut(nil)
  }

  /// Shows the window in front of the other apps' windows, minimized, hidden
  /// or closed as it may be: a notification, the Dock icon or the menu bar
  /// icon was clicked.
  func bringToFront() {
    hidesAfterFullScreen = false
    NSApp.unhide(nil)
    if self.isMiniaturized {
      self.deminiaturize(nil)
    }
    self.makeKeyAndOrderFront(nil)
    if #available(macOS 14.0, *) {
      NSApp.activate()
    } else {
      NSApp.activate(ignoringOtherApps: true)
    }
    windowChannel?.invokeMethod("windowDidOpen", arguments: nil)
  }

  /// Moves the window with the mouse press the app's header just received.
  private func startDrag() {
    // By the time the app's request arrives the button may be up again, and
    // then there is no press left to drag with.
    guard let event = self.currentEvent,
      event.type == .leftMouseDown || event.type == .leftMouseDragged
    else { return }
    self.performDrag(with: event)
    releaseMouseInFlutter(at: event.locationInWindow)
  }

  /// Tells Flutter the mouse button is up.
  ///
  /// The system takes the mouse over for a window drag and may never deliver
  /// its mouse-up (see `performDrag(with:)`). Flutter keeps its own record of
  /// the button and has no other way to learn it was released: it would stop
  /// reporting hover and ignore the next click. A mouse-up that does arrive
  /// later finds the button already up and is read as a plain move.
  private func releaseMouseInFlutter(at location: NSPoint) {
    guard
      let mouseUp = NSEvent.mouseEvent(
        with: .leftMouseUp,
        location: location,
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: self.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 0)
    else {
      NSLog("MainFlutterWindow: could not make the mouse-up that ends a window drag for Flutter")
      return
    }
    isHeaderPressInFlutter = false
    flutterViewController?.mouseUp(with: mouseUp)
  }

  /// Does what the system is set to do for a double-click on a title bar.
  private func performTitleBarDoubleClick() {
    switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
    case "Minimize":
      self.miniaturize(nil)
    case "None":
      break
    default:
      self.zoom(nil)
    }
  }

  /// Centres the traffic lights in the header row. The title bar and its
  /// container are made as tall as the header, and each button is placed in
  /// the middle of that height.
  @objc private func layoutTrafficLights() {
    // In full screen the system owns the title bar and hides the buttons.
    if self.styleMask.contains(.fullScreen) { return }

    guard let close = self.standardWindowButton(.closeButton),
      let minimize = self.standardWindowButton(.miniaturizeButton),
      let zoom = self.standardWindowButton(.zoomButton),
      let titleBar = close.superview,
      let container = titleBar.superview
    else {
      NSLog("MainFlutterWindow: the title bar buttons were not found, so they keep the system's position")
      return
    }

    var containerFrame = container.frame
    containerFrame.size.height = MainFlutterWindow.headerHeight
    containerFrame.origin.y = self.frame.height - MainFlutterWindow.headerHeight
    container.frame = containerFrame
    // The title bar does not grow with its container on its own.
    titleBar.frame = container.bounds
    // Let the title bar finish its own layout first, so it does not move the
    // buttons again after they are placed.
    titleBar.layoutSubtreeIfNeeded()

    for (index, button) in [close, minimize, zoom].enumerated() {
      let x = MainFlutterWindow.trafficLightsLeading + CGFloat(index) * MainFlutterWindow.trafficLightsSpacing
      let y = (MainFlutterWindow.headerHeight - button.frame.height) / 2
      button.setFrameOrigin(NSPoint(x: x, y: y))
    }
  }
}
