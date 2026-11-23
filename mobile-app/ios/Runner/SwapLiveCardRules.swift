import Foundation

/// How long a finished swap card stays after the swap finished. Same windows
/// as Android `swapLiveTimeoutMs` and the end push Senoti sends, so the card
/// leaves at the same time whichever side ends it.
let swapLiveSwappedWindow: TimeInterval = 15 * 60
let swapLiveFailedWindow: TimeInterval = 30 * 60

/// The fields that order writes to the swap card. Epochs are milliseconds.
struct SwapLiveCardRevision {
  let key: String
  let updatedAt: Double
  let phase: String
  let failure: String?
}

enum SwapLiveActiveCardAction: Equatable {
  case update
  case end(dismissAt: Date)
  case ignore
}

/// What a write does to the card still on screen. A finished swap ends the
/// card, which stays until its dismissal date.
func swapLiveActiveCardAction(current: SwapLiveCardRevision, incoming: SwapLiveCardRevision) -> SwapLiveActiveCardAction {
  guard swapLiveLocalWriteAllowed(current: current, incoming: incoming) else { return .ignore }
  if let dismissAt = swapLiveDismissalDate(phase: incoming.phase, failure: incoming.failure, updatedAt: incoming.updatedAt) {
    return .end(dismissAt: dismissAt)
  }
  return .update
}

/// Whether a write opens a new card when none is running. A finished swap never
/// opens one: with none running it either already left, or the user removed it.
/// [ended] are cards that ended but are still on screen until their dismissal
/// date, such as one a completion push ended. Their swap keeps the write order,
/// so a poll that missed the push cannot reopen that swap as in progress.
func swapLiveOpensCard(_ incoming: SwapLiveCardRevision, ended: [SwapLiveCardRevision]) -> Bool {
  if swapLiveTerminal(phase: incoming.phase, failure: incoming.failure) { return false }
  return ended.allSatisfy { swapLiveLocalWriteAllowed(current: $0, incoming: incoming) }
}

/// When a finished card leaves, counted from the moment the swap finished.
/// Nil while the swap is still open, which includes an incomplete deposit.
func swapLiveDismissalDate(phase: String, failure: String?, updatedAt: Double) -> Date? {
  guard swapLiveTerminal(phase: phase, failure: failure) else { return nil }
  let window = phase == "swapped" ? swapLiveSwappedWindow : swapLiveFailedWindow
  return Date(timeIntervalSince1970: updatedAt / 1000 + window)
}

/// When the card switches to its stale layout. A finished card has nothing
/// left to check, so it goes stale only when it leaves, as Senoti's end push does.
func swapLiveStaleDate(_ incoming: SwapLiveCardRevision, staleAt: Double) -> Date {
  swapLiveDismissalDate(phase: incoming.phase, failure: incoming.failure, updatedAt: incoming.updatedAt)
    ?? Date(timeIntervalSince1970: staleAt / 1000)
}

/// Same rule as Android `swapLiveLocalWriteAllowed`. A different swap may
/// replace the activity. The swap already on screen does not move backward.
func swapLiveLocalWriteAllowed(current: SwapLiveCardRevision, incoming: SwapLiveCardRevision) -> Bool {
  if current.key.isEmpty { return true }
  if !incoming.key.isEmpty && incoming.key != current.key { return true }
  if incoming.updatedAt < current.updatedAt { return false }
  let finished = swapLiveTerminal(phase: current.phase, failure: current.failure)
  if !finished { return true }
  return swapLiveTerminal(phase: incoming.phase, failure: incoming.failure)
}

func swapLiveTerminal(phase: String, failure: String?) -> Bool {
  if phase == "swapped" { return true }
  return phase == "failed" && failure != "incomplete"
}
