import Cocoa

/// The menu bar icon, there while the window is closed with work under way,
/// so a wallet with no window is never out of sight. Its menu brings the
/// window back or quits the app, in the app's language.
final class BackgroundStatusItem: NSObject {
  private static let imageName = "StatusBarIcon"

  private let onOpen: () -> Void
  private let menu = NSMenu()
  private let openItem = NSMenuItem()
  private let quitItem = NSMenuItem()
  private var item: NSStatusItem?

  init(onOpen: @escaping () -> Void) {
    self.onOpen = onOpen
    super.init()
    openItem.target = self
    openItem.action = #selector(openWindow)
    quitItem.target = self
    quitItem.action = #selector(quitApp)
    menu.addItem(openItem)
    menu.addItem(.separator())
    menu.addItem(quitItem)
  }

  /// What the icon's menu says.
  func setLabels(openLabel: String, quitLabel: String) {
    openItem.title = openLabel
    quitItem.title = quitLabel
    item?.button?.toolTip = openLabel
    item?.button?.setAccessibilityLabel(openLabel)
  }

  /// Shows the icon or takes it away.
  func setShown(_ isShown: Bool) {
    guard isShown else {
      if let item {
        NSStatusBar.system.removeStatusItem(item)
        self.item = nil
      }
      return
    }
    guard item == nil else { return }
    let openLabel = openItem.title

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let image = NSImage(named: BackgroundStatusItem.imageName) {
      item.button?.image = image
    } else {
      NSLog("BackgroundStatusItem: the image \(BackgroundStatusItem.imageName) is missing from the app")
    }
    item.button?.toolTip = openLabel
    item.button?.setAccessibilityLabel(openLabel)
    item.menu = menu
    self.item = item
  }

  @objc private func openWindow() {
    onOpen()
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }
}
