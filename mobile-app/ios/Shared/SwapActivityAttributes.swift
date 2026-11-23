import ActivityKit
import Foundation

/// The lock-screen card. Display strings arrive already translated. Epochs are
/// milliseconds. The widget reads this type, and so does the app that starts
/// the activity, so both targets compile this file.
@available(iOS 16.2, *)
struct SwapActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var phase: String
    var failure: String?
    var headline: String
    var brand: String
    var idleBrand: String
    var fromAmount: String
    var fromSymbol: String
    var toAmount: String
    var toSymbol: String
    var chain: String
    var fromLabel: String
    var toLabel: String
    var chainLabel: String
    var openToCheck: String
    var agoLabel: String
    var overdueLabel: String
    var progress: Double
    var showProgress: Bool
    var endsAt: Double?
    /// Set once the estimate has passed, by the app or by Senoti's push at the
    /// deadline. The badge trusts it even when this phone's clock is behind.
    var overdue: Bool
    var updatedAt: Double
    var staleAt: Double
    var holdsProcess: Bool
    var key: String

    var endsAtDate: Date? {
      guard let endsAt else { return nil }
      return Date(timeIntervalSince1970: endsAt / 1000)
    }

    var updatedAtDate: Date {
      Date(timeIntervalSince1970: updatedAt / 1000)
    }

    var staleAtDate: Date {
      Date(timeIntervalSince1970: staleAt / 1000)
    }
  }
}
