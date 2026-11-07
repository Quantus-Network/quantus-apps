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
        Text(timerInterval: state.updatedAtDate...Date.distantFuture, countsDown: false)
          .font(.geist(15))
          .foregroundStyle(.white)
          .monospacedDigit()
        Text(state.agoLabel)
          .font(.geist(11))
          .foregroundStyle(SwapPalette.content)
      }
      .fixedSize(horizontal: true, vertical: false)
    } else if let endsAt = state.endsAtDate {
      SwapCountdown(
        endsAt: endsAt,
        minute: swapCountdownWord(state.minuteLabel, fallback: "min"),
        hour: swapCountdownWord(state.hourLabel, fallback: "hr"),
        left: swapCountdownWord(state.leftLabel, fallback: "left")
      )
    }
  }
}

/// Words for a card started before the countdown labels were sent.
private func swapCountdownWord(_ value: String?, fallback: String) -> String {
  guard let value else { return fallback }
  let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
  return trimmed.isEmpty ? fallback : trimmed
}

private struct SwapCountdown: View {
  let endsAt: Date
  let minute: String
  let hour: String
  let left: String

  var body: some View {
    label
      .font(.geist(12))
      .foregroundStyle(SwapPalette.flare)
      .lineLimit(1)
      .fixedSize(horizontal: true, vertical: false)
      .padding(.horizontal, 12)
      .frame(height: 26)
      .background(Capsule().fill(SwapPalette.flare.opacity(0.08)))
      .overlay(Capsule().stroke(SwapPalette.flare.opacity(0.3), lineWidth: 1))
  }

  @ViewBuilder
  private var label: some View {
    if #available(iOS 18.0, *) {
      swapCountdownLiveText(endsAt: endsAt, minute: minute, hour: hour, left: left)
    } else {
      HStack(spacing: 0) {
        Text("~")
        swapCountdownTimerText(endsAt: endsAt)
          .monospacedDigit()
      }
    }
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
    GeometryReader { geo in
      let width = geo.size.width
      let clamped = min(max(progress, 0), 1)
      let knob: CGFloat = 9
      let center = min(max(width * clamped, knob / 2), max(width - knob / 2, knob / 2))
      ZStack(alignment: .leading) {
        Capsule()
          .fill(SwapPalette.rule)
          .frame(width: width, height: 3)
        Capsule()
          .fill(SwapPalette.flare)
          .frame(width: max(width * clamped, 0), height: 3)
        ForEach(stops, id: \.self) { stop in
          if stop > clamped + 0.001 {
            Rectangle()
              .fill(Color.white.opacity(0.45))
              .frame(width: 1, height: 8)
              .position(x: width * stop, y: geo.size.height / 2)
          }
        }
        Circle()
          .fill(Color.white)
          .frame(width: knob, height: knob)
          .position(x: center, y: geo.size.height / 2)
      }
    }
    .frame(height: 9)
  }
}

/// Column shares measured on the Figma card (From 164, To 182, Chain 294).
private enum SwapFactsLayout {
  static let from: CGFloat = 164
  static let to: CGFloat = 182
  static let chain: CGFloat = 294

  static func width(_ share: CGFloat, of inner: CGFloat) -> CGFloat {
    inner * share / (from + to + chain)
  }
}

private struct SwapFacts: View {
  let state: SwapActivityAttributes.ContentState

  var body: some View {
    GeometryReader { geo in
      let inner = max(geo.size.width - 2, 0)
      HStack(alignment: .center, spacing: 0) {
        SwapFact(label: state.fromLabel, amount: state.fromAmount, symbol: state.fromSymbol)
          .frame(width: SwapFactsLayout.width(SwapFactsLayout.from, of: inner), alignment: .leading)
        factRule
        SwapFact(label: state.toLabel, amount: state.toAmount, symbol: state.toSymbol)
          .padding(.leading, 7)
          .frame(width: SwapFactsLayout.width(SwapFactsLayout.to, of: inner), alignment: .leading)
        factRule
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
        .padding(.leading, 7)
        .frame(width: SwapFactsLayout.width(SwapFactsLayout.chain, of: inner), alignment: .leading)
      }
    }
    .frame(height: 36)
  }

  private var factRule: some View {
    Rectangle().fill(SwapPalette.rule).frame(width: 1, height: 36)
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
