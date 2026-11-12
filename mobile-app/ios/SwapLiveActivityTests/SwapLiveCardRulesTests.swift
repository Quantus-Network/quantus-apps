import Foundation

/// When the app writes to the swap card, and when a finished card leaves.
///
/// From `mobile-app/ios`:
/// swiftc -o /tmp/swap-live-card-rules \
///   Runner/SwapLiveCardRules.swift \
///   SwapLiveActivityTests/SwapLiveCardRulesTests.swift \
/// && /tmp/swap-live-card-rules

private var failures: [String] = []

private func expect(_ condition: Bool, _ message: String) {
  if !condition {
    failures.append(message)
  }
}

private let finishedAt: Double = 1_700_000_000_000

private func card(
  _ phase: String,
  failure: String? = nil,
  key: String = "swap-a",
  updatedAt: Double = finishedAt
) -> SwapLiveCardRevision {
  SwapLiveCardRevision(key: key, updatedAt: updatedAt, phase: phase, failure: failure)
}

private func date(minutesAfterFinish minutes: Double) -> Date {
  Date(timeIntervalSince1970: finishedAt / 1000 + minutes * 60)
}

@main
private struct SwapLiveCardRulesTest {
  static func main() {
    dismissalDates()
    staleDates()
    activeCardActions()
    openingCards()

    if failures.isEmpty {
      print("ok")
    } else {
      for failure in failures {
        fputs("FAIL \(failure)\n", stderr)
      }
      exit(1)
    }
  }

  private static func dismissalDates() {
    let swapped = swapLiveDismissalDate(phase: "swapped", failure: nil, updatedAt: finishedAt)
    expect(swapped == date(minutesAfterFinish: 15), "swapped dismisses at \(String(describing: swapped))")

    for failure in ["failed", "refunded"] {
      let failed = swapLiveDismissalDate(phase: "failed", failure: failure, updatedAt: finishedAt)
      expect(failed == date(minutesAfterFinish: 30), "\(failure) dismisses at \(String(describing: failed))")
    }

    let incomplete = swapLiveDismissalDate(phase: "failed", failure: "incomplete", updatedAt: finishedAt)
    expect(incomplete == nil, "an incomplete deposit dismisses at \(String(describing: incomplete))")

    for phase in ["submitted", "confirming", "settling"] {
      let moving = swapLiveDismissalDate(phase: phase, failure: nil, updatedAt: finishedAt)
      expect(moving == nil, "\(phase) dismisses at \(String(describing: moving))")
    }
  }

  private static func staleDates() {
    // A finished card has nothing left to check, so it never turns stale before it leaves.
    let staleAt = finishedAt + 120_000
    let wantedStale = Date(timeIntervalSince1970: staleAt / 1000)

    let swapped = swapLiveStaleDate(card("swapped"), staleAt: staleAt)
    expect(swapped == date(minutesAfterFinish: 15), "swapped goes stale at \(swapped)")

    for failure in ["failed", "refunded"] {
      let failed = swapLiveStaleDate(card("failed", failure: failure), staleAt: staleAt)
      expect(failed == date(minutesAfterFinish: 30), "\(failure) goes stale at \(failed)")
    }

    let incomplete = swapLiveStaleDate(card("failed", failure: "incomplete"), staleAt: staleAt)
    expect(incomplete == wantedStale, "an incomplete deposit goes stale at \(incomplete)")

    for phase in ["submitted", "confirming", "settling"] {
      let moving = swapLiveStaleDate(card(phase), staleAt: staleAt)
      expect(moving == wantedStale, "\(phase) goes stale at \(moving)")
    }
  }

  private static func activeCardActions() {
    let finish = swapLiveActiveCardAction(current: card("settling"), incoming: card("swapped"))
    expect(finish == .end(dismissAt: date(minutesAfterFinish: 15)), "a finished swap on its card gave \(finish)")

    let refund = swapLiveActiveCardAction(current: card("settling"), incoming: card("failed", failure: "refunded"))
    expect(refund == .end(dismissAt: date(minutesAfterFinish: 30)), "a refund on its card gave \(refund)")

    let moving = swapLiveActiveCardAction(
      current: card("confirming", updatedAt: finishedAt - 60_000),
      incoming: card("settling")
    )
    expect(moving == .update, "a swap still moving gave \(moving)")

    let incomplete = swapLiveActiveCardAction(current: card("settling"), incoming: card("failed", failure: "incomplete"))
    expect(incomplete == .update, "an incomplete deposit gave \(incomplete)")

    let older = swapLiveActiveCardAction(
      current: card("swapped"),
      incoming: card("settling", updatedAt: finishedAt + 60_000)
    )
    expect(older == .ignore, "an in-progress write after the finish gave \(older)")

    let stale = swapLiveActiveCardAction(
      current: card("settling"),
      incoming: card("settling", updatedAt: finishedAt - 60_000)
    )
    expect(stale == .ignore, "an older revision gave \(stale)")

    let otherSwap = swapLiveActiveCardAction(
      current: card("swapped"),
      incoming: card("submitted", key: "swap-b", updatedAt: finishedAt - 60_000)
    )
    expect(otherSwap == .update, "a different swap on the card gave \(otherSwap)")
  }

  private static func openingCards() {
    expect(!swapLiveOpensCard(card("swapped")), "a finished swap opened a card")
    expect(!swapLiveOpensCard(card("failed", failure: "failed")), "a failed swap opened a card")
    expect(!swapLiveOpensCard(card("failed", failure: "refunded")), "a refunded swap opened a card")
    expect(swapLiveOpensCard(card("submitted", key: "swap-b")), "a new swap did not open a card")
    expect(swapLiveOpensCard(card("failed", failure: "incomplete")), "an incomplete deposit did not open a card")
  }
}
