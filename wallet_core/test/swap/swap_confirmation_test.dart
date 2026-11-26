import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/notification_models.dart';
import 'package:wallet_core/models/swap_preflight.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_core_overrides.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/services/local_notifications.dart';
import 'package:wallet_core/services/remote_config_service.dart';
import 'package:wallet_core/services/transaction_submission_service.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/swap/swap_confirmation.dart';

import '../fakes.dart';

const _usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
const _qtc = SwapToken(
  assetId: 'nep141:qtc.omft.near',
  symbol: 'QTC',
  network: SwapToken.quantusNetwork,
  decimals: AppConstants.decimals,
  usdPrice: 0.1,
  isQuantus: true,
);
const _deposit = 'qzdeposit';
final _unit = BigInt.from(10).pow(AppConstants.decimals);
final _fee = _unit ~/ BigInt.from(50);

/// Remote config whose location verdict a test changes.
class _RemoteConfig extends RemoteConfigService {
  RemoteConfigModel remote = RemoteConfigModel.defaults;
  int reads = 0;

  @override
  RemoteConfigModel readLocalConfig() => RemoteConfigModel.defaults;

  @override
  Future<RemoteConfigModel?> readRemoteConfig() async {
    reads++;
    return remote;
  }

  @override
  Future<void> cacheConfig(Object json) async {}
}

class _Config extends RemoteConfigNotifier {
  _Config(this.service) : super(service);

  final _RemoteConfig service;

  static final _denied = RemoteConfigModel.fromJson(const {'geoNearAllowed': false});

  /// The location stops allowing swaps, as a refresh would find.
  void revoke() => state = _denied;

  /// The next refresh, such as the one after approval, finds it not allowed.
  void denyNextRefresh() => service.remote = _denied;
}

class _NoNotifications implements LocalNotifications {
  @override
  Future<void> showOrScheduleNotification(NotificationData notification) async {}

  @override
  Future<void> cancelAll() async {}
}

/// 1Click as far as a confirmation asks it: a live quote for a dry one, and
/// word of the deposit.
class _OneClick extends Fake implements SwapService {
  /// What the live quote pays and asks, when it differs from the dry one.
  BigInt? liveOut;
  BigInt? liveIn;

  /// When the live quote's deposit window closes.
  Duration window = const Duration(minutes: 20);

  /// Holds every live quote until completed.
  Completer<void>? hold;

  /// What every live quote is refused with.
  Object? refusal;

  final created = <SwapQuote>[];
  final deposits = <(String, String)>[];

  @override
  Future<SwapOrder> createSwap(SwapQuote quote) async {
    created.add(quote);
    await hold?.future;
    if (refusal case final refusal?) throw refusal;
    final out = liveOut ?? quote.amountOut;
    return SwapOrder(
      quote: _quote(
        swapOut: quote.fromToken.isQuantus,
        amountIn: liveIn ?? quote.amountIn,
        amountOut: out,
        depositAddress: _deposit,
        deadline: clock.now().add(window),
      ),
      status: SwapStatus.pendingDeposit,
    );
  }

  @override
  Future<void> submitDeposit(SwapOrder order, String txHash) async => deposits.add((order.depositAddress, txHash));

  @override
  Future<SwapOrder> getSwapStatus(SwapOrder order) async => order;
}

/// The chain taking a transfer, once [hold] completes when there is one, or
/// refusing it.
class _Submission extends FakeTransactionSubmissionService {
  Completer<void>? hold;
  bool refuses = false;

  /// How many transfers were asked for, sent or not.
  int asked = 0;

  @override
  Future<String> balanceTransfer(
    Account account, {
    required RuntimeCall call,
    required String targetAddress,
    required BigInt amount,
    required BigInt fee,
  }) async {
    asked++;
    await hold?.future;
    if (refuses) throw StateError('chain down');
    return super.balanceTransfer(account, call: call, targetAddress: targetAddress, amount: amount, fee: fee);
  }
}

/// 250 QTC for USDC, or 25 USDC for QTC; the least that arrives is 1% under.
SwapQuote _quote({
  bool swapOut = true,
  BigInt? amountIn,
  BigInt? amountOut,
  String? depositAddress,
  DateTime? deadline,
}) {
  final paid = amountIn ?? (swapOut ? _unit * BigInt.from(250) : BigInt.from(25000000));
  final out = amountOut ?? (swapOut ? BigInt.from(24860000) : _unit * BigInt.from(248));
  return SwapQuote(
    fromToken: swapOut ? _qtc : _usdc,
    toToken: swapOut ? _usdc : _qtc,
    amountIn: paid,
    minAmountIn: paid,
    amountOut: out,
    minAmountOut: out * BigInt.from(99) ~/ BigInt.from(100),
    amountInUsd: 25,
    amountOutUsd: 24.86,
    slippageBps: 100,
    refundAddress: swapOut ? 'qzaccount' : '0xrefund',
    recipient: swapOut ? '0xrecipient' : 'qzaccount',
    deadline: deadline ?? clock.now().add(const Duration(minutes: 20)),
    timeEstimate: const Duration(minutes: 1),
    correlationId: 'c',
    signature: 's',
    depositAddress: depositAddress,
  );
}

/// A swap under way whose deposit went to [depositAddress].
ActiveSwap _running(Account account, String depositAddress) => ActiveSwap(
  order: SwapOrder(
    quote: _quote(depositAddress: depositAddress),
    status: SwapStatus.processing,
  ),
  accountId: account.accountId,
  accountName: account.name,
  startedAt: clock.now(),
  depositByHand: false,
);

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final account = makeAccount(1);
  late _OneClick oneClick;
  late _Submission submission;
  late FakeSettingsService settings;
  late _Config config;
  late FakeUserApproval approval;
  late FakeTelemetry telemetry;
  late StateProvider<SwapService> services;
  late bool active;

  setUp(() {
    oneClick = _OneClick();
    submission = _Submission();
    settings = FakeSettingsService();
    config = _Config(_RemoteConfig());
    approval = FakeUserApproval();
    telemetry = FakeTelemetry();
    services = StateProvider<SwapService>((_) => oneClick);
    active = true;
  });

  List<Override> overrides({SwapPreflight? preflight}) => [
    ...walletCoreOverrides(
      telemetry: (_) => telemetry,
      pushRegistration: (_) => FakePushRegistration(),
      localNotifications: (_) => _NoNotifications(),
      userApproval: (_) => approval,
    ),
    settingsServiceProvider.overrideWithValue(settings),
    l10nProvider.overrideWithValue(l10n),
    remoteConfigProvider.overrideWith((ref) => config),
    swapPreflightProvider.overrideWithValue(preflight),
    swapServiceProvider.overrideWith((ref) => ref.watch(services)),
    swapDepositFeeProvider.overrideWith((ref, _) async => _fee),
    balancesServiceProvider.overrideWithValue(FakeBalancesService()),
    transactionSubmissionServiceProvider.overrideWithValue(submission),
  ];

  /// A ref with the deposit's fee already known for [quote], as the review
  /// has it by the time it can be confirmed.
  Future<WidgetRef> pumpReview(WidgetTester tester, SwapQuote quote, {SwapPreflight? preflight}) async {
    final ref = await pumpRef(tester, overrides: overrides(preflight: preflight));
    ref.listenManual(swapDepositFeeProvider((account, quote.amountIn)), (_, _) {});
    await tester.pump();
    return ref;
  }

  Future<SwapConfirmOutcome> confirm(SwapConfirmation confirmation, WidgetRef ref, SwapQuote quote) =>
      confirmation.confirm(ref, quote, isActive: () => active);

  /// Lets what is under way run until it next waits on something held.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('a live quote as good as the one reviewed sends the deposit, tells 1Click, and follows the swap', (
    tester,
  ) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);

    final outcome = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(outcome, isA<SwapConfirmed>());
    expect(oneClick.created, [quote]);
    expect(approval.reasons, [l10n.sendReviewAuthReason]);
    expect(submission.transfers, [(_deposit, quote.amountIn, _fee)]);
    expect(oneClick.deposits, [(_deposit, '0xtxhash')]);

    final swap = ref.read(activeSwapsProvider).single;
    expect((outcome as SwapConfirmed).swap, same(swap), reason: 'the outcome names the swap that started');
    expect(swap.order.depositAddress, _deposit);
    expect(swap.accountId, account.accountId);
    expect(swap.accountName, account.name);
    expect(swap.depositByHand, isFalse);
    expect(swap.depositTxHash, '0xtxhash');
    expect(swap.depositFee, _fee);
    expect(settings.activeSwaps.single.depositTxHash, '0xtxhash');
    expect(telemetry.events, ['swap_started']);
  });

  testWidgets('a live quote that pays out less gives the new terms and sends nothing; confirming again reuses it', (
    tester,
  ) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    final confirmation = SwapConfirmation(account: account);
    oneClick.liveOut = BigInt.from(20000000);

    final first = await confirm(confirmation, ref, quote);

    expect(first, isA<SwapTermsChanged>());
    final live = (first as SwapTermsChanged).quote;
    expect(live.amountOut, BigInt.from(20000000));
    expect(live.depositAddress, _deposit);
    expect(submission.asked, 0);
    expect(approval.reasons, isEmpty);
    expect(ref.read(activeSwapsProvider), isEmpty);

    final second = await confirm(confirmation, ref, live);

    expect(second, isA<SwapConfirmed>());
    expect(oneClick.created, hasLength(1), reason: 'the live quote is kept, with its deposit address');
    expect(submission.transfers, [(_deposit, quote.amountIn, _fee)]);
    expect(ref.read(activeSwapsProvider).single.order.quote.amountOut, BigInt.from(20000000));
  });

  testWidgets('a live quote that asks for more is new terms too', (tester) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    oneClick.liveIn = quote.amountIn + BigInt.one;

    final outcome = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(outcome, isA<SwapTermsChanged>());
    expect((outcome as SwapTermsChanged).quote.amountIn, quote.amountIn + BigInt.one);
    expect(submission.asked, 0);
  });

  testWidgets('a kept live quote too near its deadline is replaced by a fresh one', (tester) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    final confirmation = SwapConfirmation(account: account);
    oneClick
      ..liveOut = BigInt.from(20000000)
      ..window = SwapService.minimumDepositLead - const Duration(seconds: 1);

    final first = await confirm(confirmation, ref, quote) as SwapTermsChanged;
    oneClick.window = const Duration(minutes: 20);
    final second = await confirm(confirmation, ref, first.quote);

    expect(oneClick.created, hasLength(2));
    expect(second, isA<SwapConfirmed>());
  });

  testWidgets('a rebuilt swap service drops the kept live quote: the next confirmation asks the new one', (
    tester,
  ) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    final confirmation = SwapConfirmation(account: account);
    oneClick.liveOut = BigInt.from(20000000);
    final first = await confirm(confirmation, ref, quote) as SwapTermsChanged;

    final rebuilt = _OneClick()..liveOut = BigInt.from(20000000);
    ref.read(services.notifier).state = rebuilt;
    confirmation.serviceRebuilt();
    await tester.pump();
    final second = await confirm(confirmation, ref, first.quote);

    expect(oneClick.created, hasLength(1));
    expect(rebuilt.created, hasLength(1));
    expect(second, isA<SwapConfirmed>());
    expect(rebuilt.deposits, [(_deposit, '0xtxhash')]);
  });

  testWidgets("a service rebuilt while the live quote is out ends the confirmation: the swap's terms changed", (
    tester,
  ) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    final confirmation = SwapConfirmation(account: account);
    oneClick.hold = Completer<void>();

    final confirming = confirm(confirmation, ref, quote);
    await settle(tester);
    confirmation.serviceRebuilt();
    oneClick.hold!.complete();

    expect(await confirming, isA<SwapListingChanged>());
    expect(submission.asked, 0);
    expect(approval.reasons, isEmpty);
    expect(ref.read(activeSwapsProvider), isEmpty);

    // And the quote it was owed is not kept.
    oneClick.hold = null;
    await confirm(confirmation, ref, quote);
    expect(oneClick.created, hasLength(2));
  });

  testWidgets('a location that stops allowing swaps while the live quote is out sends nothing', (tester) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    oneClick.hold = Completer<void>();

    final confirming = confirm(SwapConfirmation(account: account), ref, quote);
    await settle(tester);
    config.revoke();
    oneClick.hold!.complete();

    expect(await confirming, isA<SwapNotAllowed>());
    expect(submission.asked, 0);
    expect(approval.reasons, isEmpty);
    expect(ref.read(activeSwapsProvider), isEmpty);
  });

  testWidgets('the location is asked afresh once approval is given: found not allowed, nothing is sent', (
    tester,
  ) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    await settle(tester);
    final readsBefore = config.service.reads;
    config.denyNextRefresh();

    final outcome = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(outcome, isA<SwapNotAllowed>());
    expect(approval.reasons, hasLength(1));
    expect(config.service.reads, readsBefore + 1);
    expect(submission.asked, 0);
    expect(oneClick.deposits, isEmpty);
    expect(ref.read(activeSwapsProvider), isEmpty);
  });

  testWidgets('approval that is not given sends nothing: approval is required', (tester) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    approval.answer = () async => ApprovalResult.declined;

    final outcome = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(outcome, isA<SwapApprovalRequired>());
    expect(submission.asked, 0);
    expect(oneClick.deposits, isEmpty);
    expect(ref.read(activeSwapsProvider), isEmpty);
  });

  testWidgets('a deposit the chain refuses is not reported to 1Click and no swap is followed', (tester) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    submission.refuses = true;

    final outcome = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(outcome, isA<SwapDepositFailed>());
    expect(submission.asked, 1);
    expect(oneClick.deposits, isEmpty);
    expect(ref.read(activeSwapsProvider), isEmpty);
    expect(settings.activeSwaps, isEmpty);
  });

  testWidgets('a live quote 1Click refuses says why, and sends nothing', (tester) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    oneClick.refusal = TimeoutException('slow');

    final outcome = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(outcome, isA<SwapQuoteRefused>());
    expect((outcome as SwapQuoteRefused).message, l10n.swapRequestTimedOut);
    expect(submission.asked, 0);
  });

  testWidgets('a review gone before approval is given sends nothing', (tester) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    final asked = Completer<void>();
    approval.answer = () async {
      await asked.future;
      return ApprovalResult.approved;
    };

    final confirming = confirm(SwapConfirmation(account: account), ref, quote);
    await settle(tester);
    expect(approval.reasons, hasLength(1));
    active = false;
    asked.complete();

    expect(await confirming, isA<SwapConfirmDropped>());
    expect(submission.asked, 0);
    expect(oneClick.deposits, isEmpty);
    expect(ref.read(activeSwapsProvider), isEmpty);
  });

  testWidgets('a review gone while the deposit is going out: the swap is followed all the same', (tester) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    submission.hold = Completer<void>();

    final confirming = confirm(SwapConfirmation(account: account), ref, quote);
    await settle(tester);
    expect(submission.asked, 1);
    active = false;
    submission.hold!.complete();
    await confirming;

    expect(oneClick.deposits, [(_deposit, '0xtxhash')]);
    expect(ref.read(activeSwapsProvider).single.depositTxHash, '0xtxhash');
    expect(settings.activeSwaps.single.depositTxHash, '0xtxhash');
  });

  testWidgets('a deposit that lands after a logout is not followed', (tester) async {
    final quote = _quote();
    final ref = await pumpReview(tester, quote);
    submission.hold = Completer<void>();

    final confirming = confirm(SwapConfirmation(account: account), ref, quote);
    await settle(tester);
    expect(submission.asked, 1);
    unawaited(ref.read(activeSwapsProvider.notifier).clearAll());
    submission.hold!.complete();

    expect(await confirming, isA<SwapConfirmDropped>());
    expect(submission.transfers.single.$1, _deposit);
    expect(ref.read(activeSwapsProvider), isEmpty);
    expect(settings.activeSwaps, isEmpty);
  });

  testWidgets('a deposit that lands after another swap started, or was put away, is followed alongside', (
    tester,
  ) async {
    final quote = _quote();
    final other = _running(account, 'qzother');
    final movedOn = <(String, void Function(ActiveSwapsNotifier), List<String>)>[
      ('started another', (swaps) => swaps.start(other), [other.id, _deposit]),
      ('put another away', (swaps) => unawaited(swaps.remove('qzearlier')), [_deposit]),
    ];
    for (final (name, moveOn, followed) in movedOn) {
      // Each round is a wallet of its own; the last one's config went with it.
      submission = _Submission()..hold = Completer<void>();
      settings = FakeSettingsService()..activeSwaps.add(_running(account, 'qzearlier'));
      config = _Config(_RemoteConfig());
      final ref = await pumpReview(tester, quote);

      final confirming = confirm(SwapConfirmation(account: account), ref, quote);
      await settle(tester);
      expect(submission.asked, 1, reason: name);
      moveOn(ref.read(activeSwapsProvider.notifier));
      submission.hold!.complete();

      expect(await confirming, isA<SwapConfirmed>(), reason: name);
      final ids = [for (final swap in ref.read(activeSwapsProvider)) swap.id];
      expect(ids.where((id) => id != 'qzearlier'), followed, reason: name);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('with as many swaps running as can be followed, confirming is refused before any live quote', (
    tester,
  ) async {
    final quote = _quote();
    for (var i = 0; i < ActiveSwapsNotifier.maxFollowed; i++) {
      settings.activeSwaps.add(_running(account, 'qzrunning$i'));
    }
    final ref = await pumpReview(tester, quote);

    final outcome = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(outcome, isA<SwapTooManyFollowed>());
    expect(oneClick.created, isEmpty);
    expect(submission.asked, 0);
    expect(ref.read(activeSwapsProvider), hasLength(ActiveSwapsNotifier.maxFollowed));
  });

  testWidgets('a confirmation under way holds the last slot against another', (tester) async {
    final quote = _quote();
    for (var i = 0; i < ActiveSwapsNotifier.maxFollowed - 1; i++) {
      settings.activeSwaps.add(_running(account, 'qzrunning$i'));
    }
    final ref = await pumpReview(tester, quote);
    oneClick.hold = Completer<void>();

    final first = confirm(SwapConfirmation(account: account), ref, quote);
    await settle(tester);
    final second = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(second, isA<SwapTooManyFollowed>());
    expect(oneClick.created, hasLength(1), reason: 'the second asked for no live quote');

    oneClick.hold!.complete();
    expect(await first, isA<SwapConfirmed>());
    expect(ref.read(activeSwapsProvider), hasLength(ActiveSwapsNotifier.maxFollowed));
  });

  testWidgets('a confirmation that ends with no swap gives its slot back', (tester) async {
    final quote = _quote();
    for (var i = 0; i < ActiveSwapsNotifier.maxFollowed - 1; i++) {
      settings.activeSwaps.add(_running(account, 'qzrunning$i'));
    }
    final ref = await pumpReview(tester, quote);
    final confirmation = SwapConfirmation(account: account);
    oneClick.refusal = TimeoutException('slow');

    expect(await confirm(confirmation, ref, quote), isA<SwapQuoteRefused>());
    oneClick.refusal = null;

    expect(await confirm(confirmation, ref, quote), isA<SwapConfirmed>());
    expect(ref.read(activeSwapsProvider), hasLength(ActiveSwapsNotifier.maxFollowed));
  });

  testWidgets('a swap into QTC sends no deposit of ours: it is followed as one made by hand', (tester) async {
    final quote = _quote(swapOut: false);
    final ref = await pumpRef(tester, overrides: overrides());

    final outcome = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(outcome, isA<SwapConfirmed>());
    expect(approval.reasons, isEmpty);
    expect(submission.asked, 0);
    expect(oneClick.deposits, isEmpty);
    final swap = ref.read(activeSwapsProvider).single;
    expect(swap.depositByHand, isTrue);
    expect(swap.depositTxHash, isNull);
    expect(swap.depositFee, isNull);
    expect(swap.order.depositAddress, _deposit);
  });

  testWidgets("in preflight a swap out's deposit is made by hand too: the app cannot sign on the stand-in's chain", (
    tester,
  ) async {
    final quote = _quote();
    final ref = await pumpRef(
      tester,
      overrides: overrides(
        preflight: const SwapPreflight(assetId: 'nep141:wrap.near', address: 'tester.near'),
      ),
    );

    final outcome = await confirm(SwapConfirmation(account: account), ref, quote);

    expect(outcome, isA<SwapConfirmed>());
    expect(submission.asked, 0);
    expect(ref.read(activeSwapsProvider).single.depositByHand, isTrue);
  });
}
