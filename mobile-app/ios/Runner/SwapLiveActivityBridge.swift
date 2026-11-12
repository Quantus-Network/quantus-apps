import ActivityKit
import Flutter
import Foundation

/// Starts and updates the swap Live Activity, and reports its push token.
///
/// The channel is registered on every iOS version the app supports. A Live
/// Activity is started only on iOS 16.2 when the user has allowed Live
/// Activities. Otherwise `show` reports `activities_unavailable` and the app
/// posts a normal notification.
final class SwapLiveActivityBridge: NSObject, FlutterStreamHandler {
  static let shared = SwapLiveActivityBridge()

  private var eventSink: FlutterEventSink?
  private var tokenTasks: [String: Task<Void, Never>] = [:]
  private var stateTasks: [String: Task<Void, Never>] = [:]
  private var suppressDismiss: Set<String> = []

  func register(messenger: FlutterBinaryMessenger) {
    let methods = FlutterMethodChannel(name: "app.quantus/swap_live_activity", binaryMessenger: messenger)
    methods.setMethodCallHandler { [weak self] call, result in
      guard let self else { return }
      switch call.method {
      case "capabilities":
        result(self.capabilities())
      case "show":
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "Expected the swap card payload", details: nil))
          return
        }
        guard #available(iOS 16.2, *) else {
          result(FlutterError(code: "activities_unavailable", message: "Live Activities are unavailable", details: nil))
          return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
          result(FlutterError(code: "activities_unavailable", message: "Live Activities are unavailable", details: nil))
          return
        }
        self.showActivity(args, result: result)
      case "end":
        self.end(quiet: false, result: result)
      case "endQuietly":
        self.end(quiet: true, result: result)
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

  private var liveActivitiesAuthorized: Bool {
    guard #available(iOS 16.2, *) else { return false }
    return ActivityAuthorizationInfo().areActivitiesEnabled
  }

  private func capabilities() -> [String: Bool] {
    ["available": iosSupportsLiveActivities, "authorized": liveActivitiesAuthorized]
  }

  private var iosSupportsLiveActivities: Bool {
    if #available(iOS 16.2, *) {
      return true
    }
    return false
  }

  @available(iOS 16.2, *)
  private func activityError(_ error: ActivityAuthorizationError) -> FlutterError {
    switch error {
    case .denied, .unsupported, .visibility:
      return FlutterError(code: "activities_unavailable", message: error.localizedDescription, details: nil)
    default:
      return FlutterError(code: "activity_failed", message: error.localizedDescription, details: nil)
    }
  }

  private func end(quiet: Bool, result: @escaping FlutterResult) {
    Task { @MainActor in
      if #available(iOS 16.2, *) {
        await self.endAll(quiet: quiet)
      }
      result(nil)
    }
  }

  @available(iOS 16.2, *)
  private func showActivity(_ args: [String: Any], result: @escaping FlutterResult) {
    Task { @MainActor in
      do {
        try await self.show(args)
        result(nil)
      } catch let error as ActivityAuthorizationError {
        result(self.activityError(error))
      } catch {
        result(FlutterError(code: "activity_failed", message: error.localizedDescription, details: nil))
      }
    }
  }

  @available(iOS 16.2, *)
  @MainActor
  private func show(_ args: [String: Any]) async throws {
    let state = try contentState(args)
    let content = ActivityContent(state: state, staleDate: swapLiveStaleDate(revision(state), staleAt: state.staleAt))
    let activities = Activity<SwapActivityAttributes>.activities
    // An ended card stays on screen until its dismissal date, and no longer
    // takes updates. Only a card that is still running is written to.
    if let activity = activities.first(where: { $0.activityState != .ended && $0.activityState != .dismissed }) {
      // A completion push updates this activity directly. A later poll must
      // not move that same swap back to in progress.
      switch swapLiveActiveCardAction(current: revision(activity.content.state), incoming: revision(state)) {
      case .update:
        await activity.update(content)
      case .end(let dismissAt):
        await activity.end(content, dismissalPolicy: .after(dismissAt))
      case .ignore:
        break
      }
      watch(activity)
      return
    }
    guard swapLiveOpensCard(revision(state), ended: activities.map { revision($0.content.state) }) else { return }
    // A finished card still waiting for its dismissal date makes way for the new swap.
    for ended in activities {
      suppressDismiss.insert(ended.id)
      await ended.end(nil, dismissalPolicy: .immediate)
    }
    let activity = try Activity.request(attributes: SwapActivityAttributes(), content: content, pushType: .token)
    watch(activity)
  }

  @available(iOS 16.2, *)
  @MainActor
  private func endAll(quiet: Bool) async {
    for activity in Activity<SwapActivityAttributes>.activities {
      if quiet {
        suppressDismiss.insert(activity.id)
      }
      await activity.end(nil, dismissalPolicy: .immediate)
    }
  }

  @available(iOS 16.2, *)
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
          if self.suppressDismiss.remove(id) != nil {
            continue
          }
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
    let overdueLabel = args["overdueLabel"] as? String,
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
    overdueLabel: overdueLabel,
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

@available(iOS 16.2, *)
private func revision(_ state: SwapActivityAttributes.ContentState) -> SwapLiveCardRevision {
  SwapLiveCardRevision(key: state.key, updatedAt: state.updatedAt, phase: state.phase, failure: state.failure)
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
