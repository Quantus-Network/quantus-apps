import 'dart:convert';

import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';

/// iOS notification used when a Live Activity cannot run.
///
/// Distinct from Android's swap card id (71041), so cancelling this fallback
/// cannot remove the Android card.
const swapLiveNotificationId = 71042;

/// Payload on that notification. Tapping it follows the same `quantus://swap`
/// route as the Live Activity.
const swapLiveNotificationPayload = 'quantus://swap';

/// Whether this device can show the swap as a Live Activity.
class SwapLiveCapabilities {
  final bool available;
  final bool authorized;

  const SwapLiveCapabilities({required this.available, required this.authorized});
}

enum SwapLivePresentation { activity, notification }

/// A Live Activity only when the OS can run one and the user has allowed it.
/// Otherwise the swap is a normal notification.
SwapLivePresentation selectSwapLivePresentation(SwapLiveCapabilities capabilities) {
  if (capabilities.available && capabilities.authorized) return SwapLivePresentation.activity;
  return SwapLivePresentation.notification;
}

/// Where a local-notification tap should go.
sealed class LocalNotificationTap {
  const LocalNotificationTap();
}

class LocalNotificationSwapTap extends LocalNotificationTap {
  const LocalNotificationSwapTap();
}

class LocalNotificationTransactionTap extends LocalNotificationTap {
  final Map<String, dynamic> json;

  const LocalNotificationTransactionTap(this.json);
}

/// Swap taps open the swap. Every other payload stays a transaction notification.
LocalNotificationTap routeLocalNotificationTap(String payload) {
  if (payload == swapLiveNotificationPayload) return const LocalNotificationSwapTap();
  final json = jsonDecode(payload);
  if (json is! Map) {
    throw const FormatException('Notification payload was not a JSON object');
  }
  return LocalNotificationTransactionTap(Map<String, dynamic>.from(json));
}

/// Title, subtitle, and body for the fallback notification.
({String title, String subtitle, String body}) swapLiveNotificationCopy(SwapLiveActivityContent content) => (
  title: content.headline,
  subtitle: content.chain,
  body: '${content.fromAmount} ${content.fromSymbol} · ${content.toAmount} ${content.toSymbol}',
);

/// Posts and removes the fallback notification.
abstract class SwapLiveNotificationPoster {
  Future<void> show(SwapLiveActivityContent content);

  Future<void> cancel();
}

/// Where the lock-screen knob sits. The bar is four equal stops: submitted,
/// confirming, settling, and a finished swap at the end.
const swapLiveProgressSubmitted = 0.25;
const swapLiveProgressConfirming = 0.50;
const swapLiveProgressSettling = 0.75;
const swapLiveProgressSwapped = 1.0;

/// After this long without an update the card switches to the stale layout.
const swapLiveStaleAfter = Duration(minutes: 2);

/// A running app refreshes at least this often, so the stale deadline stays
/// ahead of the clock while the phase itself has not changed.
const swapLiveRefreshAfter = Duration(seconds: 45);

/// How long a Senoti register or unregister may go unanswered. The lock-screen
/// card does not wait on this; a silent connection must not hold it open.
const swapLiveRemoteTimeout = Duration(seconds: 15);

enum SwapLivePhase { submitted, confirming, settling, swapped, failed }

enum SwapLiveFailure { failed, refunded, incomplete }

/// What the lock screen shows for one moment of a swap. Strings are already
/// in the app's language, so the native card does not translate.
class SwapLiveActivityContent {
  final SwapLivePhase phase;
  final SwapLiveFailure? failure;
  final String headline;
  final String brand;
  final String idleBrand;
  final String fromAmount;
  final String fromSymbol;
  final String toAmount;
  final String toSymbol;
  final String chain;
  final String fromLabel;
  final String toLabel;
  final String chainLabel;
  final String openToCheck;
  final String agoLabel;
  final String leftLabel;
  final String minuteLabel;
  final String hourLabel;
  final double progress;
  final bool showProgress;
  final DateTime? endsAt;
  final DateTime updatedAt;
  final String depositAddress;
  final String key;

  /// Whether the swap is still moving, which keeps the Android card ongoing.
  /// The name is the wire key Senoti and both native cards read. It dates
  /// from an Android service that held the process.
  final bool holdsProcess;
  final bool simulated;
  final String locale;
  final String channelName;
  final Map<String, String> labels;

  const SwapLiveActivityContent({
    required this.phase,
    required this.failure,
    required this.headline,
    required this.brand,
    required this.idleBrand,
    required this.fromAmount,
    required this.fromSymbol,
    required this.toAmount,
    required this.toSymbol,
    required this.chain,
    required this.fromLabel,
    required this.toLabel,
    required this.chainLabel,
    required this.openToCheck,
    required this.agoLabel,
    required this.leftLabel,
    required this.minuteLabel,
    required this.hourLabel,
    required this.progress,
    required this.showProgress,
    required this.endsAt,
    required this.updatedAt,
    required this.depositAddress,
    required this.key,
    required this.holdsProcess,
    required this.simulated,
    required this.locale,
    required this.channelName,
    required this.labels,
  });

  /// Fields the native card draws. [updatedAt] moves on every refresh, so it
  /// is not part of [identity].
  Map<String, Object?> toPayload() => {
    'phase': phase.name,
    'failure': failure?.name,
    'headline': headline,
    'brand': brand,
    'idleBrand': idleBrand,
    'fromAmount': fromAmount,
    'fromSymbol': fromSymbol,
    'toAmount': toAmount,
    'toSymbol': toSymbol,
    'chain': chain,
    'fromLabel': fromLabel,
    'toLabel': toLabel,
    'chainLabel': chainLabel,
    'openToCheck': openToCheck,
    'agoLabel': agoLabel,
    'leftLabel': leftLabel,
    'minuteLabel': minuteLabel,
    'hourLabel': hourLabel,
    'progress': progress,
    'showProgress': showProgress,
    'endsAt': endsAt?.millisecondsSinceEpoch,
    'updatedAt': updatedAt.millisecondsSinceEpoch,
    'staleAt': updatedAt.add(swapLiveStaleAfter).millisecondsSinceEpoch,
    'holdsProcess': holdsProcess,
    'key': key,
    'channelName': channelName,
  };

  /// What has to change before the card is worth sending again.
  Map<String, Object?> get identity => {
    'phase': phase.name,
    'failure': failure?.name,
    'headline': headline,
    'fromAmount': fromAmount,
    'toAmount': toAmount,
    'chain': chain,
    'progress': progress,
    'showProgress': showProgress,
    'endsAt': endsAt?.millisecondsSinceEpoch,
    'key': key,
    'locale': locale,
  };
}

/// Whether [swap] ended without paying out. Incomplete deposits keep being
/// polled, so their card stays ongoing.
SwapLiveFailure? swapLiveFailure(ActiveSwap swap) => switch (swap.order.status) {
  SwapStatus.failed => SwapLiveFailure.failed,
  SwapStatus.refunded => SwapLiveFailure.refunded,
  SwapStatus.incompleteDeposit => SwapLiveFailure.incomplete,
  _ => null,
};

SwapLivePhase swapLivePhase(ActiveSwap swap) => switch (swap.order.status) {
  SwapStatus.failed || SwapStatus.refunded || SwapStatus.incompleteDeposit => SwapLivePhase.failed,
  SwapStatus.pendingDeposit => SwapLivePhase.submitted,
  SwapStatus.knownDepositTx => SwapLivePhase.confirming,
  SwapStatus.processing => SwapLivePhase.settling,
  SwapStatus.success => SwapLivePhase.swapped,
};

enum SwapLiveCommand { show, end }

class SwapLiveDecision {
  final SwapLiveCommand command;
  final SwapLiveActivityContent? content;

  const SwapLiveDecision.show(SwapLiveActivityContent this.content) : command = SwapLiveCommand.show;

  const SwapLiveDecision.end() : command = SwapLiveCommand.end, content = null;
}

/// The card to show, or [SwapLiveDecision.end] when the lock screen should
/// drop it. A swap that is still waiting for the user to send the deposit
/// stays off the lock screen. A failure stays up only while the app is not
/// in front. A finished swap stays up only while its progress screen is open.
SwapLiveDecision decideSwapLiveActivity({
  required ActiveSwap? swap,
  required AppLocalizations l10n,
  required String Function(BigInt amount, SwapToken token) formatAmount,
  required DateTime now,
  required bool progressVisible,
  required bool appInForeground,
}) {
  if (swap == null) return const SwapLiveDecision.end();
  final waitingToSend = swap.order.status == SwapStatus.pendingDeposit && !swap.depositUnderway;
  if (waitingToSend) return const SwapLiveDecision.end();
  final failure = swapLiveFailure(swap);
  if (failure != null && appInForeground) return const SwapLiveDecision.end();
  if (swap.order.status == SwapStatus.success && !progressVisible) return const SwapLiveDecision.end();
  return SwapLiveDecision.show(_content(swap, l10n, formatAmount, now, failure));
}

SwapLiveActivityContent _content(
  ActiveSwap swap,
  AppLocalizations l10n,
  String Function(BigInt amount, SwapToken token) formatAmount,
  DateTime now,
  SwapLiveFailure? failure,
) {
  final quote = swap.order.quote;
  final phase = swapLivePhase(swap);
  final source = quote.fromToken.networkName;
  final destination = quote.toToken.networkName;
  final labels = _labels(l10n, source, destination);
  final underway =
      phase == SwapLivePhase.submitted || phase == SwapLivePhase.confirming || phase == SwapLivePhase.settling;
  final started = swap.startedAt.toUtc();
  return SwapLiveActivityContent(
    phase: phase,
    failure: failure,
    headline: _headline(l10n, phase, failure, source, destination),
    brand: failure == null ? l10n.swapLiveBrand : l10n.swapLiveBrandIdle,
    idleBrand: l10n.swapLiveBrandIdle,
    fromAmount: formatAmount(quote.amountIn, quote.fromToken),
    fromSymbol: quote.fromToken.symbol,
    toAmount: formatAmount(swap.order.amountOut ?? quote.amountOut, quote.toToken),
    toSymbol: quote.toToken.symbol,
    chain: source,
    fromLabel: l10n.swapLiveFrom,
    toLabel: l10n.swapLiveTo,
    chainLabel: l10n.swapLiveChain,
    openToCheck: l10n.swapLiveOpenToCheck,
    agoLabel: l10n.swapLiveAgo,
    leftLabel: l10n.swapLiveLeft,
    minuteLabel: l10n.swapLiveMinute,
    hourLabel: l10n.swapLiveHour,
    progress: _progress(phase),
    showProgress: failure == null,
    endsAt: underway ? started.add(quote.timeEstimate) : null,
    updatedAt: now.toUtc(),
    depositAddress: swap.order.depositAddress,
    key: '${swap.order.depositAddress}|${started.millisecondsSinceEpoch}',
    holdsProcess: underway || failure == SwapLiveFailure.incomplete,
    simulated: swap.simulated,
    locale: l10n.localeName,
    channelName: l10n.swapLiveChannel,
    labels: labels,
  );
}

String _headline(
  AppLocalizations l10n,
  SwapLivePhase phase,
  SwapLiveFailure? failure,
  String source,
  String destination,
) => switch (phase) {
  SwapLivePhase.submitted => l10n.swapLiveSubmitted,
  SwapLivePhase.confirming => l10n.swapStepConfirming(source),
  SwapLivePhase.settling => l10n.swapLiveSettling(destination),
  SwapLivePhase.swapped => l10n.swapLiveSwapped,
  SwapLivePhase.failed => switch (failure) {
    SwapLiveFailure.refunded => l10n.swapRefundedLabel,
    SwapLiveFailure.incomplete => l10n.swapDepositIncompleteTitle,
    _ => l10n.swapFailedTitle,
  },
};

double _progress(SwapLivePhase phase) => switch (phase) {
  SwapLivePhase.submitted => swapLiveProgressSubmitted,
  SwapLivePhase.confirming => swapLiveProgressConfirming,
  SwapLivePhase.settling => swapLiveProgressSettling,
  SwapLivePhase.swapped => swapLiveProgressSwapped,
  SwapLivePhase.failed => 0,
};

Map<String, String> _labels(AppLocalizations l10n, String source, String destination) => {
  'brand': l10n.swapLiveBrand,
  'idleBrand': l10n.swapLiveBrandIdle,
  'from': l10n.swapLiveFrom,
  'to': l10n.swapLiveTo,
  'chain': l10n.swapLiveChain,
  'openToCheck': l10n.swapLiveOpenToCheck,
  'ago': l10n.swapLiveAgo,
  'submitted': l10n.swapLiveSubmitted,
  'confirming': l10n.swapStepConfirming(source),
  'settling': l10n.swapLiveSettling(destination),
  'swapped': l10n.swapLiveSwapped,
  'failed': l10n.swapFailedTitle,
  'refunded': l10n.swapRefundedLabel,
  'incomplete': l10n.swapDepositIncompleteTitle,
};

/// Body posted to Senoti when a card starts. Senoti stores it and, when
/// 1Click reports a new status, sends `content_state` back with the new phase
/// filled in. It does not translate: `labels` already matches the app language.
///
/// Status to phase: PENDING_DEPOSIT submitted, KNOWN_DEPOSIT_TX confirming,
/// PROCESSING settling, SUCCESS swapped, FAILED failed, REFUNDED refunded,
/// INCOMPLETE_DEPOSIT incomplete. The headline is `labels[phase]`, or
/// `labels[failure]` when the phase is failed. Progress comes from `progress`.
/// A failed or finished phase drops `endsAt` and `showProgress`. Epochs are
/// milliseconds. iOS pushes `content_state` as the Live Activity content state
/// (`apns-push-type: liveactivity`, topic `<bundle>.push-type.liveactivity`)
/// and sets the stale date from `staleAt`. Android sends the same map as an
/// FCM data message with `type` = `swap_live_activity`.
Map<String, Object?> swapLiveActivityRegistrationBody({
  required String token,
  required String platform,
  required SwapLiveActivityContent content,
}) => {
  'activity_token': token,
  'platform': platform,
  'deposit_address': content.depositAddress,
  'locale': content.locale,
  'phase': content.phase.name,
  'failure': content.failure?.name,
  'from_amount': content.fromAmount,
  'from_symbol': content.fromSymbol,
  'to_amount': content.toAmount,
  'to_symbol': content.toSymbol,
  'chain': content.chain,
  'ends_at': content.endsAt?.millisecondsSinceEpoch,
  'labels': content.labels,
  'content_state': content.toPayload(),
  'progress': {
    'submitted': swapLiveProgressSubmitted,
    'confirming': swapLiveProgressConfirming,
    'settling': swapLiveProgressSettling,
    'swapped': swapLiveProgressSwapped,
  },
};
