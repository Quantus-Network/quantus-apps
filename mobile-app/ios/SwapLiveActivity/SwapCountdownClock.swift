import SwiftUI

/// "~5 min left", rounding the remainder up to the next minute.
func swapTimeLeft(endsAt: Date, now: Date, minute: String, hour: String, left: String) -> String {
  let minutes = swapMinutesRemaining(until: endsAt, now: now)
  if minutes < 60 {
    return "~\(minutes) \(minute) \(left)"
  }
  let hours = minutes / 60
  let rest = minutes % 60
  if rest == 0 {
    return "~\(hours) \(hour) \(left)"
  }
  return "~\(hours) \(hour) \(rest) \(minute) \(left)"
}

private func swapMinutesRemaining(until endsAt: Date, now: Date) -> Int {
  let seconds = endsAt.timeIntervalSince(now)
  if seconds <= 0 { return 0 }
  return Int(ceil(seconds / 60))
}

@available(iOS 18.0, *)
struct SwapTimeLeft: FormatStyle, DiscreteFormatStyle, Codable, Equatable {
  var endsAt: Date
  var minuteLabel: String
  var hourLabel: String
  var leftLabel: String

  func format(_ now: Date) -> String {
    swapTimeLeft(endsAt: endsAt, now: now, minute: minuteLabel, hour: hourLabel, left: leftLabel)
  }

  func discreteInput(before now: Date) -> Date? {
    swapTimeLeftBoundary(endsAt: endsAt, now: now, later: false)
  }

  func discreteInput(after now: Date) -> Date? {
    swapTimeLeftBoundary(endsAt: endsAt, now: now, later: true)
  }
}

/// The next moment the rounded minute changes. [later] follows the clock forward.
private func swapTimeLeftBoundary(endsAt: Date, now: Date, later: Bool) -> Date? {
  let seconds = endsAt.timeIntervalSince(now)
  if later {
    if seconds <= 0 { return nil }
    let minutes = Int(ceil(seconds / 60))
    let boundary = TimeInterval(minutes - 1) * 60
    let at = endsAt.addingTimeInterval(-boundary)
    if at > now { return at }
    let earlier = TimeInterval(minutes - 2) * 60
    let next = earlier > 0 ? endsAt.addingTimeInterval(-earlier) : endsAt
    return next > now ? next : nil
  }
  let minutes = seconds <= 0 ? 0 : Int(ceil(seconds / 60))
  let at = endsAt.addingTimeInterval(-TimeInterval(minutes) * 60)
  if at < now { return at }
  return endsAt.addingTimeInterval(-TimeInterval(minutes + 1) * 60)
}

/// Rounded "~5 min left" badge on iOS 18.
///
/// `TimeDataSource.currentDate` is the clock. The formatter is asked again at
/// each minute boundary, so the badge moves while the app is suspended.
/// Passing `Date.now` stores that instant and the badge keeps it.
@available(iOS 18.0, *)
func swapCountdownLiveText(endsAt: Date, minute: String, hour: String, left: String) -> Text {
  let style = SwapTimeLeft(endsAt: endsAt, minuteLabel: minute, hourLabel: hour, leftLabel: left)
  return Text(TimeDataSource<Date>.currentDate, format: style)
}

/// Countdown badge on iOS 16.2–17.
///
/// Those systems have no custom live formatter, so this keeps the system timer.
/// The timer keeps counting, including across a minute, without another activity update.
func swapCountdownTimerText(endsAt: Date, now: Date = .now) -> Text {
  let end = max(endsAt, now.addingTimeInterval(1))
  return Text(timerInterval: now...end, countsDown: true)
}
