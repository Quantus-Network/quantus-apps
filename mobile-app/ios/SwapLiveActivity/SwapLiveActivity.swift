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
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .center) {
        SwapBrand(state: state, stale: stale)
        Spacer(minLength: 8)
        SwapTiming(state: state, stale: stale)
      }
      SwapBody(state: state, stale: stale)
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
    HStack(spacing: 8) {
      SwapTile()
      Text(stale || state.phase == "failed" ? state.idleBrand : state.brand)
        .font(.geist(13))
        .foregroundStyle(SwapPalette.content)
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
    } else if let endsAt = state.endsAtDate {
      HStack(spacing: 0) {
        Text("~")
        Text(timerInterval: Date.now...max(endsAt, Date.now.addingTimeInterval(1)), countsDown: true)
          .monospacedDigit()
      }
      .font(.geist(12))
      .foregroundStyle(SwapPalette.flare)
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(Capsule().fill(SwapPalette.flare.opacity(0.08)))
      .overlay(Capsule().stroke(SwapPalette.flare.opacity(0.3), lineWidth: 1))
    }
  }
}

private struct SwapBody: View {
  let state: SwapActivityAttributes.ContentState
  let stale: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: stale ? 10 : 6) {
      Text(state.headline)
        .font(.geist(18))
        .foregroundStyle(.white)
        .lineLimit(1)
      if state.showProgress && !stale {
        SwapProgress(progress: state.progress)
      }
      SwapFacts(state: state)
      if stale {
        Text(state.openToCheck)
          .font(.geist(11))
          .foregroundStyle(SwapPalette.flare)
      }
    }
  }
}

private struct SwapProgress: View {
  let progress: Double

  var body: some View {
    GeometryReader { geo in
      let width = geo.size.width
      let clamped = min(max(progress, 0), 1)
      ZStack(alignment: .leading) {
        Capsule().fill(SwapPalette.rule).frame(height: 3)
        Capsule().fill(SwapPalette.flare).frame(width: max(width * clamped, 3), height: 3)
        ForEach([0.25, 0.5, 0.75], id: \.self) { tick in
          Rectangle()
            .fill(Color.white.opacity(0.45))
            .frame(width: 1.5, height: 5)
            .offset(x: width * tick)
        }
        Circle()
          .fill(Color.white)
          .frame(width: 9, height: 9)
          .offset(x: width * clamped - 4.5)
      }
      .frame(height: 9)
    }
    .frame(height: 9)
  }
}

private struct SwapFacts: View {
  let state: SwapActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: 6) {
      SwapFact(label: state.fromLabel, amount: state.fromAmount, symbol: state.fromSymbol)
      factRule
      SwapFact(label: state.toLabel, amount: state.toAmount, symbol: state.toSymbol)
      factRule
      VStack(alignment: .leading, spacing: 2) {
        Text(state.chainLabel)
          .font(.geist(11, medium: true))
          .foregroundStyle(SwapPalette.content)
        Text(state.chain)
          .font(.geist(15))
          .foregroundStyle(.white)
          .lineLimit(1)
      }
    }
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
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
        .font(.geist(11, medium: true))
        .foregroundStyle(SwapPalette.content)
      HStack(alignment: .lastTextBaseline, spacing: 2) {
        Text(amount)
          .font(.geist(15))
          .foregroundStyle(.white)
        Text(symbol)
          .font(.geist(11))
          .foregroundStyle(SwapPalette.content)
      }
      .lineLimit(1)
    }
  }
}
