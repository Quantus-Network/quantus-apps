import ActivityKit
import SwiftUI
import WidgetKit

private enum SwapPalette {
  static let card = Color(red: 14 / 255, green: 14 / 255, blue: 14 / 255)
  static let flare = Color(red: 255 / 255, green: 107 / 255, blue: 53 / 255)
  static let content = Color(red: 232 / 255, green: 230 / 255, blue: 224 / 255)
  static let rule = Color(red: 232 / 255, green: 230 / 255, blue: 224 / 255).opacity(0.16)
  static let wash = Color(red: 255 / 255, green: 84 / 255, blue: 16 / 255)
}

private extension Font {
  static func geist(_ size: CGFloat, medium: Bool = false) -> Font {
    .custom(medium ? "Geist-Medium" : "Geist-Regular", size: size)
  }
}

@main
struct SwapLiveActivityBundle: WidgetBundle {
  var body: some Widget {
    SwapLiveActivity()
  }
}

struct SwapLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: SwapActivityAttributes.self) { context in
      SwapLockScreen(state: context.state, stale: context.isStale)
        .activityBackgroundTint(SwapPalette.card)
        .widgetURL(URL(string: "quantus://swap"))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          SwapBrand(state: context.state, stale: context.isStale)
        }
        DynamicIslandExpandedRegion(.trailing) {
          SwapTiming(state: context.state, stale: context.isStale)
        }
        DynamicIslandExpandedRegion(.bottom) {
          SwapBody(state: context.state, stale: context.isStale)
        }
      } compactLeading: {
        SwapArrows()
      } compactTrailing: {
        SwapRing(progress: context.state.progress)
      } minimal: {
        SwapArrows()
      }
      .widgetURL(URL(string: "quantus://swap"))
    }
  }
}

private struct SwapLockScreen: View {
  let state: SwapActivityAttributes.ContentState
  let stale: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .center, spacing: 10) {
        SwapBrand(state: state, stale: stale)
        Spacer(minLength: 8)
        SwapTiming(state: state, stale: stale)
          .layoutPriority(1)
      }
      SwapBody(state: state, stale: stale)
        .padding(.top, 16)
    }
    .padding(18)
    .background(SwapLockBackground())
  }
}

private struct SwapLockBackground: View {
  var body: some View {
    SwapPalette.card.overlay(alignment: .bottom) {
      LinearGradient(
        colors: [SwapPalette.wash.opacity(0), SwapPalette.wash.opacity(0.34)],
        startPoint: .top,
        endPoint: .bottom
      )
      .frame(height: 72)
    }
  }
}

private struct SwapBrand: View {
  let state: SwapActivityAttributes.ContentState
  let stale: Bool

  var body: some View {
    HStack(spacing: 10) {
      SwapTile()
      Text(stale || state.phase == "failed" ? state.idleBrand : state.brand)
        .font(.geist(16))
        .foregroundStyle(SwapPalette.content)
        .lineLimit(1)
    }
  }
}

private struct SwapTile: View {
  var body: some View {
    RoundedRectangle(cornerRadius: 4)
      .fill(SwapPalette.flare.opacity(0.08))
      .overlay(RoundedRectangle(cornerRadius: 4).stroke(SwapPalette.flare.opacity(0.3), lineWidth: 1.5))
      .frame(width: 26, height: 26)
      .overlay(SwapArrows())
  }
}

private struct SwapArrows: View {
  var body: some View {
    Image(systemName: "arrow.left.arrow.right")
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(SwapPalette.flare)
  }
}

private struct SwapRing: View {
  let progress: Double

  var body: some View {
    ZStack {
      Circle().stroke(SwapPalette.flare.opacity(0.28), lineWidth: 2)
      Circle()
        .trim(from: 0, to: progress)
        .stroke(SwapPalette.flare, style: StrokeStyle(lineWidth: 2, lineCap: .round))
        .rotationEffect(.degrees(-90))
    }
    .frame(width: 16, height: 16)
  }
}

private struct SwapTiming: View {
  let state: SwapActivityAttributes.ContentState
  let stale: Bool

  var body: some View {
    if stale {
      HStack(alignment: .lastTextBaseline, spacing: 4) {
        SwapTimerSlot(template: "0:00:00", alignment: .trailing) {
          Text(timerInterval: state.updatedAtDate...Date.distantFuture, countsDown: false)
            .multilineTextAlignment(.trailing)
        }
        .font(.geist(15))
        .foregroundStyle(.white)
        .monospacedDigit()
        Text(state.agoLabel)
          .font(.geist(11))
          .foregroundStyle(SwapPalette.content)
          .lineLimit(1)
      }
    } else if let endsAt = state.endsAtDate {
      SwapCountdown(endsAt: endsAt)
    }
  }
}

private struct SwapCountdown: View {
  let endsAt: Date

  var body: some View {
    label
      .font(.geist(12))
      .foregroundStyle(SwapPalette.flare)
      .lineLimit(1)
      .padding(.horizontal, 12)
      .frame(height: 26)
      .background(Capsule().fill(SwapPalette.flare.opacity(0.08)))
      .overlay(Capsule().stroke(SwapPalette.flare.opacity(0.3), lineWidth: 1))
  }

  private var label: some View {
    SwapTimerSlot(template: swapCountdownTemplate(endsAt: endsAt), alignment: .center) {
      HStack(spacing: 0) {
        Text("~")
        swapCountdownBadgeText(endsAt: endsAt)
      }
    }
    .monospacedDigit()
  }
}

/// A timer drawn over hidden [template] text, which sets its width.
///
/// On iOS 26 the lock screen card comes out empty, with no error, when a timer
/// is asked for its ideal width, for example under `.fixedSize`. Keep
/// `.fixedSize` off a timer and everything around it, and size it with this.
/// The lock screen draws a timer across the whole slot and places its digits
/// by `multilineTextAlignment`, not by [alignment], so set both.
private struct SwapTimerSlot<Timer: View>: View {
  let template: String
  let alignment: Alignment
  @ViewBuilder let timer: Timer

  var body: some View {
    Text(template)
      .hidden()
      .overlay(alignment: alignment) { timer }
  }
}

private struct SwapBody: View {
  let state: SwapActivityAttributes.ContentState
  let stale: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(state.headline)
        .font(.geist(22))
        .foregroundStyle(.white)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
      if state.showProgress && !stale {
        SwapProgress(progress: state.progress)
          .padding(.top, 8)
      }
      SwapFacts(state: state)
        .padding(.top, state.showProgress && !stale ? 6 : 10)
      if stale {
        Text(state.openToCheck)
          .font(.geist(11))
          .foregroundStyle(SwapPalette.flare)
          .padding(.top, 10)
      }
    }
  }
}

private struct SwapProgress: View {
  let progress: Double

  /// Even stops. The knob sits on the current one, so only later stops are drawn.
  private let stops: [CGFloat] = [0.25, 0.5, 0.75]

  var body: some View {
    let clamped = CGFloat(min(max(progress, 0), 1))
    ZStack {
      SwapBar(end: 1).fill(SwapPalette.rule)
      SwapBar(end: clamped).fill(SwapPalette.flare)
      SwapStops(stops: stops.filter { $0 > clamped + 0.001 }).fill(Color.white.opacity(0.45))
      SwapKnob(at: clamped).fill(Color.white)
    }
    .frame(height: SwapKnob.diameter)
  }
}

/// WidgetKit lays the card out once with a NaN x origin before it has the real
/// one. SwiftUI's stacks and shapes carry that through, but placing a subview
/// there is a fatal error. A GeometryReader places one, so the bar and the
/// columns under it took the whole extension down, and iOS removed the card as
/// soon as it started. The bar is therefore drawn as shapes, which size their
/// pieces from the rect they are given.
private struct SwapBar: Shape {
  let end: CGFloat

  func path(in rect: CGRect) -> Path {
    Path(roundedRect: CGRect(x: rect.minX, y: rect.midY - 1.5, width: rect.width * end, height: 3), cornerRadius: 1.5)
  }
}

private struct SwapStops: Shape {
  let stops: [CGFloat]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    for stop in stops {
      path.addRect(CGRect(x: rect.minX + rect.width * stop - 0.5, y: rect.midY - 4, width: 1, height: 8))
    }
    return path
  }
}

private struct SwapKnob: Shape {
  static let diameter: CGFloat = 9

  let at: CGFloat

  func path(in rect: CGRect) -> Path {
    let radius = Self.diameter / 2
    let center = min(max(rect.width * at, radius), max(rect.width - radius, radius))
    return Path(ellipseIn: CGRect(x: rect.minX + center - radius, y: rect.midY - radius, width: Self.diameter, height: Self.diameter))
  }
}

/// Columns side by side in fixed shares of the width, each centred vertically.
private struct SwapColumns: Layout {
  let shares: [CGFloat]

  private func widths(in width: CGFloat) -> [CGFloat] {
    let total = shares.reduce(0, +)
    return shares.map { width * $0 / total }
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let width = proposal.replacingUnspecifiedDimensions().width
    let heights = zip(subviews, widths(in: width)).map {
      $0.sizeThatFits(ProposedViewSize(width: $1, height: proposal.height)).height
    }
    return CGSize(width: width, height: heights.max() ?? 0)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    // The NaN first pass described on `SwapBar`. A later pass has the origin.
    var x = bounds.minX.isFinite ? bounds.minX : 0
    for (subview, width) in zip(subviews, widths(in: bounds.width)) {
      let column = ProposedViewSize(width: width, height: bounds.height)
      let height = subview.sizeThatFits(column).height
      subview.place(at: CGPoint(x: x, y: bounds.midY - height / 2), anchor: .topLeading, proposal: column)
      x += width
    }
  }
}

private struct SwapFacts: View {
  let state: SwapActivityAttributes.ContentState

  /// Column shares measured on the Figma card (From 164, To 182, Chain 294).
  private static let shares: [CGFloat] = [164, 182, 294]
  private static let height: CGFloat = 36

  var body: some View {
    SwapColumns(shares: Self.shares) {
      SwapFact(label: state.fromLabel, amount: state.fromAmount, symbol: state.fromSymbol)
      ruled(SwapFact(label: state.toLabel, amount: state.toAmount, symbol: state.toSymbol))
      ruled(
        VStack(alignment: .leading, spacing: 4) {
          Text(state.chainLabel)
            .font(.geist(11, medium: true))
            .foregroundStyle(SwapPalette.content)
            .lineLimit(1)
          Text(state.chain)
            .font(.geist(15))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      )
    }
    .frame(height: Self.height)
  }

  /// A column behind a hairline on its leading edge.
  private func ruled(_ column: some View) -> some View {
    column
      .padding(.leading, 8)
      .frame(maxHeight: .infinity)
      .overlay(alignment: .leading) { Rectangle().fill(SwapPalette.rule).frame(width: 1) }
  }
}

private struct SwapFact: View {
  let label: String
  let amount: String
  let symbol: String

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.geist(11, medium: true))
        .foregroundStyle(SwapPalette.content)
        .lineLimit(1)
      HStack(alignment: .lastTextBaseline, spacing: 4) {
        Text(amount)
          .font(.geist(15))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .layoutPriority(1)
        Text(symbol)
          .font(.geist(11))
          .foregroundStyle(SwapPalette.content)
          .lineLimit(1)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}
