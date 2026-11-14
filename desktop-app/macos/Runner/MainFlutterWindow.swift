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

  private var windowChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
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
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    windowChannel = channel

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

    super.awakeFromNib()

    layoutTrafficLights()
  }

  /// Moves the window with the mouse press the app's header just received.
  private func startDrag() {
    guard let event = self.currentEvent else { return }
    self.performDrag(with: event)
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
