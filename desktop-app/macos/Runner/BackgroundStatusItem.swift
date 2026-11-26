import Cocoa

/// The menu bar icon, there while the window is closed with work under way,
/// so a wallet with no window is never out of sight, and while a swap is in
/// progress, which it follows: beside the icon the step the newest swap is
/// on, and in its menu each swap with its steps, which opens it. Its menu
/// also brings the window back or quits the app, in the app's language.
final class BackgroundStatusItem: NSObject {
  /// A swap in progress as the menu lists it: what it is for, and its steps,
  /// the one it is on at `current`.
  struct Swap {
    let swapId: String
    let accountId: String
    let label: String
    let steps: [String]
    let current: Int
  }

  private static let imageName = "StatusBarIcon"

  private let onOpen: () -> Void
  private let onOpenSwap: (Swap) -> Void
  private let menu = NSMenu()
  private let openItem = NSMenuItem()
  private let quitItem = NSMenuItem()
  private var item: NSStatusItem?

  /// Whether the window is off the screen with the app still running.
  private var isHiddenForWork = false

  /// What shows beside the icon; nil for the icon alone.
  private var title: String?
  private var swaps: [Swap] = []

  init(onOpen: @escaping () -> Void, onOpenSwap: @escaping (Swap) -> Void) {
    self.onOpen = onOpen
    self.onOpenSwap = onOpenSwap
    super.init()
    // The steps are there to be read, not picked.
    menu.autoenablesItems = false
    openItem.target = self
    openItem.action = #selector(openWindow)
    quitItem.target = self
    quitItem.action = #selector(quitApp)
    rebuildMenu()
  }

  /// What the icon's menu says.
  func setLabels(openLabel: String, quitLabel: String) {
    openItem.title = openLabel
    quitItem.title = quitLabel
    showTitle()
  }

  /// The window left the screen with the app still running, or came back.
  func setHiddenForWork(_ isHidden: Bool) {
    isHiddenForWork = isHidden
    updateShown()
  }

  /// The swaps in progress, in the order they started, and what shows beside
  /// the icon of them.
  func setSwaps(title: String?, swaps: [Swap]) {
    self.title = title
    self.swaps = swaps
    rebuildMenu()
    updateShown()
    showTitle()
  }

  private func rebuildMenu() {
    menu.removeAllItems()
    for swap in swaps {
      let header = NSMenuItem(title: swap.label, action: #selector(openSwap(_:)), keyEquivalent: "")
      header.target = self
      header.representedObject = swap
      menu.addItem(header)
      for (index, step) in swap.steps.enumerated() {
        let stepItem = NSMenuItem(title: step, action: nil, keyEquivalent: "")
        stepItem.isEnabled = false
        stepItem.indentationLevel = 1
        stepItem.state = index < swap.current ? .on : index == swap.current ? .mixed : .off
        menu.addItem(stepItem)
      }
      menu.addItem(.separator())
    }
    menu.addItem(openItem)
    menu.addItem(.separator())
    menu.addItem(quitItem)
  }

  /// Shows the icon while the window is hidden for work or a swap is in
  /// progress, and takes it away otherwise.
  private func updateShown() {
    guard isHiddenForWork || !swaps.isEmpty else {
      if let item {
        NSStatusBar.system.removeStatusItem(item)
        self.item = nil
      }
      return
    }
    guard item == nil else { return }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    if let image = NSImage(named: BackgroundStatusItem.imageName) {
      item.button?.image = image
    } else {
      NSLog("BackgroundStatusItem: the image \(BackgroundStatusItem.imageName) is missing from the app")
    }
    item.menu = menu
    self.item = item
    showTitle()
  }

  /// Puts the title beside the icon, or leaves the icon alone, and says what
  /// the icon is to VoiceOver and in its tooltip.
  private func showTitle() {
    guard let item, let button = item.button else { return }
    if let title {
      item.length = NSStatusItem.variableLength
      button.title = title
      button.imagePosition = .imageLeading
      button.setAccessibilityLabel(title)
    } else {
      item.length = NSStatusItem.squareLength
      button.title = ""
      button.imagePosition = .imageOnly
      button.setAccessibilityLabel(openItem.title)
    }
    button.toolTip = openItem.title
  }

  @objc private func openWindow() {
    onOpen()
  }

  @objc private func openSwap(_ sender: NSMenuItem) {
    guard let swap = sender.representedObject as? Swap else {
      NSLog("BackgroundStatusItem: a swap's menu item holds no swap")
      return
    }
    onOpenSwap(swap)
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }
}
