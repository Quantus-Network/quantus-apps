import ActivityKit
import Flutter
import Foundation

/// Starts and updates the swap Live Activity, and reports its push token.
@available(iOS 16.2, *)
final class SwapLiveActivityBridge: NSObject, FlutterStreamHandler {
  static let shared = SwapLiveActivityBridge()

  private var eventSink: FlutterEventSink?
  private var tokenTasks: [String: Task<Void, Never>] = [:]
  private var stateTasks: [String: Task<Void, Never>] = [:]

  func register(messenger: FlutterBinaryMessenger) {
    let methods = FlutterMethodChannel(name: "app.quantus/swap_live_activity", binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "show":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Expected the swap card payload", details: nil))
          return
        }
        Task { @MainActor in
          do {
            try await self.show(args)
            result(nil)
          } catch {
            result(FlutterError(code: "activity_failed", message: error.localizedDescription, details: nil))
          }
        }
      case "end":
        Task { @MainActor in
          await self.endAll()
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let events = FlutterEventChannel(name: "app.quantus/swap_live_activity_events", binaryMessenger: messenger)
    events.setStreamHandler(self)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  @MainActor
  private func show(_ args: [String: Any]) async throws {
    let state = try contentState(args)
    let content = ActivityContent(state: state, staleDate: state.staleAtDate)
    if let activity = Activity<SwapActivityAttributes>.activities.first {
      await activity.update(content)
      watch(activity)
      return
    }
    let activity = try Activity.request(attributes: SwapActivityAttributes(), content: content, pushType: .token)
    watch(activity)
  }

  @MainActor
  private func endAll() async {
    for activity in Activity<SwapActivityAttributes>.activities {
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  @MainActor
  private func watch(_ activity: Activity<SwapActivityAttributes>) {
    let id = activity.id
    guard tokenTasks[id] == nil else { return }
    tokenTasks[id] = Task { @MainActor in
      for await token in activity.pushTokenUpdates {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        self.emit(["type": "token", "token": hex])
      }
    }
    stateTasks[id] = Task { @MainActor in
      for await state in activity.activityStateUpdates {
        if state == .dismissed {
          self.emit(["type": "dismissed"])
        }
      }
    }
  }

  private func emit(_ payload: [String: String]) {
    DispatchQueue.main.async { [weak self] in
      self?.eventSink?(payload)
    }
  }
}

@available(iOS 16.2, *)
private func contentState(_ args: [String: Any]) throws -> SwapActivityAttributes.ContentState {
  guard
    let phase = args["phase"] as? String,
    let headline = args["headline"] as? String,
    let brand = args["brand"] as? String,
    let idleBrand = args["idleBrand"] as? String,
    let fromAmount = args["fromAmount"] as? String,
    let fromSymbol = args["fromSymbol"] as? String,
    let toAmount = args["toAmount"] as? String,
    let toSymbol = args["toSymbol"] as? String,
    let chain = args["chain"] as? String,
    let fromLabel = args["fromLabel"] as? String,
    let toLabel = args["toLabel"] as? String,
    let chainLabel = args["chainLabel"] as? String,
    let openToCheck = args["openToCheck"] as? String,
    let agoLabel = args["agoLabel"] as? String,
    let progress = doubleValue(args["progress"]),
    let showProgress = boolValue(args["showProgress"]),
    let updatedAt = doubleValue(args["updatedAt"]),
    let staleAt = doubleValue(args["staleAt"]),
    let holdsProcess = boolValue(args["holdsProcess"]),
    let key = args["key"] as? String
  else {
    throw SwapLiveActivityError.badPayload
  }
  return SwapActivityAttributes.ContentState(
    phase: phase,
    failure: args["failure"] as? String,
    headline: headline,
    brand: brand,
    idleBrand: idleBrand,
    fromAmount: fromAmount,
    fromSymbol: fromSymbol,
    toAmount: toAmount,
    toSymbol: toSymbol,
    chain: chain,
    fromLabel: fromLabel,
    toLabel: toLabel,
    chainLabel: chainLabel,
    openToCheck: openToCheck,
    agoLabel: agoLabel,
    progress: progress,
    showProgress: showProgress,
    endsAt: doubleValue(args["endsAt"]),
    updatedAt: updatedAt,
    staleAt: staleAt,
    holdsProcess: holdsProcess,
    key: key
  )
}

private func boolValue(_ value: Any?) -> Bool? {
  switch value {
  case let flag as Bool:
    return flag
  case let number as NSNumber:
    return number.boolValue
  default:
    return nil
  }
}

private func doubleValue(_ value: Any?) -> Double? {
  switch value {
  case let number as NSNumber:
    return number.doubleValue
  case let number as Double:
    return number
  default:
    return nil
  }
}

private enum SwapLiveActivityError: LocalizedError {
  case badPayload

  var errorDescription: String? {
    switch self {
    case .badPayload:
      return "Swap card payload was missing a field"
    }
  }
}
