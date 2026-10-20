import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:ed25519_edwards/ed25519_edwards.dart' as ed25519;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/models/swap_preflight.dart';
import 'package:resonance_network_wallet/providers/active_swap_provider.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/remote_config_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/components/search_field.dart';
import 'package:resonance_network_wallet/v2/screens/settings/help_and_support_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/review_swap_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_progress_screen.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_providers.dart';
import 'package:resonance_network_wallet/v2/screens/swap/swap_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../extensions.dart';
import '../fakes.dart';

const _usdc = SwapToken(assetId: 'nep141:usdc.omft.near', symbol: 'USDC', network: 'ETH', decimals: 6, usdPrice: 1);
const _external = '0xa5f3c2b1d4e8a7c9f2b5e6d7c8b9a0f1e2d3c7b9';
final _deposit = 'qzdeposit${'y' * 40}';
const _qtc = SwapToken(
  assetId: 'nep141:qtc.omft.near',
  symbol: 'QTC',
  network: SwapToken.quantusNetwork,
  decimals: AppConstants.decimals,
  usdPrice: 0.1,
  isQuantus: true,
);
const _wnear = <String, dynamic>{
  'assetId': 'nep141:wrap.near',
  'decimals': 24,
  'blockchain': 'near',
  'symbol': 'wNEAR',
  'price': 5,
};
const _tester = 'tester.near';
const _preflight = SwapPreflight(assetId: 'nep141:wrap.near', address: _tester);
const _wnearStandIn = SwapToken(
  assetId: 'nep141:wrap.near',
  symbol: 'WNEAR',
  network: 'NEAR',
  decimals: 24,
  usdPrice: 5,
  isQuantus: true,
);
const _listedQtc = <String, dynamic>{
  'assetId': 'nep141:qtc.omft.near',
  'decimals': AppConstants.decimals,
  'blockchain': 'qtc',
  'symbol': 'QTC',
  'price': 0.1,
};
final _managerKeyPair = ed25519.generateKey();
final _managerPublicKey = OneClickQuoteSignature.encodeKey(Uint8List.fromList(_managerKeyPair.publicKey.bytes));
final _unit = BigInt.from(10).pow(AppConstants.decimals);

/// Remote config as the swap screens see it; [allowed] is the geo verdict.
class _SwapConfig extends RemoteConfigNotifier {
  _SwapConfig._(this.service) : super(service);

  factory _SwapConfig({bool allowed = true}) {
    final model = RemoteConfigModel.fromJson({'enableSwap': true, 'geoNearAllowed': allowed});
    return _SwapConfig._(FakeRemoteConfigService(model, remote: model));
  }

  final FakeRemoteConfigService service;

  void revokeGeo() => state = state.copyWith(geoNearAllowed: false);

  /// The next refresh, such as the one after authentication, finds the
  /// location no longer allowed.
  void denyNextRefresh() => service.remote = state.copyWith(geoNearAllowed: false);
}

/// 1Click stand-in: a dry quote pays [dryOut], a live one [liveOut] with a
/// deposit address, both with 1% slippage. An exact-output quote pays out what
/// it was asked for and costs [dryOut] or [liveOut] instead, 1% of it buffer. The token list has USDC on
/// Ethereum plus [listed], and answers [tokensStatus].
class _OneClick {
  final BigInt dryOut;
  final BigInt liveOut;
  final List<Map<String, dynamic>> listed;
  int tokensStatus;

  /// What the status endpoint answers, and with which HTTP status.
  String status = 'PENDING_DEPOSIT';
  int statusCode = 200;

  /// Holds every status answer until completed.
  Completer<void>? holdStatus;
  final requests = <http.Request>[];

  /// CoinGecko takes the request and never answers.
  bool coinGeckoHangs = false;

  /// Holds every live quote answer until completed.
  Completer<void>? holdLive;

  _OneClick({required this.dryOut, BigInt? liveOut, this.listed = const [_listedQtc], this.tokensStatus = 200})
    : liveOut = liveOut ?? dryOut;

  Iterable<http.Request> get liveQuotes =>
      requests.where((r) => r.url.path == '/v0/quote' && (jsonDecode(r.body) as Map)['dry'] == false);

  /// Holds every address save until completed.
  Completer<void>? holdSave;

  /// Holds every dry quote until completed.
  Completer<void>? holdQuote;

  SwapService service({bool preflight = false}) => _OneClickService(this, preflight: preflight);

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    if (coinGeckoHangs && request.url.host == Uri.parse(AppConstants.coingeckoEndpoint).host) {
      return Completer<http.Response>().future;
    }
    return switch (request.url.path) {
      '/v0/tokens' => http.Response(
        jsonEncode([
          {'assetId': _usdc.assetId, 'decimals': 6, 'blockchain': 'eth', 'symbol': 'USDC', 'price': 1},
          ...listed,
        ]),
        tokensStatus,
      ),
      '/v0/quote' => await _quote(request),
      '/v0/deposit/submit' => http.Response('{}', 200),
      '/v0/status' => await _status(),
      _ => http.Response('down', 503),
    };
  }

  Future<http.Response> _status() async {
    if (holdStatus != null) await holdStatus!.future;
    return http.Response(jsonEncode({'status': status}), statusCode);
  }

  Future<http.Response> _quote(http.Request request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    if (body['dry'] == false && holdLive != null) await holdLive!.future;
    if (body['dry'] == true && holdQuote != null) await holdQuote!.future;
    return http.Response(jsonEncode(_quoteJson(body)), 200);
  }

  Map<String, dynamic> _quoteJson(Map<String, dynamic> request) {
    final dry = request['dry'] as bool;
    final out = dry ? dryOut : liveOut;
    final buffered = '${out * BigInt.from(99) ~/ BigInt.from(100)}';
    final exactOutput = request['swapType'] == 'EXACT_OUTPUT';
    final response = {
      'quote': {
        if (!dry) 'depositAddress': _deposit,
        'amountIn': exactOutput ? '$out' : request['amount'],
        'minAmountIn': exactOutput ? buffered : request['amount'],
        'amountOut': exactOutput ? request['amount'] : '$out',
        'minAmountOut': exactOutput ? request['amount'] : buffered,
        'amountInUsd': '25.0',
        'amountOutUsd': '24.86',
        if (!dry) 'deadline': DateTime.now().toUtc().add(const Duration(minutes: 20)).toIso8601String(),
        'timeEstimate': 60,
      },
      'quoteRequest': {
        for (final k in const [
          'dry',
          'swapType',
          'originAsset',
          'destinationAsset',
          'amount',
          'slippageTolerance',
          'refundTo',
          'recipient',
          'deadline',
          'confidentiality',
        ])
          k: request[k],
        'appFees': [
          {'recipient': '2238fd089f1c92b206c218cd16b8676cb98964e0d50f8ab729c6396a81e07805', 'fee': 20},
        ],
      },
      'correlationId': dry ? 'dry' : 'live',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    final message = utf8.encode(OneClickQuoteSignature.hash(response));
    return {
      ...response,
      'signature': OneClickQuoteSignature.encodeKey(ed25519.sign(_managerKeyPair.privateKey, message)),
    };
  }
}

/// [SwapService] on the stand-in, whose address save waits on [_OneClick.holdSave].
class _OneClickService extends SwapService {
  final _OneClick oneClick;

  _OneClickService(this.oneClick, {required super.preflight})
    : super(
        endpoint: 'https://oneclick.test',
        client: MockClient(oneClick.handle),
        managerPublicKey: _managerPublicKey,
        quantusAssetId: preflight ? _preflight.assetId : null,
      );

  @override
  Future<void> saveAddress(String network, String address) async {
    await oneClick.holdSave?.future;
    await super.saveAddress(network, address);
  }
}

SwapQuote _quote({
  required SwapToken from,
  required SwapToken to,
  required BigInt amountIn,
  required BigInt amountOut,
  required String refund,
  required String recipient,
  String? depositAddress,
  String? depositMemo,
  DateTime? deadline,
}) => SwapQuote(
  fromToken: from,
  toToken: to,
  amountIn: amountIn,
  minAmountIn: amountIn,
  amountOut: amountOut,
  minAmountOut: amountOut * BigInt.from(99) ~/ BigInt.from(100),
  amountInUsd: 25,
  amountOutUsd: 24.86,
  slippageBps: 100,
  refundAddress: refund,
  recipient: recipient,
  deadline: deadline ?? clock.now().add(const Duration(minutes: 20)),
  timeEstimate: const Duration(minutes: 1),
  correlationId: 'c',
  signature: 'ed25519:sig',
  depositAddress: depositAddress,
  depositMemo: depositMemo,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l10n = lookupAppLocalizations(const Locale('en'));
  final account = makeAccount(1);
  final outQuote = _quote(
    from: _qtc,
    to: _usdc,
    amountIn: _unit * BigInt.from(250),
    amountOut: BigInt.from(24860000),
    refund: account.accountId,
    recipient: _external,
  );

  /// [outQuote] as 1Click reserved it: with the deposit address a status poll needs.
  final liveQuote = _quote(
    from: _qtc,
    to: _usdc,
    amountIn: _unit * BigInt.from(250),
    amountOut: BigInt.from(24860000),
    refund: account.accountId,
    recipient: _external,
    depositAddress: _deposit,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  /// [services] stands in for the remote config rebuilding the service.
  List<Override> overrides(
    SwapService service, {
    BigInt? balance,
    FakeTransactionSubmissionService? submission,
    StateProvider<SwapService>? services,
    _SwapConfig? config,
    SwapPreflight? preflight,
    FakeSettingsService? settings,
  }) => [
    settingsServiceProvider.overrideWithValue(settings ?? FakeSettingsService(activeAccount: RegularAccount(account))),
    isOnlineProvider.overrideWith((ref) => true),
    l10nProvider.overrideWithValue(l10n),
    remoteConfigProvider.overrideWith((ref) => config ?? _SwapConfig()),
    swapPreflightProvider.overrideWithValue(preflight),
    services == null
        ? swapServiceProvider.overrideWithValue(service)
        : swapServiceProvider.overrideWith((ref) => ref.watch(services)),
    effectiveBalanceProviderFamily.overrideWith((ref, _) => AsyncValue.data(balance ?? _unit * BigInt.from(1000))),
    swapDepositFeeProvider.overrideWith((ref, _) async => _unit ~/ BigInt.from(50)),
    balancesServiceProvider.overrideWithValue(FakeBalancesService()),
    transactionSubmissionServiceProvider.overrideWithValue(submission ?? FakeTransactionSubmissionService()),
  ];

  /// [order] as the swap the app follows, started [age] ago; the app sent the
  /// deposit of a swap out of QTC, a swap in waits for one from elsewhere.
  ActiveSwap activeSwap(SwapOrder order, {Duration age = const Duration(minutes: 1)}) {
    final swapOut = order.quote.fromToken.isQuantus;
    return ActiveSwap(
      order: order,
      accountId: account.accountId,
      accountName: account.name,
      startedAt: clock.now().subtract(age),
      depositByHand: !swapOut,
      depositTxHash: swapOut ? '0xtxhash' : null,
      depositFee: swapOut ? _unit ~/ BigInt.from(50) : null,
    );
  }

  /// Settings with [swap] kept on the device, as a restart finds it.
  FakeSettingsService settingsWith(ActiveSwap swap) =>
      FakeSettingsService(activeAccount: RegularAccount(account), activeSwap: swap);

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(SwapProgressScreen)));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder svg(String asset) =>
      find.byWidgetPredicate((w) => w is SvgPicture && (w.bytesLoader as SvgAssetLoader).assetName == asset);

  /// Turns the form around to swap out of QTC; it opens as a purchase. The
  /// arrows between the sides come after the dot by the typed side's USD value.
  Future<void> swapOut(WidgetTester tester) async {
    await tester.tap(svg('assets/v2/swap_arrows_down_up.svg').last);
    await tester.pump();
  }

  QuantusButton button(WidgetTester tester, String label) =>
      tester.widget<QuantusButton>(find.ancestor(of: find.text(label), matching: find.byType(QuantusButton)));

  /// A phone-sized view, so that a tall sheet's button is on screen.
  void phoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('SwapScreen', () {
    testWidgets('opens as a purchase of QTC and flips direction with the arrows', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.from(24860000));
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(oneClick.service(), balance: _unit * BigInt.from(100)),
      );
      await settle(tester);

      expect(find.text('FROM'), findsOneWidget);
      expect(find.text(account.name), findsOneWidget);
      expect(find.text(l10n.swapExternalWallet), findsOneWidget);
      final fromHeader = tester.getTopLeft(find.text('FROM')).dy;
      expect(tester.getTopLeft(find.text(l10n.swapExternalWallet)).dy, closeTo(fromHeader, 4));
      expect(button(tester, l10n.swapAddRefundAddress).isDisabled, isFalse);

      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      expect(button(tester, l10n.swapAddRefundAddress).isDisabled, isFalse);

      await swapOut(tester);
      expect(button(tester, l10n.swapAddRecipientAddress).isDisabled, isFalse);
      expect(tester.getTopLeft(find.text(account.name)).dy, closeTo(fromHeader, 4));

      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump();
      expect(button(tester, l10n.sendLogicInsufficientBalance).isDisabled, isTrue);

      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      expect(button(tester, l10n.swapAddRecipientAddress).isDisabled, isFalse);
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('a swap out shows the most it can put in, less the fee and the existential deposit; a tap types it', (
      tester,
    ) async {
      final oneClick = _OneClick(dryOut: BigInt.from(24860000));
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(oneClick.service(), balance: _unit * BigInt.from(100)),
      );
      await settle(tester);
      final max = find.text('${l10n.sendInputAmountMax} 99.979 QTC');
      expect(max, findsNothing);

      await swapOut(tester);
      await settle(tester);
      expect(max, findsOneWidget);
      await tester.tap(max);
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '99.979');
      expect(button(tester, l10n.swapAddRecipientAddress).isDisabled, isFalse);

      await tester.enterText(find.byType(TextField), '99.98');
      await tester.pump();
      expect(button(tester, l10n.sendLogicInsufficientBalance).isDisabled, isTrue);

      await tester.tap(find.text('9.998'));
      await tester.pump();
      expect(tester.getTopLeft(find.byType(TextField)).dy, greaterThan(tester.getTopLeft(find.text('TO')).dy));
      await tester.tap(max);
      await tester.pump();
      expect(tester.getTopLeft(find.byType(TextField)).dy, lessThan(tester.getTopLeft(find.text('TO')).dy));
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '99.979');
      expect(button(tester, l10n.swapAddRecipientAddress).isDisabled, isFalse);

      await swapOut(tester);
      expect(max, findsNothing);
    });

    testWidgets('while the amount is typed, chips put a share of the most the account can pay in', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.from(24860000));
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(oneClick.service(), balance: _unit * BigInt.from(100)),
      );
      await settle(tester);
      await swapOut(tester);
      await settle(tester);
      final half = find.text(l10n.commonPercent('50'));
      expect(half, findsNothing);

      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      expect(half, findsOneWidget);
      await tester.tap(half);
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '49.9895');
      expect(half, findsOneWidget);

      await tester.tap(find.text(l10n.sendInputAmountMax));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '99.979');

      await swapOut(tester);
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      expect(half, findsNothing);
    });

    testWidgets('the token picker opens two thirds high, lists every token and filters them by search', (tester) async {
      final oneClick = _OneClick(
        dryOut: BigInt.one,
        listed: [
          _listedQtc,
          {'assetId': 'nep141:sol-usdc.omft.near', 'decimals': 6, 'blockchain': 'sol', 'symbol': 'USDC', 'price': 1},
          for (var i = 1; i <= 12; i++)
            {'assetId': 'nep141:coin$i.near', 'decimals': 18, 'blockchain': 'near', 'symbol': 'coin$i', 'price': 1},
        ],
      );
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);

      await tester.tap(find.text('USDC'));
      await settle(tester);
      expect(find.text(l10n.swapTokenPickerPayWith), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(BottomSheetContainer)).dy,
        tester.getSize(find.byType(MaterialApp)).height / 3,
      );

      final search = find.descendant(of: find.byType(SearchField), matching: find.byType(TextField));
      await tester.enterText(search, 'coin12');
      await tester.pump();
      expect(find.text('COIN12'), findsOneWidget);
      expect(find.text('COIN1'), findsNothing);

      await tester.enterText(search, 'usdc');
      await tester.pump();
      expect(find.text('Solana'), findsOneWidget);
      expect(find.text('Ethereum'), findsNWidgets(2));

      await tester.enterText(search, 'solana');
      await tester.pump();
      expect(find.text('Solana'), findsOneWidget);
      expect(find.text('Ethereum'), findsOneWidget);
      expect(find.text('COIN12'), findsNothing);

      await tester.enterText(search, 'nothing');
      await tester.pump();
      expect(find.text(l10n.swapTokenPickerNoMatch), findsOneWidget);

      await tester.enterText(search, 'coin12');
      await tester.pump();
      await tester.tap(find.text('COIN12'));
      await settle(tester);
      expect(find.byType(BottomSheetContainer), findsNothing);

      await tester.tap(find.text('QTC'));
      await settle(tester);
      expect(find.text(l10n.swapTokenPickerReceive), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);
      expect(find.byType(BottomSheetContainer), findsNothing);
      expect(find.text(l10n.swapAddRefundAddress), findsOneWidget);
      expect(find.text('COIN12'), findsOneWidget);
    });

    testWidgets('quotes QTC under the asset id 1Click lists it with', (tester) async {
      const listedId = 'nep141:quantus.omft.near';
      final oneClick = _OneClick(
        dryOut: BigInt.from(1000000),
        listed: [
          {..._listedQtc, 'assetId': listedId},
        ],
      );
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);

      await swapOut(tester);
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      await tester.tap(find.text(l10n.swapAddRecipientAddress));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, _external);
      await tester.pump();
      await tester.tap(find.text(l10n.swapContinue));
      await settle(tester);

      final quote = oneClick.requests.singleWhere((r) => r.url.path == '/v0/quote');
      expect((jsonDecode(quote.body) as Map)['originAsset'], listedId);
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
    });

    testWidgets('an address given before the amount waits on the form, and Review Swap then quotes', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.from(1000000));
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);

      await tester.tap(find.text(l10n.swapAddRefundAddress));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, _external);
      await tester.pump();
      await tester.tap(find.text(l10n.swapContinue));
      await settle(tester);

      expect(oneClick.requests.where((r) => r.url.path == '/v0/quote'), isEmpty);
      expect(find.text(l10n.swapRefundTo.toUpperCase()), findsOneWidget);
      expect(find.text(AddressFormattingService.formatAddress(_external)), findsOneWidget);
      expect(button(tester, l10n.swapReviewTitle).isDisabled, isTrue);

      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      expect(button(tester, l10n.swapReviewTitle).isDisabled, isFalse);
      await tester.tap(find.text(l10n.swapReviewTitle));
      await settle(tester);

      final quote = jsonDecode(oneClick.requests.singleWhere((r) => r.url.path == '/v0/quote').body) as Map;
      expect(quote['refundTo'], _external);
      expect(quote['recipient'], account.accountId);
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
    });

    testWidgets('reloads the listing when the remote asset id changes while the screen is open', (tester) async {
      const otherId = 'nep141:quantus.omft.near';
      final before = _OneClick(dryOut: BigInt.from(1000000));
      final after = _OneClick(
        dryOut: BigInt.from(1000000),
        listed: [
          {..._listedQtc, 'assetId': otherId},
        ],
      );
      final services = StateProvider<SwapService>((_) => before.service());
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(before.service(), services: services),
      );
      await settle(tester);
      expect(find.text('FROM'), findsOneWidget);

      ProviderScope.containerOf(tester.element(find.byType(SwapScreen))).read(services.notifier).state = after
          .service();
      await settle(tester);

      await swapOut(tester);
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      await tester.tap(find.text(l10n.swapAddRecipientAddress));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, _external);
      await tester.pump();
      await tester.tap(find.text(l10n.swapContinue));
      await settle(tester);

      final quote = after.requests.singleWhere((r) => r.url.path == '/v0/quote');
      expect((jsonDecode(quote.body) as Map)['originAsset'], otherId);
      expect(before.requests.where((r) => r.url.path == '/v0/quote'), isEmpty);
    });

    testWidgets('an address sheet open across the asset id change cannot quote the old QTC', (tester) async {
      final before = _OneClick(dryOut: BigInt.from(1000000));
      final after = _OneClick(
        dryOut: BigInt.from(1000000),
        listed: [
          {..._listedQtc, 'assetId': 'nep141:quantus.omft.near'},
        ],
      );
      final services = StateProvider<SwapService>((_) => before.service());
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(before.service(), services: services),
      );
      await settle(tester);
      await swapOut(tester);
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      await tester.tap(find.text(l10n.swapAddRecipientAddress));
      await settle(tester);

      ProviderScope.containerOf(tester.element(find.byType(SwapScreen))).read(services.notifier).state = after
          .service();
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, _external);
      await tester.pump();
      await tester.tap(find.text(l10n.swapContinue));
      await settle(tester);

      expect([...before.requests, ...after.requests].where((r) => r.url.path == '/v0/quote'), isEmpty);
      expect(find.byType(ReviewSwapScreen), findsNothing);
      expect(find.text(l10n.swapContinue), findsNothing);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('shows swaps as unavailable while 1Click does not list QTC, or lists it without a price', (
      tester,
    ) async {
      for (final listed in [
        <Map<String, dynamic>>[],
        [
          {..._listedQtc, 'price': 0},
        ],
      ]) {
        final oneClick = _OneClick(dryOut: BigInt.one, listed: listed);
        await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
        await settle(tester);

        expect(find.text(l10n.swapDisabledTitle), findsOneWidget);
        expect(find.text(l10n.swapUnavailableTitle), findsNothing);
        expect(find.text(l10n.commonTryAgain), findsNothing);
        expect(find.text('FROM'), findsNothing);
        expect(find.text(l10n.swapAddRecipientAddress), findsNothing);
      }
    });

    testWidgets('opens the form in 1Click order once a CoinGecko request that never answers times out', (tester) async {
      final oneClick = _OneClick(
        dryOut: BigInt.one,
        listed: [
          _listedQtc,
          {..._wnear, 'coingeckoId': 'wrapped-near'},
        ],
      )..coinGeckoHangs = true;
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);
      expect(oneClick.requests.where((r) => r.url.path == '/api/v3/coins/markets'), hasLength(1));
      expect(find.text('FROM'), findsNothing);

      await tester.pump(CoinGeckoService.requestTimeout);
      await settle(tester);
      expect(find.text('FROM'), findsOneWidget);
      expect(find.text('USDC'), findsOneWidget);
    });

    testWidgets('shows swaps as unavailable with a retry while 1Click cannot be reached', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.one, tokensStatus: 503);
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);

      expect(find.text(l10n.swapUnavailableTitle), findsOneWidget);
      expect(find.text(l10n.swapUnavailableUnreachable), findsOneWidget);
      expect(find.text('FROM'), findsNothing);

      oneClick.tokensStatus = 200;
      await tester.tap(find.text(l10n.commonTryAgain));
      await settle(tester);

      expect(find.text(l10n.swapUnavailableTitle), findsNothing);
      expect(find.text(l10n.swapDisabledTitle), findsNothing);
      expect(find.text('FROM'), findsOneWidget);
    });
  });

  group('quoting', () {
    for (final swapOutForm in [true, false]) {
      testWidgets(
        'swapping ${swapOutForm ? 'out' : 'in'}, a quote out takes no taps and opens nothing once the form moved on',
        (tester) async {
          final oneClick = _OneClick(dryOut: BigInt.from(24860000))..holdQuote = Completer<void>();
          await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
          await settle(tester);
          if (swapOutForm) await swapOut(tester);
          final addAddress = swapOutForm ? l10n.swapAddRecipientAddress : l10n.swapAddRefundAddress;
          await tester.enterText(find.byType(TextField), '10');
          await tester.pump();
          await tester.tap(find.text(addAddress));
          await settle(tester);
          await tester.enterText(find.byType(TextField).last, _external);
          await tester.pump();
          await tester.tap(find.text(l10n.swapContinue));
          await settle(tester);
          expect(find.byType(BottomSheetContainer), findsNothing);
          Iterable<http.Request> quotes() => oneClick.requests.where((r) => r.url.path == '/v0/quote');
          expect(quotes(), hasLength(1));

          await tester.tap(find.text(AddressFormattingService.formatAddress(_external)), warnIfMissed: false);
          await settle(tester);
          expect(find.byType(BottomSheetContainer), findsNothing);
          expect(quotes(), hasLength(1));

          await tester.enterText(find.byType(TextField), '20');
          await tester.pump();
          oneClick.holdQuote!.complete();
          await settle(tester);
          expect(find.byType(ReviewSwapScreen), findsNothing);

          oneClick.holdQuote = null;
          await tester.tap(find.text(l10n.swapReviewTitle));
          await settle(tester);
          expect(find.byType(ReviewSwapScreen), findsOneWidget);
          expect(quotes(), hasLength(2));
        },
      );
    }
  });

  group('address sheet', () {
    /// Opens the recipient sheet for a swap out with an amount typed, fills
    /// the address, asks to keep it and taps Continue, which [oneClick] holds.
    Future<void> continueWithHeldSave(WidgetTester tester, _OneClick oneClick) async {
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);
      await swapOut(tester);
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      await tester.tap(find.text(l10n.swapAddRecipientAddress));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, _external);
      await tester.pump();
      await tester.tap(find.text(l10n.swapSaveAddress));
      await tester.pump();
      await tester.tap(find.text(l10n.swapContinue));
      await tester.pump();
    }

    testWidgets('Continue is busy while the address is kept, and pops the sheet once', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.from(24860000))..holdSave = Completer<void>();
      await continueWithHeldSave(tester, oneClick);
      expect(find.text(l10n.swapContinue), findsNothing);
      expect(find.descendant(of: find.byType(BottomSheetContainer), matching: find.byType(Loader)), findsOneWidget);

      oneClick.holdSave!.complete();
      await settle(tester);
      expect(find.byType(BottomSheetContainer), findsNothing);
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
      expect(find.byType(SwapScreen, skipOffstage: false), findsOneWidget);
    });

    testWidgets('a sheet cancelled while its address is kept pops nothing when the save completes', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.from(24860000))..holdSave = Completer<void>();
      await continueWithHeldSave(tester, oneClick);
      await tester.tap(find.text(l10n.commonCancel));
      await settle(tester);
      expect(find.byType(BottomSheetContainer), findsNothing);

      oneClick.holdSave!.complete();
      await settle(tester);
      expect(find.byType(SwapScreen), findsOneWidget);
      expect(find.byType(ReviewSwapScreen), findsNothing);
      expect(find.text(l10n.swapAddRecipientAddress), findsOneWidget);
    });
  });

  group('slippage', () {
    testWidgets('the picked tolerance shows on the form and goes into the quote', (tester) async {
      phoneView(tester);
      final oneClick = _OneClick(dryOut: BigInt.from(24860000));
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);
      expect(find.text(l10n.swapSlippageLabel('1')), findsOneWidget);

      await tester.tap(svg('assets/v2/swap_pencil.svg'));
      await settle(tester);
      await tester.tap(find.text('2%'));
      await tester.pump();
      expect(find.text(l10n.swapSlippageLabel('1')), findsOneWidget);
      await tester.tap(find.text(l10n.commonSave));
      await settle(tester);
      expect(find.text(l10n.swapSlippageLabel('2')), findsOneWidget);

      await swapOut(tester);
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      await tester.tap(find.text(l10n.swapAddRecipientAddress));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, _external);
      await tester.pump();
      await tester.tap(find.text(l10n.swapContinue));
      await settle(tester);

      final quote = oneClick.requests.singleWhere((r) => r.url.path == '/v0/quote');
      expect((jsonDecode(quote.body) as Map)['slippageTolerance'], 200);
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
    });
  });

  group('exact output', () {
    testWidgets('typing what arrives prices the payment and quotes that exact amount out', (tester) async {
      final oneClick = _OneClick(dryOut: _unit * BigInt.from(202));
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);
      await swapOut(tester);

      await tester.tap(find.text('0').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '20');
      await tester.pump();
      expect(find.text('200'), findsOneWidget);

      await tester.tap(find.text(l10n.swapAddRecipientAddress));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, _external);
      await tester.pump();
      await tester.tap(find.text(l10n.swapContinue));
      await settle(tester);

      final quote = jsonDecode(oneClick.requests.singleWhere((r) => r.url.path == '/v0/quote').body) as Map;
      expect(quote['swapType'], 'EXACT_OUTPUT');
      expect(quote['originAsset'], _listedQtc['assetId']);
      expect(quote['amount'], '20000000');
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
      expect(find.text(l10n.commonAmountBalance('202', 'QTC')), findsOneWidget);
      expect(find.text(l10n.swapReviewUnusedRefunded), findsOneWidget);
    });

    testWidgets('tapping the paying side again types there, starting from its estimate', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.one);
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);
      await swapOut(tester);
      await tester.tap(find.text('0').last);
      await tester.pump();
      await tester.enterText(find.byType(TextField), '20');
      await tester.pump();

      await tester.tap(find.text('200'));
      await tester.pump();
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '200');
      expect(field.controller!.selection, const TextSelection(baseOffset: 0, extentOffset: 3));
      expect(find.text('20'), findsOneWidget);
    });
  });

  group('custom slippage', () {
    testWidgets('takes any tolerance up to 99% and quotes with it', (tester) async {
      phoneView(tester);
      final oneClick = _OneClick(dryOut: BigInt.from(24860000));
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);

      await tester.tap(svg('assets/v2/swap_pencil.svg'));
      await settle(tester);
      expect(tester.getSize(find.text(l10n.swapSlippageCustom)).height, tester.getSize(find.text('1%')).height);
      await tester.tap(find.text(l10n.swapSlippageCustom));
      await settle(tester);
      final field = find.descendant(of: find.byType(BottomSheetContainer), matching: find.byType(TextField));

      await tester.enterText(field, '99.5');
      await tester.pump();
      expect(find.text(l10n.swapSlippageCustomMax('99')), findsOneWidget);
      expect(button(tester, l10n.commonSave).isDisabled, isTrue);

      await tester.enterText(field, '7.5');
      await tester.pump();
      expect(find.text(l10n.swapSlippageCustomMax('99')), findsNothing);
      await tester.tap(find.text(l10n.commonSave));
      await settle(tester);
      expect(find.text(l10n.swapSlippageLabel('7.5')), findsOneWidget);

      await tester.tap(svg('assets/v2/swap_pencil.svg'));
      await settle(tester);
      expect(tester.widget<TextField>(field).controller!.text, '7.5');
      await tester.tap(find.byIcon(Icons.close));
      await settle(tester);

      await swapOut(tester);
      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      await tester.tap(find.text(l10n.swapAddRecipientAddress));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, _external);
      await tester.pump();
      await tester.tap(find.text(l10n.swapContinue));
      await settle(tester);
      final quote = oneClick.requests.singleWhere((r) => r.url.path == '/v0/quote');
      expect((jsonDecode(quote.body) as Map)['slippageTolerance'], 750);
    });
  });

  group('ReviewSwapScreen', () {
    testWidgets('a swap out sends the QTC to the live deposit address and follows the swap', (tester) async {
      final oneClick = _OneClick(dryOut: outQuote.amountOut);
      final submission = FakeTransactionSubmissionService();
      final settings = FakeSettingsService(activeAccount: RegularAccount(account));
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: outQuote),
        overrides: overrides(oneClick.service(), submission: submission, settings: settings),
      );
      await settle(tester);

      expect(find.text('RECIPIENT'), findsOneWidget);
      expect(find.text('NETWORK FEE'), findsOneWidget);
      expect(find.text('0.02 QTC'), findsOneWidget);
      expect(find.text('24.6114 USDC'), findsOneWidget);

      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);

      expect(submission.transfers, [(_deposit, outQuote.amountIn, _unit ~/ BigInt.from(50))]);
      final submit = oneClick.requests.singleWhere((r) => r.url.path == '/v0/deposit/submit');
      expect(jsonDecode(submit.body), {'txHash': '0xtxhash', 'depositAddress': _deposit});
      expect(find.text(l10n.swapInProgressTitle), findsOneWidget);
      expect(find.text(l10n.swapStepSent('QTC')), findsOneWidget);

      final swap = containerOf(tester).read(activeSwapProvider)!;
      expect(swap.depositTxHash, '0xtxhash');
      expect(swap.depositByHand, isFalse);
      expect(swap.order.depositAddress, _deposit);
      final kept = settings.activeSwap!;
      expect(kept.order.depositAddress, _deposit);
      expect(kept.depositFee, _unit ~/ BigInt.from(50));
    });

    /// The review pushed over a page, so it can be left while a deposit is
    /// held in flight.
    Future<ProviderContainer> openReview(WidgetTester tester, List<Override> overrides) async {
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReviewSwapScreen(account: account, quote: outQuote),
              ),
            ),
            child: const Text('open'),
          ),
        ),
        overrides: overrides,
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      return ProviderScope.containerOf(tester.element(find.byType(ReviewSwapScreen)));
    }

    Future<void> confirmAndLeave(WidgetTester tester) async {
      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);
      await tester.tap(find.text(l10n.commonCancel));
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(ReviewSwapScreen), findsNothing);
    }

    testWidgets('a deposit still in flight when the review is left is followed once it is out', (tester) async {
      final oneClick = _OneClick(dryOut: outQuote.amountOut);
      final submission = FakeTransactionSubmissionService()..holdTransfer = Completer<void>();
      final settings = FakeSettingsService(activeAccount: RegularAccount(account));
      final container = await openReview(
        tester,
        overrides(oneClick.service(), submission: submission, settings: settings),
      );
      await confirmAndLeave(tester);

      submission.holdTransfer!.complete();
      await settle(tester);
      expect(submission.transfers.single.$1, _deposit);
      expect(oneClick.requests.where((r) => r.url.path == '/v0/deposit/submit'), hasLength(1));
      expect(container.read(activeSwapProvider)?.depositTxHash, '0xtxhash');
      expect(settings.activeSwap?.depositTxHash, '0xtxhash');
    });

    testWidgets('a deposit that lands after the wallet logged out or moved on is not followed', (tester) async {
      final other = activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.processing));
      final movedOn = <(String, Future<void> Function(ActiveSwapNotifier), ActiveSwap?)>[
        ('logged out', (swaps) => swaps.clear(), null),
        ('started another', (swaps) async => swaps.start(other), other),
      ];
      for (final (name, moveOn, kept) in movedOn) {
        final oneClick = _OneClick(dryOut: outQuote.amountOut);
        final submission = FakeTransactionSubmissionService()..holdTransfer = Completer<void>();
        final settings = FakeSettingsService(activeAccount: RegularAccount(account));
        final container = await openReview(
          tester,
          overrides(oneClick.service(), submission: submission, settings: settings),
        );
        await confirmAndLeave(tester);
        await moveOn(container.read(activeSwapProvider.notifier));

        submission.holdTransfer!.complete();
        await settle(tester);
        final asKept = kept == null ? isNull : same(kept);
        expect(submission.transfers.single.$1, _deposit, reason: name);
        expect(oneClick.requests.where((r) => r.url.path == '/v0/deposit/submit'), hasLength(1), reason: name);
        expect(container.read(activeSwapProvider), asKept, reason: name);
        expect(settings.activeSwap, asKept, reason: name);
        expect(find.byType(SwapProgressScreen), findsNothing, reason: name);
      }
    });

    testWidgets('a worse live quote replaces the terms and needs a second confirm', (tester) async {
      final oneClick = _OneClick(dryOut: outQuote.amountOut, liveOut: BigInt.from(20000000));
      final submission = FakeTransactionSubmissionService();
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: outQuote),
        overrides: overrides(oneClick.service(), submission: submission),
      );
      await settle(tester);

      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);

      expect(submission.transfers, isEmpty);
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
      expect(find.text('19.8 USDC'), findsOneWidget);

      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);

      expect(submission.transfers.single.$1, _deposit);
      expect(oneClick.liveQuotes, hasLength(1));
      await tester.pump(const Duration(seconds: 3));
    });

    testWidgets('a review open across the asset id change neither reuses its live order nor sends', (tester) async {
      final before = _OneClick(dryOut: outQuote.amountOut, liveOut: BigInt.from(20000000));
      final after = _OneClick(
        dryOut: outQuote.amountOut,
        listed: [
          {..._listedQtc, 'assetId': 'nep141:quantus.omft.near'},
        ],
      );
      final services = StateProvider<SwapService>((_) => before.service());
      final submission = FakeTransactionSubmissionService();
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: outQuote),
        overrides: overrides(before.service(), submission: submission, services: services),
      );
      await settle(tester);
      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);
      expect(find.text('19.8 USDC'), findsOneWidget);
      expect(before.liveQuotes, hasLength(1));

      ProviderScope.containerOf(tester.element(find.byType(ReviewSwapScreen))).read(services.notifier).state = after
          .service();
      await settle(tester);
      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);

      expect(submission.transfers, isEmpty);
      expect(after.liveQuotes, isEmpty);
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a live quote still pending when the asset id changes is discarded and nothing is sent', (
      tester,
    ) async {
      final before = _OneClick(dryOut: outQuote.amountOut)..holdLive = Completer<void>();
      final after = _OneClick(
        dryOut: outQuote.amountOut,
        listed: [
          {..._listedQtc, 'assetId': 'nep141:quantus.omft.near'},
        ],
      );
      final services = StateProvider<SwapService>((_) => before.service());
      final submission = FakeTransactionSubmissionService();
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: outQuote),
        overrides: overrides(before.service(), submission: submission, services: services),
      );
      await settle(tester);
      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);
      expect(before.liveQuotes, hasLength(1));

      ProviderScope.containerOf(tester.element(find.byType(ReviewSwapScreen))).read(services.notifier).state = after
          .service();
      await settle(tester);
      before.holdLive!.complete();
      await settle(tester);

      expect(submission.transfers, isEmpty);
      expect(after.liveQuotes, isEmpty);
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('shows every digit of the amount that will be sent', (tester) async {
      final oneClick = _OneClick(dryOut: outQuote.amountOut);
      final quote = _quote(
        from: _qtc,
        to: _usdc,
        amountIn: _unit + BigInt.from(90000000),
        amountOut: outQuote.amountOut,
        refund: account.accountId,
        recipient: _external,
      );
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: quote),
        overrides: overrides(oneClick.service()),
      );
      await settle(tester);

      expect(find.text('1.00009 QTC'), findsOneWidget);
    });

    testWidgets('blocks a swap out the balance cannot cover with its fee', (tester) async {
      final oneClick = _OneClick(dryOut: outQuote.amountOut);
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: outQuote),
        overrides: overrides(oneClick.service(), balance: outQuote.amountIn),
      );
      await settle(tester);

      expect(find.text(l10n.swapReviewInsufficient('QTC')), findsOneWidget);
      expect(button(tester, l10n.swapReviewConfirm).isDisabled, isTrue);
    });
  });

  group('geo gate', () {
    testWidgets('where NEAR Intents is not allowed the swap screen says swap is disabled', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.one);
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(oneClick.service(), config: _SwapConfig(allowed: false)),
      );
      await settle(tester);

      expect(find.text(l10n.swapDisabledTitle), findsOneWidget);
      expect(find.text('FROM'), findsNothing);
      expect(find.text(l10n.commonTryAgain), findsNothing);
    });

    testWidgets('a verdict revoked while the form is open takes the form away', (tester) async {
      final config = _SwapConfig();
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(_OneClick(dryOut: BigInt.one).service(), config: config),
      );
      await settle(tester);
      expect(find.text('FROM'), findsOneWidget);

      config.revokeGeo();
      await tester.pump();

      expect(find.text(l10n.swapDisabledTitle), findsOneWidget);
      expect(find.text('FROM'), findsNothing);
    });

    testWidgets('a confirmation awaiting its live quote stops when the location allowance is revoked', (tester) async {
      final oneClick = _OneClick(dryOut: outQuote.amountOut)..holdLive = Completer<void>();
      final config = _SwapConfig();
      final submission = FakeTransactionSubmissionService();
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: outQuote),
        overrides: overrides(oneClick.service(), submission: submission, config: config),
      );
      await settle(tester);
      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);
      expect(oneClick.liveQuotes, hasLength(1));

      config.revokeGeo();
      await tester.pump();
      oneClick.holdLive!.complete();
      await settle(tester);

      expect(submission.transfers, isEmpty);
      expect(oneClick.requests.where((r) => r.url.path == '/v0/deposit/submit'), isEmpty);
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
      expect(button(tester, l10n.swapReviewConfirm).isDisabled, isTrue);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets('a location found blocked by the refresh after authentication sends nothing', (tester) async {
      final oneClick = _OneClick(dryOut: outQuote.amountOut);
      final config = _SwapConfig();
      final submission = FakeTransactionSubmissionService();
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: outQuote),
        overrides: overrides(oneClick.service(), submission: submission, config: config),
      );
      await settle(tester);
      expect(button(tester, l10n.swapReviewConfirm).isDisabled, isFalse);

      config.denyNextRefresh();
      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);

      expect(oneClick.liveQuotes, hasLength(1));
      expect(submission.transfers, isEmpty);
      expect(oneClick.requests.where((r) => r.url.path == '/v0/deposit/submit'), isEmpty);
      expect(find.byType(ReviewSwapScreen), findsOneWidget);
      expect(button(tester, l10n.swapReviewConfirm).isDisabled, isTrue);
      await tester.pump(const Duration(seconds: 10));
    });

    testWidgets(
      'where NEAR Intents is not allowed a review cannot be confirmed and a failed swap cannot start another',
      (tester) async {
        await tester.pumpApp(
          ReviewSwapScreen(account: account, quote: outQuote),
          overrides: overrides(_OneClick(dryOut: outQuote.amountOut).service(), config: _SwapConfig(allowed: false)),
        );
        await settle(tester);
        expect(button(tester, l10n.swapReviewConfirm).isDisabled, isTrue);
        expect(find.text(l10n.swapDisabledTitle), findsOneWidget);

        await tester.pumpApp(
          SwapProgressScreen(account: account),
          overrides: overrides(
            _OneClick(dryOut: BigInt.one).service(),
            config: _SwapConfig(allowed: false),
            settings: settingsWith(activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.refunded))),
          ),
        );
        await settle(tester);
        expect(find.text('REFUNDED'), findsOneWidget);
        expect(button(tester, l10n.swapStartNew).isDisabled, isTrue);

        final container = containerOf(tester);
        await tester.tap(find.byType(AppBackButton));
        await settle(tester);
        expect(container.read(activeSwapProvider), isNull);
      },
    );
  });

  group('preflight', () {
    Future<Map<String, dynamic>> quoteWith(WidgetTester tester, _OneClick oneClick, String cta) async {
      await tester.enterText(find.byType(TextField), '1');
      await tester.pump();
      await tester.tap(find.text(cta));
      await settle(tester);
      await tester.enterText(find.byType(TextField).last, _external);
      await tester.pump();
      await tester.tap(find.text(l10n.swapContinue));
      await settle(tester);
      return jsonDecode(oneClick.requests.singleWhere((r) => r.url.path == '/v0/quote').body) as Map<String, dynamic>;
    }

    testWidgets('stands the configured asset in for QTC, with the tester address on its side', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.from(1000000), listed: [_wnear]);
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(oneClick.service(preflight: true), preflight: _preflight),
      );
      await settle(tester);

      expect(find.text(l10n.swapPreflightBanner('WNEAR', 'NEAR')), findsOneWidget);
      expect(find.text('WNEAR'), findsOneWidget);
      expect(find.text('QTC'), findsNothing);

      await swapOut(tester);
      final out = await quoteWith(tester, oneClick, l10n.swapAddRecipientAddress);
      expect(out['originAsset'], _preflight.assetId);
      expect(out['destinationAsset'], _usdc.assetId);
      expect(out['amount'], BigInt.from(10).pow(24).toString());
      expect(out['refundTo'], _tester);
      expect(out['recipient'], _external);
    });

    testWidgets('a swap in pays out to the tester address', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.from(10).pow(23), listed: [_wnear]);
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(oneClick.service(preflight: true), preflight: _preflight),
      );
      await settle(tester);

      final into = await quoteWith(tester, oneClick, l10n.swapAddRefundAddress);
      expect(into['originAsset'], _usdc.assetId);
      expect(into['destinationAsset'], _preflight.assetId);
      expect(into['refundTo'], _external);
      expect(into['recipient'], _tester);
    });

    testWidgets('a swap out shows the deposit address instead of sending', (tester) async {
      final quote = _quote(
        from: _wnearStandIn,
        to: _usdc,
        amountIn: BigInt.from(10).pow(24),
        amountOut: BigInt.from(4900000),
        refund: _tester,
        recipient: _external,
      );
      final oneClick = _OneClick(dryOut: quote.amountOut, listed: [_wnear]);
      final submission = FakeTransactionSubmissionService();
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: quote),
        overrides: overrides(oneClick.service(preflight: true), submission: submission, preflight: _preflight),
      );
      await settle(tester);
      expect(find.text('NETWORK FEE'), findsNothing);

      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);

      expect(submission.transfers, isEmpty);
      expect(oneClick.requests.where((r) => r.url.path == '/v0/deposit/submit'), isEmpty);
      expect(find.text(_deposit), findsOneWidget);
      expect(find.text(l10n.swapDepositOnly('WNEAR', 'NEAR')), findsOneWidget);
    });
  });

  group('SwapProgressScreen', () {
    /// Opens the screen on [swap] as kept on the device, with 1Click answering [oneClick].
    Future<FakeSettingsService> pumpSwap(WidgetTester tester, ActiveSwap swap, {_OneClick? oneClick}) async {
      final settings = settingsWith(swap);
      await tester.pumpApp(
        SwapProgressScreen(account: account),
        overrides: overrides((oneClick ?? _OneClick(dryOut: BigInt.one)).service(), settings: settings),
      );
      await settle(tester);
      return settings;
    }

    Future<void> pumpOrder(WidgetTester tester, SwapOrder order) => pumpSwap(tester, activeSwap(order));

    StepRowState stepState(WidgetTester tester, String label) =>
        tester.widget<QuantusStepRow>(find.widgetWithText(QuantusStepRow, label)).state;

    Finder banner(String prefix) => find.byWidgetPredicate((w) => w is QuantusBanner && w.message.startsWith(prefix));

    testWidgets('shows what arrived where once the swap succeeds', (tester) async {
      await pumpOrder(
        tester,
        SwapOrder(quote: liveQuote, status: SwapStatus.success, amountOut: BigInt.from(24900000)),
      );

      expect(find.text(l10n.swapCompleteTitle), findsOneWidget);
      expect(find.text('24.9 USDC'), findsOneWidget);
      expect(find.text('Ethereum'), findsOneWidget);
    });

    testWidgets('tells a refunded swap out that the QTC went back to the account', (tester) async {
      await pumpOrder(tester, SwapOrder(quote: liveQuote, status: SwapStatus.refunded));

      expect(find.text(l10n.swapFailedTitle), findsOneWidget);
      expect(find.text('REFUNDED'), findsOneWidget);
      expect(find.text(l10n.swapRefundedBody('250 QTC', account.name, 'USDC')), findsOneWidget);
      expect(find.text(l10n.swapStartNew), findsOneWidget);
    });

    testWidgets('follows the status through the steps, says so when a poll fails, and retries', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.one);
      final settings = await pumpSwap(
        tester,
        activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.pendingDeposit)),
        oneClick: oneClick,
      );
      expect(stepState(tester, l10n.swapStepSent('QTC')), StepRowState.done);
      expect(stepState(tester, l10n.swapStepConfirming('Quantus')), StepRowState.active);
      expect(stepState(tester, l10n.swapStepSwapping), StepRowState.pending);

      oneClick.status = 'PROCESSING';
      await tester.pump(SwapService.statusPollInterval);
      await settle(tester);
      expect(stepState(tester, l10n.swapStepConfirming('Quantus')), StepRowState.done);
      expect(stepState(tester, l10n.swapStepSwapping), StepRowState.active);
      final kept = settings.activeSwap!;
      expect(kept.order.status, SwapStatus.processing);

      oneClick.statusCode = 503;
      await tester.pump(SwapService.statusPollInterval);
      await settle(tester);
      expect(banner(l10n.swapProgressStatusUnavailable('')), findsOneWidget);
      expect(stepState(tester, l10n.swapStepSwapping), StepRowState.active);
      expect(find.text(l10n.swapProgressFooter), findsOneWidget);

      oneClick.statusCode = 200;
      oneClick.status = 'SUCCESS';
      await tester.ensureVisible(find.text(l10n.commonRetry));
      await tester.tap(find.text(l10n.commonRetry));
      await settle(tester);
      expect(find.text(l10n.swapCompleteTitle), findsOneWidget);
      expect(containerOf(tester).read(activeSwapProvider)!.settledAt, isNotNull);
      expect(oneClick.requests.where((r) => r.url.path == '/v0/status'), hasLength(3));
    });

    testWidgets('an unknown status is reported and polled past', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.one)..status = 'SETTLING';
      await pumpSwap(
        tester,
        activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.processing)),
        oneClick: oneClick,
      );

      await tester.pump(SwapService.statusPollInterval);
      await settle(tester);
      expect(banner(l10n.swapProgressStatusUnavailable('')), findsOneWidget);
      expect(find.textContaining('SETTLING'), findsOneWidget);

      oneClick.status = 'SUCCESS';
      await tester.pump(SwapService.statusPollInterval);
      await settle(tester);
      expect(find.text(l10n.swapCompleteTitle), findsOneWidget);
    });

    testWidgets('leaving a running swap keeps following it', (tester) async {
      await pumpSwap(tester, activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.processing)));

      final container = containerOf(tester);
      await tester.tap(find.byType(AppBackButton));
      await settle(tester);
      expect(container.read(activeSwapProvider), isNotNull);
      expect(container.read(settingsServiceProvider).getActiveSwap(), isNotNull);
    });

    testWidgets('a deposit not seen by the deadline says so and can be dismissed, sent by the app or by hand', (
      tester,
    ) async {
      final past = clock.now().subtract(const Duration(minutes: 1));
      final late = _quote(
        from: _qtc,
        to: _usdc,
        amountIn: _unit * BigInt.from(250),
        amountOut: BigInt.from(24860000),
        refund: account.accountId,
        recipient: _external,
        depositAddress: _deposit,
        deadline: past,
      );
      await pumpSwap(
        tester,
        activeSwap(
          SwapOrder(quote: late, status: SwapStatus.pendingDeposit),
          age: const Duration(minutes: 5),
        ),
      );
      expect(find.text(l10n.swapInProgressTitle), findsOneWidget);
      expect(banner(l10n.swapProgressOverdue(account.name)), findsOneWidget);
      var container = containerOf(tester);
      await tester.tap(find.text(l10n.swapStopTracking));
      await settle(tester);
      expect(container.read(activeSwapProvider), isNull);

      final lateIn = _quote(
        from: const SwapToken(assetId: 'nep141:btc', symbol: 'BTC', network: 'BTC', decimals: 8, usdPrice: 86000),
        to: _qtc,
        amountIn: BigInt.from(12345678),
        amountOut: _unit * BigInt.from(1000),
        refund: 'bc1qrefund',
        recipient: account.accountId,
        depositAddress: 'bc1qdeposit',
        deadline: past,
      );
      await pumpSwap(tester, activeSwap(SwapOrder(quote: lateIn, status: SwapStatus.pendingDeposit)).withDepositSent());
      expect(find.text(l10n.swapInProgressTitle), findsOneWidget);
      expect(banner(l10n.swapProgressOverdue('bc1qrefund')), findsOneWidget);
      container = containerOf(tester);
      await tester.tap(find.text(l10n.swapStopTracking));
      await settle(tester);
      expect(container.read(activeSwapProvider), isNull);
    });

    testWidgets('a swap 1Click has seen but not settled an hour past its deadline is overdue and can be dismissed', (
      tester,
    ) async {
      final late = _quote(
        from: _qtc,
        to: _usdc,
        amountIn: _unit * BigInt.from(250),
        amountOut: BigInt.from(24860000),
        refund: account.accountId,
        recipient: _external,
        depositAddress: _deposit,
        deadline: clock.now().subtract(ActiveSwap.finishGrace + const Duration(minutes: 1)),
      );
      await pumpSwap(tester, activeSwap(SwapOrder(quote: late, status: SwapStatus.processing)));
      expect(banner(l10n.swapProgressOverdue(account.name)), findsOneWidget);
      final container = containerOf(tester);
      await tester.tap(find.text(l10n.swapStopTracking));
      await settle(tester);
      expect(container.read(activeSwapProvider), isNull);
    });

    testWidgets('the details sheet stops tracking a running swap once confirmed', (tester) async {
      await pumpSwap(tester, activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.processing)));
      final container = containerOf(tester);
      expect(find.text(l10n.swapStopTracking), findsNothing);

      await tester.tap(svg('assets/v2/swap_list.svg'));
      await settle(tester);
      await tester.tap(find.text(l10n.swapStopTracking));
      await settle(tester);
      await tester.tap(find.text(l10n.commonCancel));
      await settle(tester);
      expect(container.read(activeSwapProvider), isNotNull);

      await tester.tap(find.text(l10n.swapStopTracking));
      await settle(tester);
      await tester.tap(find.text(l10n.swapStopTracking).last);
      await settle(tester);
      expect(container.read(activeSwapProvider), isNull);
    });

    testWidgets("I've sent it during a status poll stays sent, whatever the poll answers", (tester) async {
      for (final statusCode in [200, 503]) {
        final oneClick = _OneClick(dryOut: BigInt.one)
          ..statusCode = statusCode
          ..holdStatus = Completer<void>();
        final inQuote = _quote(
          from: const SwapToken(assetId: 'nep141:btc', symbol: 'BTC', network: 'BTC', decimals: 8, usdPrice: 86000),
          to: _qtc,
          amountIn: BigInt.from(12345678),
          amountOut: _unit * BigInt.from(1000),
          refund: 'bc1qrefund',
          recipient: account.accountId,
          depositAddress: 'bc1qdeposit',
        );
        await pumpSwap(
          tester,
          activeSwap(SwapOrder(quote: inQuote, status: SwapStatus.pendingDeposit)),
          oneClick: oneClick,
        );
        await tester.pump(SwapService.statusPollInterval);
        expect(oneClick.requests.where((r) => r.url.path == '/v0/status'), hasLength(1));

        await tester.tap(find.text(l10n.swapDepositSent));
        await settle(tester);
        expect(find.text(l10n.swapInProgressTitle), findsOneWidget);

        oneClick.holdStatus!.complete();
        await settle(tester);
        expect(containerOf(tester).read(activeSwapProvider)!.depositSent, isTrue, reason: 'poll answered $statusCode');
        expect(find.text(l10n.swapInProgressTitle), findsOneWidget);
      }
    });

    for (final (who, account) in [
      ('a Keystone account', makeAccount(2, accountType: AccountType.keystone)),
      ('an account without a key here', null),
    ]) {
      testWidgets('opened from $who, a failed swap can be put away but not replaced', (tester) async {
        await tester.pumpApp(
          SwapProgressScreen(account: account),
          overrides: overrides(
            _OneClick(dryOut: BigInt.one).service(),
            settings: settingsWith(activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.failed))),
          ),
        );
        await settle(tester);

        expect(button(tester, l10n.swapStartNew).isDisabled, isTrue);
        final container = containerOf(tester);
        await tester.tap(find.byType(AppBackButton));
        await settle(tester);
        expect(container.read(activeSwapProvider), isNull);
      });
    }

    testWidgets('a poll failure shows on the deposit screen too, and Retry moves it on', (tester) async {
      final inQuote = _quote(
        from: _usdc,
        to: _qtc,
        amountIn: BigInt.from(25000000),
        amountOut: _unit * BigInt.from(248),
        refund: _external,
        recipient: account.accountId,
        depositAddress: _external,
      );
      final oneClick = _OneClick(dryOut: BigInt.one)..statusCode = 503;
      await pumpSwap(
        tester,
        activeSwap(SwapOrder(quote: inQuote, status: SwapStatus.pendingDeposit)),
        oneClick: oneClick,
      );
      expect(find.text(l10n.swapDepositSent), findsOneWidget);

      await tester.pump(SwapService.statusPollInterval);
      await settle(tester);
      expect(banner(l10n.swapProgressStatusUnavailable('')), findsOneWidget);
      expect(find.text(l10n.swapDepositSent), findsOneWidget);

      oneClick.statusCode = 200;
      oneClick.status = 'KNOWN_DEPOSIT_TX';
      await tester.ensureVisible(find.text(l10n.commonRetry));
      await tester.tap(find.text(l10n.commonRetry));
      await settle(tester);
      expect(find.text(l10n.swapInProgressTitle), findsOneWidget);
      expect(stepState(tester, l10n.swapStepConfirming('Ethereum')), StepRowState.active);
      expect(banner(l10n.swapProgressStatusUnavailable('')), findsNothing);
    });

    testWidgets('a status request that never answers times out, shows the notice and is polled again', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.one)
        ..status = 'PROCESSING'
        ..holdStatus = Completer<void>();
      await pumpSwap(
        tester,
        activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.processing)),
        oneClick: oneClick,
      );
      Iterable<http.Request> polls() => oneClick.requests.where((r) => r.url.path == '/v0/status');

      await tester.pump(SwapService.statusPollInterval);
      expect(polls(), hasLength(1));
      await tester.pump(OneClickService.requestTimeout);
      await settle(tester);
      expect(banner(l10n.swapProgressStatusUnavailable(l10n.swapRequestTimedOut)), findsOneWidget);
      expect(find.text(l10n.commonRetry), findsOneWidget);

      await tester.pump(SwapService.statusPollInterval);
      expect(polls(), hasLength(2));
      oneClick.holdStatus!.complete();
      await settle(tester);
      expect(banner(l10n.swapProgressStatusUnavailable('')), findsNothing);
    });

    testWidgets('polls run one at a time, and an answer that arrives after the swap was put away is dropped', (
      tester,
    ) async {
      final oneClick = _OneClick(dryOut: BigInt.one)
        ..status = 'SUCCESS'
        ..holdStatus = Completer<void>();
      final settings = await pumpSwap(
        tester,
        activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.processing)),
        oneClick: oneClick,
      );
      final notifier = containerOf(tester).read(activeSwapProvider.notifier);
      final first = notifier.refresh();
      final second = notifier.refresh();
      await tester.pump(SwapService.statusPollInterval);
      expect(identical(first, second), isTrue);
      expect(oneClick.requests.where((r) => r.url.path == '/v0/status'), hasLength(1));

      await notifier.clear();
      oneClick.holdStatus!.complete();
      await settle(tester);
      expect(containerOf(tester).read(activeSwapProvider), isNull);
      expect(settings.activeSwap, isNull);
      expect(oneClick.requests.where((r) => r.url.path == '/v0/status'), hasLength(1));
    });

    testWidgets('a swap started while the dismissed one still awaits its answer is polled on its own', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.one)
        ..status = 'PROCESSING'
        ..holdStatus = Completer<void>();
      await pumpSwap(
        tester,
        activeSwap(SwapOrder(quote: liveQuote, status: SwapStatus.processing)),
        oneClick: oneClick,
      );
      final notifier = containerOf(tester).read(activeSwapProvider.notifier);
      unawaited(notifier.refresh());
      await notifier.clear();

      final other = _quote(
        from: _qtc,
        to: _usdc,
        amountIn: liveQuote.amountIn,
        amountOut: liveQuote.amountOut,
        refund: account.accountId,
        recipient: _external,
        depositAddress: 'qzother',
      );
      notifier.start(activeSwap(SwapOrder(quote: other, status: SwapStatus.processing)));
      await tester.pump(SwapService.statusPollInterval);
      Iterable<String> polled() => oneClick.requests
          .where((r) => r.url.path == '/v0/status')
          .map((r) => r.url.queryParameters['depositAddress']!);
      expect(polled(), [_deposit, 'qzother']);

      oneClick.holdStatus!.complete();
      await settle(tester);
      expect(containerOf(tester).read(activeSwapProvider)!.order.depositAddress, 'qzother');

      await tester.pump(SwapService.statusPollInterval);
      await settle(tester);
      expect(polled(), [_deposit, 'qzother', 'qzother']);
    });

    testWidgets('Done on a completed swap and Start new on a failed one put the swap away', (tester) async {
      await pumpOrder(tester, SwapOrder(quote: liveQuote, status: SwapStatus.success));
      var container = containerOf(tester);
      await tester.tap(find.text(l10n.commonDone));
      await settle(tester);
      expect(container.read(activeSwapProvider), isNull);

      await pumpOrder(tester, SwapOrder(quote: liveQuote, status: SwapStatus.failed));
      container = containerOf(tester);
      await tester.tap(find.text(l10n.swapStartNew));
      await settle(tester);
      expect(container.read(activeSwapProvider), isNull);
      expect(find.byType(SwapScreen), findsOneWidget);
    });

    testWidgets('Contact Support on a failed swap opens Help & Support', (tester) async {
      await pumpOrder(tester, SwapOrder(quote: liveQuote, status: SwapStatus.failed));
      await tester.tap(find.text(l10n.commonContactSupport));
      await settle(tester);
      expect(find.byType(HelpAndSupportScreenV2), findsOneWidget);
    });

    testWidgets('shows the deposit address and exact amount while a swap in waits', (tester) async {
      final inQuote = _quote(
        from: const SwapToken(assetId: 'nep141:btc', symbol: 'BTC', network: 'BTC', decimals: 8, usdPrice: 86000),
        to: _qtc,
        amountIn: BigInt.from(12345678),
        amountOut: _unit * BigInt.from(1000),
        refund: 'bc1qrefund',
        recipient: account.accountId,
        depositAddress: 'bc1qdeposit',
      );
      final settings = await pumpSwap(tester, activeSwap(SwapOrder(quote: inQuote, status: SwapStatus.pendingDeposit)));

      expect(find.text(l10n.swapDepositTitle), findsOneWidget);
      expect(find.text('bc1qdeposit'), findsOneWidget);
      expect(find.text(l10n.commonAmountBalance('0.12345678', 'BTC')), findsOneWidget);
      expect(find.text(l10n.swapDepositOnly('BTC', 'Bitcoin')), findsOneWidget);
      expect(find.text(l10n.swapDepositMemoNotice), findsNothing);
      expect(find.text(l10n.swapInProgressTitle), findsNothing);

      await tester.tap(find.text(l10n.swapDepositSent));
      await settle(tester);
      expect(find.text(l10n.swapInProgressTitle), findsOneWidget);
      expect(find.text(l10n.swapStepDeposited('BTC')), findsOneWidget);
      expect(containerOf(tester).read(activeSwapProvider)!.depositSent, isTrue);
      expect(settings.getActiveSwap()!.depositSent, isTrue);
    });

    testWidgets('leaving the deposit screen before the deposit is sent puts the swap away', (tester) async {
      final inQuote = _quote(
        from: const SwapToken(assetId: 'nep141:btc', symbol: 'BTC', network: 'BTC', decimals: 8, usdPrice: 86000),
        to: _qtc,
        amountIn: BigInt.from(12345678),
        amountOut: _unit * BigInt.from(1000),
        refund: 'bc1qrefund',
        recipient: account.accountId,
        depositAddress: 'bc1qdeposit',
      );
      final settings = await pumpSwap(tester, activeSwap(SwapOrder(quote: inQuote, status: SwapStatus.pendingDeposit)));
      final container = containerOf(tester);
      await tester.tap(find.byType(AppBackButton));
      await settle(tester);
      expect(container.read(activeSwapProvider), isNull);
      expect(settings.activeSwap, isNull);
    });

    testWidgets('shows the memo a deposit must carry', (tester) async {
      final inQuote = _quote(
        from: const SwapToken(assetId: 'nep245:xlm', symbol: 'XLM', network: 'STELLAR', decimals: 7, usdPrice: 0.2),
        to: _qtc,
        amountIn: BigInt.from(50000000),
        amountOut: _unit * BigInt.from(10),
        refund: 'GREFUND',
        recipient: account.accountId,
        depositAddress: 'GDEPOSIT',
        depositMemo: '4183920',
      );
      await pumpOrder(tester, SwapOrder(quote: inQuote, status: SwapStatus.pendingDeposit));

      expect(find.text('MEMO'), findsOneWidget);
      expect(find.text('4183920'), findsOneWidget);
      expect(find.text(l10n.swapDepositMemoNotice), findsOneWidget);
    });
  });
}
