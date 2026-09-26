import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/l10n/app_localizations.dart';
import 'package:resonance_network_wallet/providers/connectivity_provider.dart';
import 'package:resonance_network_wallet/providers/l10n_provider.dart';
import 'package:resonance_network_wallet/providers/wallet_providers.dart';
import 'package:resonance_network_wallet/services/transaction_submission_service.dart';
import 'package:resonance_network_wallet/v2/screens/send/send_providers.dart';
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
final _qtc = SwapService.quantusToken(usdPrice: 0.1);
final _unit = BigInt.from(10).pow(AppConstants.decimals);

class _FakeSubmission extends Fake implements TransactionSubmissionService {
  final transfers = <(String, BigInt, BigInt)>[];

  @override
  Future<String> balanceTransfer(
    Account account, {
    required RuntimeCall call,
    required String targetAddress,
    required BigInt amount,
    required BigInt fee,
  }) async {
    transfers.add((targetAddress, amount, fee));
    return '0xtxhash';
  }
}

/// 1Click stand-in: a dry quote pays [dryOut], a live one [liveOut] with a
/// deposit address, both with 1% slippage.
class _OneClick {
  final BigInt dryOut;
  final BigInt liveOut;
  final requests = <http.Request>[];

  _OneClick({required this.dryOut, BigInt? liveOut}) : liveOut = liveOut ?? dryOut;

  Iterable<http.Request> get liveQuotes =>
      requests.where((r) => r.url.path == '/v0/quote' && (jsonDecode(r.body) as Map)['dry'] == false);

  SwapService service() => SwapService(endpoint: 'https://oneclick.test', client: MockClient(_handle));

  Future<http.Response> _handle(http.Request request) async {
    requests.add(request);
    return switch (request.url.path) {
      '/v0/tokens' => http.Response(
        jsonEncode([
          {'assetId': _usdc.assetId, 'decimals': 6, 'blockchain': 'eth', 'symbol': 'USDC', 'price': 1},
        ]),
        200,
      ),
      '/v0/quote' => http.Response(jsonEncode(_quoteJson(jsonDecode(request.body) as Map<String, dynamic>)), 200),
      '/v0/deposit/submit' => http.Response('{}', 200),
      '/v0/status' => http.Response(jsonEncode({'status': 'PENDING_DEPOSIT'}), 200),
      _ => http.Response('down', 503),
    };
  }

  Map<String, dynamic> _quoteJson(Map<String, dynamic> request) {
    final dry = request['dry'] as bool;
    final out = dry ? dryOut : liveOut;
    return {
      'quote': {
        if (!dry) 'depositAddress': _deposit,
        'amountIn': request['amount'],
        'amountOut': '$out',
        'minAmountOut': '${out * BigInt.from(99) ~/ BigInt.from(100)}',
        'amountInUsd': '25.0',
        'amountOutUsd': '24.86',
        if (!dry) 'deadline': DateTime.now().toUtc().add(const Duration(minutes: 20)).toIso8601String(),
        'timeEstimate': 60,
      },
      'quoteRequest': {
        'slippageTolerance': request['slippageTolerance'],
        'refundTo': request['refundTo'],
        'recipient': request['recipient'],
        'deadline': request['deadline'],
      },
      'correlationId': dry ? 'dry' : 'live',
      'signature': 'ed25519:sig',
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
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
}) => SwapQuote(
  fromToken: from,
  toToken: to,
  amountIn: amountIn,
  amountOut: amountOut,
  minAmountOut: amountOut * BigInt.from(99) ~/ BigInt.from(100),
  amountInUsd: 25,
  amountOutUsd: 24.86,
  slippageBps: 100,
  refundAddress: refund,
  recipient: recipient,
  deadline: DateTime.now().add(const Duration(minutes: 20)),
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

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService().initialize();
  });

  List<Override> overrides(SwapService service, {BigInt? balance, _FakeSubmission? submission}) => [
    settingsServiceProvider.overrideWithValue(FakeSettingsService(activeAccount: RegularAccount(account))),
    isOnlineProvider.overrideWith((ref) => true),
    l10nProvider.overrideWithValue(l10n),
    swapServiceProvider.overrideWithValue(service),
    quantusSwapTokenProvider.overrideWithValue(_qtc),
    effectiveMaxBalanceProviderFamily.overrideWith((ref, _) => AsyncValue.data(balance ?? _unit * BigInt.from(1000))),
    swapDepositFeeProvider.overrideWith((ref, _) async => _unit ~/ BigInt.from(50)),
    balancesServiceProvider.overrideWithValue(FakeBalancesService()),
    transactionSubmissionServiceProvider.overrideWithValue(submission ?? _FakeSubmission()),
    swapOrderProvider.overrideWith((ref, order) => Stream.value(order)),
  ];

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Finder svg(String asset) =>
      find.byWidgetPredicate((w) => w is SvgPicture && (w.bytesLoader as SvgAssetLoader).assetName == asset);

  QuantusButton button(WidgetTester tester, String label) =>
      tester.widget<QuantusButton>(find.ancestor(of: find.text(label), matching: find.byType(QuantusButton)));

  group('SwapScreen', () {
    testWidgets('swaps out of QTC by default and flips direction with the arrows', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.from(24860000));
      await tester.pumpApp(
        SwapScreen(account: account),
        overrides: overrides(oneClick.service(), balance: _unit * BigInt.from(100)),
      );
      await settle(tester);

      expect(find.text('FROM'), findsOneWidget);
      expect(find.text(account.name), findsOneWidget);
      expect(find.text(l10n.swapExternalWallet), findsOneWidget);
      expect(button(tester, l10n.swapAddRecipientAddress).isDisabled, isTrue);

      await tester.enterText(find.byType(TextField), '1000');
      await tester.pump();
      expect(button(tester, l10n.sendLogicInsufficientBalance).isDisabled, isTrue);

      await tester.enterText(find.byType(TextField), '10');
      await tester.pump();
      expect(button(tester, l10n.swapAddRecipientAddress).isDisabled, isFalse);
      expect(find.text('1'), findsOneWidget);

      final arrows = svg('assets/v2/swap_arrows_down_up.svg');
      await tester.tap(arrows);
      await tester.pump();

      expect(button(tester, l10n.swapAddRefundAddress).isDisabled, isTrue);
      final fromHeader = tester.getTopLeft(find.text('FROM')).dy;
      expect(tester.getTopLeft(find.text(l10n.swapExternalWallet)).dy, closeTo(fromHeader, 4));
    });
  });

  group('slippage', () {
    testWidgets('the picked tolerance shows on the form and goes into the quote', (tester) async {
      final oneClick = _OneClick(dryOut: BigInt.from(24860000));
      await tester.pumpApp(SwapScreen(account: account), overrides: overrides(oneClick.service()));
      await settle(tester);
      expect(find.text(l10n.swapSlippageLabel('1')), findsOneWidget);

      await tester.tap(svg('assets/v2/swap_pencil.svg'));
      await settle(tester);
      await tester.tap(find.text('2%'));
      await settle(tester);
      expect(find.text(l10n.swapSlippageLabel('2')), findsOneWidget);

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
      expect(find.text(l10n.swapReviewTitle), findsOneWidget);
    });
  });

  group('ReviewSwapScreen', () {
    testWidgets('a swap out sends the QTC to the live deposit address and follows the swap', (tester) async {
      final oneClick = _OneClick(dryOut: outQuote.amountOut);
      final submission = _FakeSubmission();
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: outQuote),
        overrides: overrides(oneClick.service(), submission: submission),
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
    });

    testWidgets('a worse live quote replaces the terms and needs a second confirm', (tester) async {
      final oneClick = _OneClick(dryOut: outQuote.amountOut, liveOut: BigInt.from(20000000));
      final submission = _FakeSubmission();
      await tester.pumpApp(
        ReviewSwapScreen(account: account, quote: outQuote),
        overrides: overrides(oneClick.service(), submission: submission),
      );
      await settle(tester);

      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);

      expect(submission.transfers, isEmpty);
      expect(find.text(l10n.swapReviewTitle), findsOneWidget);
      expect(find.text('19.8 USDC'), findsOneWidget);

      await tester.tap(find.text(l10n.swapReviewConfirm));
      await settle(tester);

      expect(submission.transfers.single.$1, _deposit);
      expect(oneClick.liveQuotes, hasLength(1));
      await tester.pump(const Duration(seconds: 3));
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

  group('SwapProgressScreen', () {
    Future<void> pumpOrder(WidgetTester tester, SwapOrder order) async {
      await tester.pumpApp(
        SwapProgressScreen(account: account, order: order),
        overrides: overrides(_OneClick(dryOut: BigInt.one).service()),
      );
      await settle(tester);
    }

    testWidgets('shows what arrived where once the swap succeeds', (tester) async {
      await pumpOrder(tester, SwapOrder(quote: outQuote, status: SwapStatus.success, amountOut: BigInt.from(24900000)));

      expect(find.text(l10n.swapCompleteTitle), findsOneWidget);
      expect(find.text('24.9 USDC'), findsOneWidget);
      expect(find.text('Ethereum'), findsOneWidget);
    });

    testWidgets('tells a refunded swap out that the QTC went back to the account', (tester) async {
      await pumpOrder(tester, SwapOrder(quote: outQuote, status: SwapStatus.refunded));

      expect(find.text(l10n.swapFailedTitle), findsOneWidget);
      expect(find.text('REFUNDED'), findsOneWidget);
      expect(find.text(l10n.swapRefundedBody('250 QTC', account.name, 'USDC')), findsOneWidget);
      expect(find.text(l10n.swapStartNew), findsOneWidget);
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
      await pumpOrder(tester, SwapOrder(quote: inQuote, status: SwapStatus.pendingDeposit));

      expect(find.text('bc1qdeposit'), findsOneWidget);
      expect(find.text('0.12345678'), findsOneWidget);
      expect(find.text(l10n.swapDepositMemoNotice), findsNothing);
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
