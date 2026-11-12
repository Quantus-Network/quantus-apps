import SwiftUI

/// The countdown badge's ticking text, on every iOS version.
///
/// The card is drawn by a system process that can only rebuild SwiftUI and
/// Foundation types. A format style of ours, even a live `TimeDataSource` one,
/// cannot be rebuilt there and turns the whole card into grey placeholders. The
/// system timer keeps counting, including across a minute, without another
/// activity update.
func swapCountdownBadgeText(endsAt: Date, now: Date = .now) -> Text {
  let end = max(endsAt, now.addingTimeInterval(1))
  return Text(timerInterval: now...end, countsDown: true)
}

/// The widest badge text the timer shows from [now] on. The badge takes its
/// width from this, drawn hidden, instead of asking the timer for its own.
func swapCountdownTemplate(endsAt: Date, now: Date = .now) -> String {
  endsAt.timeIntervalSince(now) >= 3_600 ? "~0:00:00" : "~00:00"
}
