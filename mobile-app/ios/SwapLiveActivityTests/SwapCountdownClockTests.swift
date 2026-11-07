import SwiftUI

/// One render of each countdown branch must keep moving after a minute passes.
/// The test builds each `Text` once and reads it again. Nothing pushes a new
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
    let live = swapCountdownLiveText(endsAt: ends, minute: "min", hour: "hr", left: "left")
    let timer = swapCountdownTimerText(endsAt: ends)
    let liveIdentity = storageIdentity(live)
    let timerIdentity = storageIdentity(timer)
    let liveBefore = rendered(live)
    let timerBefore = rendered(timer)

    let liveType = storageTypeName(live)
    expect(liveType.contains("TimeDataFormattingStorage"), "iOS 18 text stored \(liveType), wanted a live time source")
    expect(liveType.contains("SwapTimeLeft"), "iOS 18 text stored \(liveType), wanted the countdown formatter")
    expect(!liveType.contains("FormatStyleStorage"), "iOS 18 text stored a fixed date in \(liveType)")

    let timerType = storageTypeName(timer)
    expect(timerType.contains("TimeDataFormattingStorage"), "earlier text stored \(timerType), wanted a system timer")
    expect(timerType.contains("Timer"), "earlier text stored \(timerType), wanted a system timer")
    expect(timerType != "String", "earlier text stored a finished string")

    Thread.sleep(forTimeInterval: 3.5)

    expect(storageIdentity(live) == liveIdentity, "iOS 18 text was rebuilt instead of updating in place")
    expect(storageIdentity(timer) == timerIdentity, "earlier text was rebuilt instead of updating in place")
    expect(liveBefore == "~2 min left", "iOS 18 text started at \(liveBefore)")
    expect(rendered(live) == "~1 min left", "iOS 18 text stayed \(rendered(live)) across the minute")
    expect(timerBefore.hasPrefix("1:"), "system timer started at \(timerBefore)")
    expect(rendered(timer).hasPrefix("0:"), "system timer stayed \(rendered(timer)) across the minute")

    let scheduleEnds = Date(timeIntervalSince1970: 1_700_000_000)
    let scheduleNow = scheduleEnds.addingTimeInterval(-300)
    let schedule = SwapTimeLeft(endsAt: scheduleEnds, minuteLabel: "min", hourLabel: "hr", leftLabel: "left")
    let scheduledNext = schedule.discreteInput(after: scheduleNow)
    expect(schedule.format(scheduleNow) == "~5 min left", "formatter at 5 minutes was \(schedule.format(scheduleNow))")
    expect(scheduledNext?.timeIntervalSince(scheduleNow) == 60, "next minute boundary was \(String(describing: scheduledNext))")
    if let scheduledNext {
      expect(
        schedule.format(scheduledNext) == "~4 min left",
        "formatter at the next minute was \(schedule.format(scheduledNext))"
      )
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
