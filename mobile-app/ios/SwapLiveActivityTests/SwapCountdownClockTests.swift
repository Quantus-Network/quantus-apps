import SwiftUI

/// One render of the countdown badge must keep moving after a minute passes.
/// The test builds the `Text` once and reads it again. Nothing pushes a new
/// activity update between the two reads.
///
/// From `mobile-app/ios`:
/// swiftc -framework SwiftUI -o /tmp/swap-countdown-clock \
///   SwapLiveActivity/SwapCountdownClock.swift \
///   SwapLiveActivityTests/SwapCountdownClockTests.swift \
/// && /tmp/swap-countdown-clock

private var failures: [String] = []

private func expect(_ condition: Bool, _ message: String) {
  if !condition {
    failures.append(message)
  }
}

private func storageTypeName(_ text: Text) -> String {
  let mirror = Mirror(reflecting: text)
  guard let storage = mirror.children.first(where: { $0.label == "storage" }) else { return "" }
  let inner = Mirror(reflecting: storage.value)
  guard let any = inner.children.first else { return "" }
  return String(describing: type(of: any.value))
}

private func storageIdentity(_ text: Text) -> ObjectIdentifier? {
  let mirror = Mirror(reflecting: text)
  guard let storage = mirror.children.first(where: { $0.label == "storage" }) else { return nil }
  let inner = Mirror(reflecting: storage.value)
  guard let any = inner.children.first else { return nil }
  return ObjectIdentifier(any.value as AnyObject)
}

/// The debug text SwiftUI prints for a live or fixed format storage, quoted.
private func rendered(_ text: Text) -> String {
  let mirror = Mirror(reflecting: text)
  guard let storage = mirror.children.first(where: { $0.label == "storage" }) else { return "" }
  let inner = Mirror(reflecting: storage.value)
  guard let any = inner.children.first else { return "" }
  let description = String(describing: any.value)
  guard let open = description.range(of: ": \""), let close = description.range(of: "\"", range: open.upperBound..<description.endIndex) else {
    return description
  }
  return String(description[open.upperBound..<close.lowerBound])
}

@main
private struct SwapCountdownClockTest {
  static func main() {
    let ends = Date.now.addingTimeInterval(62)
    let badge = swapCountdownBadgeText(endsAt: ends)
    let badgeIdentity = storageIdentity(badge)
    let badgeBefore = rendered(badge)

    // The system process that draws the card can only rebuild SwiftUI and
    // Foundation types. A format style of ours turns the whole card into grey
    // placeholders, so the badge must store nothing but the system timer.
    let badgeType = storageTypeName(badge)
    expect(badgeType.contains("TimeDataFormattingStorage"), "badge stored \(badgeType), wanted a system timer")
    expect(badgeType.contains("Timer"), "badge stored \(badgeType), wanted a system timer")
    expect(!badgeType.contains("Swap"), "badge stored \(badgeType), which names a type of ours")

    Thread.sleep(forTimeInterval: 3.5)

    expect(storageIdentity(badge) == badgeIdentity, "badge was rebuilt instead of updating in place")
    expect(badgeBefore.hasPrefix("1:"), "badge started at \(badgeBefore)")
    expect(rendered(badge).hasPrefix("0:"), "badge stayed \(rendered(badge)) across the minute")

    // The badge's width comes from a hidden template, so it must fit the
    // longest value the timer shows from now on.
    let templateNow = Date(timeIntervalSince1970: 1_700_000_000)
    let templates: [(TimeInterval, String)] = [
      (-30, "~00:00"),
      (0, "~00:00"),
      (59 * 60 + 59, "~00:00"),
      (3_600, "~0:00:00"),
      (5 * 3_600, "~0:00:00"),
    ]
    for (remaining, wanted) in templates {
      let template = swapCountdownTemplate(endsAt: templateNow.addingTimeInterval(remaining), now: templateNow)
      expect(template == wanted, "template with \(remaining)s left was \(template), wanted \(wanted)")
    }

    // Past the estimate the badge reads "Taking longer" instead of a timer at 0:00.
    let overdueNow = Date(timeIntervalSince1970: 1_700_000_000)
    let overdueCases: [(TimeInterval, Bool)] = [(-1, false), (0, true), (1, true), (600, true)]
    for (sinceEnd, wanted) in overdueCases {
      let overdue = swapCountdownOverdue(endsAt: overdueNow.addingTimeInterval(-sinceEnd), now: overdueNow)
      expect(overdue == wanted, "\(sinceEnd)s past the estimate was overdue \(overdue), wanted \(wanted)")
    }

    // The card's `overdue` flag shows the label even when its push lands before
    // this phone's clock reaches the estimate. Without the flag the clock decides.
    let shownCases: [(Bool, TimeInterval, Bool)] = [(true, -30, true), (false, 0, true), (false, 1, true), (false, -30, false)]
    for (flag, sinceEnd, wanted) in shownCases {
      let shown = swapCountdownShowsOverdue(overdue: flag, endsAt: overdueNow.addingTimeInterval(-sinceEnd), now: overdueNow)
      expect(shown == wanted, "flag \(flag), \(sinceEnd)s past the estimate showed the label \(shown), wanted \(wanted)")
    }

    if failures.isEmpty {
      print("ok")
    } else {
      for failure in failures {
        fputs("FAIL \(failure)\n", stderr)
      }
      exit(1)
    }
  }
}
