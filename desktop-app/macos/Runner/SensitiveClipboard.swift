import Cocoa
import FlutterMacOS

/// Puts a secret such as a recovery phrase on the pasteboard for a short
/// time, and asks clipboard history not to keep it. `SensitiveClipboard` in
/// `lib/services/sensitive_clipboard.dart` is the app's side.
///
/// The copy carries nspasteboard.org's concealed and transient markers,
/// which clipboard managers honour by not recording it, and is for this Mac
/// only, so Universal Clipboard does not hand it to other devices. A manager
/// may still ignore the markers: they are a request, not a guarantee.
///
/// `clear`, and quitting the app, empty the pasteboard only while it still
/// holds that copy, so something the user copied since is left alone.
final class SensitiveClipboard {
  static let shared = SensitiveClipboard()

  private static let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
  private static let transientType = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

  private var channel: FlutterMethodChannel?

  /// The pasteboard's change count just after the last copy, while that
  /// copy has not been cleared.
  private var copiedChangeCount: Int?

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.quantus/sensitive_clipboard", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "copy":
        guard let arguments = call.arguments as? [String: Any], let text = arguments["text"] as? String else {
          result(FlutterError(code: "arguments", message: "copy needs the text to copy", details: nil))
          return
        }
        if self.copy(text) {
          result(nil)
        } else {
          result(FlutterError(code: "pasteboard", message: "The pasteboard did not take the copy", details: nil))
        }
      case "clear":
        self.clearIfUnchanged()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.channel = channel
  }

  private func copy(_ text: String) -> Bool {
    let pasteboard = NSPasteboard.general
    copiedChangeCount = nil
    // Empties the pasteboard, and keeps what follows on this Mac.
    pasteboard.prepareForNewContents(with: .currentHostOnly)
    let item = NSPasteboardItem()
    guard item.setString(text, forType: .string),
      item.setString("", forType: SensitiveClipboard.concealedType),
      item.setString("", forType: SensitiveClipboard.transientType),
      pasteboard.writeObjects([item])
    else {
      return false
    }
    copiedChangeCount = pasteboard.changeCount
    return true
  }

  /// Empties the pasteboard if it still holds the last copy.
  func clearIfUnchanged() {
    guard let copied = copiedChangeCount else { return }
    copiedChangeCount = nil
    let pasteboard = NSPasteboard.general
    if pasteboard.changeCount == copied {
      pasteboard.clearContents()
    }
  }
}
