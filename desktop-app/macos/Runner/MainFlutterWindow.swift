import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  /// The smallest content size at which the sidebar and the account panes fit.
  private static let minimumContentSize = NSSize(width: 960, height: 640)
  private static let initialContentSize = NSSize(width: 1200, height: 800)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.contentMinSize = MainFlutterWindow.minimumContentSize
    self.setContentSize(MainFlutterWindow.initialContentSize)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
