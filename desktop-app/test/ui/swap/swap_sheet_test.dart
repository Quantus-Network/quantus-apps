import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/ui/components/pop_up_button.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/shell/account_toolbar.dart';
import 'package:quantus_desktop_wallet/ui/shell/desktop_shell.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_detail.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_row_view.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_sheet.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/models/swap_preflight.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/services/user_approval.dart';

import '../../fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('en'));

BigInt _qtc(num tokens) => BigInt.from(tokens * 10000) * oneToken ~/ BigInt.from(10000);

/// What Main holds unless a test says otherwise.
final _held = _qtc(1250);

/// A token account on another chain, as Solana writes one.
const _otherAddress = '7xKXtg2CW87d97TXJSDpbD5jBkheTqA83TZRuJosgAsU';

Finder _key(Key key) => find.byKey(key);

/// A label drawn in capitals.
Finder _caps(String label) => find.text(label.toUpperCase());

Finder _in(Key box, Finder finder) => find.descendant(of: find.byKey(box), matching: finder);

SheetButton _button(WidgetTester tester, Key key) => tester.widget<SheetButton>(find.byKey(key));

String _text(WidgetTester tester, Key key) => tester.widget<Text>(find.byKey(key)).data!;

/// Opens Main's wallet and presses Swap in its toolbar.
Future<FakeSwapService> _openSheet(
  WidgetTester tester, {
  FakeSwapService? swaps,
  FakeSwapService Function(Ref ref)? swapsOf,
  FakeSendChain? chain,
  FakeUserApproval? approval,
  FakeRemoteConfigService? remoteConfig,
  FakeSettingsService? settings,
  BigInt? held,
  Size? window,
  bool settle = true,
  SwapPreflight? preflight,
}) async {
  final service = swaps ?? FakeSwapService();
  await pumpShell(
    tester,
    overrides: [
      if (preflight != null) swapPreflightProvider.overrideWithValue(preflight),
      ...shellOverrides(
        accounts: const [mainAccount, savingsAccount, encryptedAccount],
        settings: settings ?? FakeSettingsService(activeAccount: const RegularAccount(mainAccount)),
        balances: {...oneTokenEach, mainAccount.accountId: held ?? _held},
        encryptedBalances: {0: oneToken},
        chain: chain,
        approval: approval,
        swaps: swapsOf == null ? service : null,
        swapsOf: swapsOf,
        remoteConfig: remoteConfig,
      ),
    ],
  );
  if (window != null) {
    tester.view.physicalSize = window;
    await tester.pumpAndSettle();
  }
  await tester.tap(
    find.descendant(of: find.byType(AccountToolbar), matching: find.widgetWithText(ToolbarAction, _l10n.homeSwap)),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // What is on screen turns for as long as it loads, and never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }
  return service;
}

Future<void> _press(WidgetTester tester, Key key) async {
  await tester.ensureVisible(find.byKey(key));
  await tester.pump();
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}

Future<void> _typeAmount(WidgetTester tester, String amount) async {
  await tester.enterText(_key(SwapSheet.amountFieldKey), amount);
  await tester.pump();
}

Future<void> _typeAddress(WidgetTester tester, String address) async {
  await tester.enterText(_key(SwapSheet.addressFieldKey), address);
  await tester.pump();
}

/// Lets the form rest until its quote has been asked for and has answered.
Future<void> _rest(WidgetTester tester) async {
  await tester.pump(swapFormQuoteDebounce);
  await tester.pumpAndSettle();
}

/// Fills in a swap of [amount] to or from [swapRecipient] and opens its
/// review.
Future<void> _openReview(WidgetTester tester, {String amount = '250'}) async {
  await _typeAmount(tester, amount);
  await _typeAddress(tester, swapRecipient);
  await _rest(tester);
  await _press(tester, SwapSheet.reviewKey);
}

Future<void> _pickToken(WidgetTester tester, SwapToken token) async {
  await _press(tester, SwapSheet.tokenButtonKey);
  await _press(tester, SwapSheet.tokenRowKey(token.assetId));
}

/// [quote] with other amounts, as a live quote differs from a dry one.
SwapQuote _requoted(SwapQuote quote, {BigInt? amountOut, BigInt? minAmountOut}) => SwapQuote(
  fromToken: quote.fromToken,
  toToken: quote.toToken,
  swapType: quote.swapType,
  amountIn: quote.amountIn,
  minAmountIn: quote.minAmountIn,
  amountOut: amountOut ?? quote.amountOut,
  minAmountOut: minAmountOut ?? quote.minAmountOut,
  amountInUsd: quote.amountInUsd,
  amountOutUsd: quote.amountOutUsd,
  slippageBps: quote.slippageBps,
  refundAddress: quote.refundAddress,
  recipient: quote.recipient,
  deadline: quote.deadline,
  timeEstimate: quote.timeEstimate,
  correlationId: quote.correlationId,
  signature: quote.signature,
  depositAddress: quote.depositAddress,
  withdrawFee: quote.withdrawFee,
  feeBps: quote.feeBps,
);

void _putOnClipboard(WidgetTester tester, String text) {
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.getData') return {'text': text};
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(DesktopShell)));

void main() {
  group('opening', () {
    testOnMac('opens on the form: QTC paid from the account on top, the first token listed below', (tester) async {
      await _openSheet(tester);

      expect(find.byType(SwapSheet), findsOneWidget);
      expect(_in(SwapSheet.payBoxKey, find.text('QTC')), findsOneWidget);
      expect(_in(SwapSheet.receiveBoxKey, find.text('USDC')), findsOneWidget);
      expect(_in(SwapSheet.receiveBoxKey, find.text('Arbitrum')), findsOneWidget);
      expect(_in(SwapSheet.receiveBoxKey, find.text(_l10n.swapExternalWallet)), findsOneWidget);
      expect(find.text(_l10n.desktopSwapPoweredByNearIntents), findsOneWidget);
      expect(_button(tester, SwapSheet.reviewKey).isDisabled, isFalse);
    });

    testOnMac('while the tokens load there is no form, only that they are loading', (tester) async {
      final listing = Completer<List<SwapToken>>();
      final swaps = FakeSwapService()..tokens = () => listing.future;

      await _openSheet(tester, swaps: swaps, settle: false);

      expect(find.text(_l10n.desktopSwapLoadingTokens), findsOneWidget);
      expect(_key(SwapSheet.amountFieldKey), findsNothing);

      listing.complete(const [listedQtc, usdcOnArbitrum]);
      await tester.pumpAndSettle();

      expect(find.text(_l10n.desktopSwapLoadingTokens), findsNothing);
      expect(_key(SwapSheet.amountFieldKey), findsOneWidget);
    });

    testOnMac('1Click out of reach is said, and Try Again asks it afresh', (tester) async {
      final swaps = FakeSwapService()..tokens = () async => throw const SwapApiException(503, 'down');
      await _openSheet(tester, swaps: swaps);

      expect(find.text(_l10n.swapUnavailableUnreachable), findsOneWidget);
      expect(_key(SwapSheet.amountFieldKey), findsNothing);

      swaps.tokens = () async => const [listedQtc, usdcOnArbitrum];
      await _press(tester, SwapSheet.tryAgainKey);

      expect(swaps.freshTokenLoads, 1);
      expect(_key(SwapSheet.amountFieldKey), findsOneWidget);
    });

    testOnMac('QTC not listed with a price shows swaps as disabled, with no way to ask again', (tester) async {
      await _openSheet(tester, swaps: FakeSwapService()..listedQuantus = null);

      expect(_caps(_l10n.swapDisabledTitle), findsOneWidget);
      expect(_key(SwapSheet.tryAgainKey), findsNothing);
      expect(_key(SwapSheet.amountFieldKey), findsNothing);
    });

    testOnMac('a location that turns against swaps while the form is open takes the form away', (tester) async {
      final config = FakeRemoteConfigService(RemoteConfigModel.defaults);
      await _openSheet(tester, remoteConfig: config);
      expect(_key(SwapSheet.amountFieldKey), findsOneWidget);

      config.remote = swapsNotOffered;
      unawaited(_container(tester).read(remoteConfigProvider.notifier).syncConfig());
      await tester.pumpAndSettle();

      expect(_caps(_l10n.swapDisabledTitle), findsOneWidget);
      expect(_key(SwapSheet.amountFieldKey), findsNothing);
    });

    testOnMac('a preflight build says what stands in for QTC, and has its deposit made by hand from the '
        "stand-in's own address", (tester) async {
      const standIn = SwapPreflight(assetId: 'nep141:stand-in', address: '0xTester');
      final swaps = await _openSheet(tester, preflight: standIn);

      expect(find.text(_l10n.swapPreflightBanner('QTC', 'Quantus')), findsOneWidget);
      // The app sends no deposit, so nothing of the account's is measured.
      expect(_key(SwapSheet.maxKey), findsNothing);

      await _typeAmount(tester, '250');
      await _typeAddress(tester, swapRecipient);
      await _rest(tester);

      expect(swaps.quoteRequests.single.refundAddress, '0xTester');
    });

    testOnMac('a rebuilt swap service is asked for its own tokens', (tester) async {
      final rebuilds = StateProvider<int>((_) => 0);
      final first = FakeSwapService();
      final second = FakeSwapService()..tokens = () async => const [listedQtc, usdtOnEthereum];
      await _openSheet(tester, swapsOf: (ref) => ref.watch(rebuilds) == 0 ? first : second);
      expect(_in(SwapSheet.receiveBoxKey, find.text('USDC')), findsOneWidget);

      _container(tester).read(rebuilds.notifier).state = 1;
      await tester.pumpAndSettle();

      expect(second.tokenLoads, 1);
      // The token picked before stays picked: the listing is what changed.
      expect(_in(SwapSheet.receiveBoxKey, find.text('USDC')), findsOneWidget);
    });
  });

  group('amounts', () {
    testOnMac('an amount typed above shows what it buys below as an estimate, with both sides in dollars', (
      tester,
    ) async {
      final swaps = await _openSheet(tester);

      await _typeAmount(tester, '250');

      expect(_text(tester, SwapSheet.otherAmountKey), '~104.7');
      expect(_in(SwapSheet.payBoxKey, find.text(r'$104.70')), findsOneWidget);
      expect(_in(SwapSheet.receiveBoxKey, find.text(r'$104.70')), findsOneWidget);
      expect(find.text(_l10n.swapEstimateNotice), findsOneWidget);
      expect(find.text(_l10n.swapRateEstimateLabel('QTC', '0.4188', 'USDC')), findsOneWidget);
      // No address yet, so nothing is asked of 1Click.
      await _rest(tester);
      expect(swaps.quoteRequests, isEmpty);
    });

    testOnMac('the quote, once in, replaces the estimate with its amounts, rate and fees', (tester) async {
      final swaps = FakeSwapService();
      swaps.quote = (request) async => _requoted(
        fakeQuoteFor(request, withdrawFee: BigInt.from(20000), feeBps: 30),
        amountOut: BigInt.from(104370000),
        minAmountOut: BigInt.from(103330000),
      );
      await _openSheet(tester, swaps: swaps);

      await _typeAmount(tester, '250');
      await _typeAddress(tester, swapRecipient);
      await _rest(tester);

      expect(_text(tester, SwapSheet.otherAmountKey), '104.37');
      expect(find.text(_l10n.swapEstimateNotice), findsNothing);
      expect(find.text(_l10n.swapReviewSwapFee), findsOneWidget);
      expect(find.text(_l10n.swapReviewWithdrawalFee), findsOneWidget);
      final request = swaps.quoteRequests.single;
      expect(request.amount, _qtc(250));
      expect(request.swapType, SwapType.exactInput);
      expect(request.recipient, swapRecipient);
      expect(request.refundAddress, mainAccount.accountId);
    });

    testOnMac('typing while the form has not rested asks for one quote, of the last amount', (tester) async {
      final swaps = await _openSheet(tester);
      await _typeAddress(tester, swapRecipient);

      await _typeAmount(tester, '2');
      await tester.pump(const Duration(milliseconds: 100));
      await _typeAmount(tester, '25');
      await tester.pump(const Duration(milliseconds: 100));
      await _typeAmount(tester, '250');
      await _rest(tester);

      expect(swaps.quoteRequests.map((r) => r.amount), [_qtc(250)]);
    });

    testOnMac('an amount typed below is what must arrive: the quote is for an exact output', (tester) async {
      final swaps = await _openSheet(tester);
      await _typeAddress(tester, swapRecipient);
      await _typeAmount(tester, '250');

      await _press(tester, SwapSheet.otherAmountKey);
      // Typing moved below, starting from what stood there.
      expect(_in(SwapSheet.receiveBoxKey, _key(SwapSheet.amountFieldKey)), findsOneWidget);
      expect(tester.widget<TextField>(_key(SwapSheet.amountFieldKey)).controller!.text, '104.7');

      await _typeAmount(tester, '100');
      await _rest(tester);

      final request = swaps.quoteRequests.last;
      expect(request.swapType, SwapType.exactOutput);
      expect(request.amount, BigInt.from(100000000));
      expect(_in(SwapSheet.payBoxKey, _key(SwapSheet.otherAmountKey)), findsOneWidget);
    });

    testOnMac('a quote that fails is said in place, and pressing Review asks again', (tester) async {
      final swaps = FakeSwapService()..quote = (_) async => throw const SwapApiException(400, 'Amount is too low');
      await _openSheet(tester, swaps: swaps);

      await _typeAmount(tester, '250');
      await _typeAddress(tester, swapRecipient);
      await _rest(tester);

      expect(find.text(_l10n.swapQuoteError('Amount is too low')), findsOneWidget);
      expect(swaps.quoteRequests, hasLength(1));

      swaps.quote = (request) async => fakeQuoteFor(request);
      await _press(tester, SwapSheet.reviewKey);
      await _rest(tester);

      expect(swaps.quoteRequests, hasLength(2));
      expect(_key(SwapSheet.confirmKey), findsOneWidget);
    });

    testOnMac('the paying account is named with the most it can put in, its fee and the deposit that keeps it alive '
        'left behind', (tester) async {
      await _openSheet(tester);

      // 1,250 less the 0.0012 fee and the 0.001 that keeps the account alive.
      expect(
        _in(SwapSheet.payBoxKey, find.text(_l10n.desktopSwapAccountAvailable('Main', '1,249.9978 QTC'))),
        findsOneWidget,
      );
    });

    testOnMac('a fee that cannot be had is said with a way to ask again', (tester) async {
      final chain = FakeSendChain()..fee = () async => throw TimeoutException('slow');
      await _openSheet(tester, chain: chain);

      expect(find.text(_l10n.swapReviewFeeFailed), findsOneWidget);

      chain.fee = () async => FakeSendChain.usualFee;
      await _press(tester, SwapSheet.retryFeeKey);

      expect(find.text(_l10n.swapReviewFeeFailed), findsNothing);
      expect(
        _in(SwapSheet.payBoxKey, find.text(_l10n.desktopSwapAccountAvailable('Main', '1,249.9978 QTC'))),
        findsOneWidget,
      );
    });

    testOnMac('the maximum types the most the account can put in and locks the amount', (tester) async {
      await _openSheet(tester);

      await _press(tester, SwapSheet.maxKey);

      final field = tester.widget<TextField>(_key(SwapSheet.amountFieldKey));
      expect(field.controller!.text, '1249.9978');
      expect(field.enabled, isFalse);

      await _press(tester, SwapSheet.maxKey);

      expect(tester.widget<TextField>(_key(SwapSheet.amountFieldKey)).enabled, isTrue);
    });

    testOnMac('the maximum is not offered when the other side pays', (tester) async {
      await _openSheet(tester);
      expect(_key(SwapSheet.maxKey), findsOneWidget);

      await _press(tester, SwapSheet.flipKey);

      expect(_key(SwapSheet.maxKey), findsNothing);
    });

    testOnMac('more than the account can pay is said, and cannot be reviewed', (tester) async {
      await _openSheet(tester);

      await _typeAmount(tester, '1250');
      await _typeAddress(tester, swapRecipient);
      await _rest(tester);

      expect(_text(tester, SwapSheet.problemKey), _l10n.sendLogicInsufficientBalance);
      expect(_button(tester, SwapSheet.reviewKey).isDisabled, isTrue);
    });

    testOnMac('where this computer cannot approve, a swap out says what to set up and cannot be reviewed', (
      tester,
    ) async {
      final approval = FakeUserApproval()..availabilityAnswer = ApprovalAvailability.notSetUp;
      await _openSheet(tester, approval: approval);

      await _typeAmount(tester, '250');
      await _typeAddress(tester, swapRecipient);
      await _rest(tester);

      expect(find.text(_l10n.desktopApprovalNeedsMacPassword), findsOneWidget);
      expect(_button(tester, SwapSheet.reviewKey).isDisabled, isTrue);
    });
  });

  group('direction and tokens', () {
    testOnMac('the arrows turn the swap around: the address stays, in its new role, and the amount goes', (
      tester,
    ) async {
      final swaps = await _openSheet(tester);
      await _typeAmount(tester, '250');
      await _typeAddress(tester, swapRecipient);
      await _rest(tester);
      expect(_caps(_l10n.desktopSwapRecipientAddressOn('Arbitrum')), findsOneWidget);

      await _press(tester, SwapSheet.flipKey);

      expect(_in(SwapSheet.payBoxKey, find.text('USDC')), findsOneWidget);
      expect(_in(SwapSheet.receiveBoxKey, find.text('QTC')), findsOneWidget);
      expect(tester.widget<TextField>(_key(SwapSheet.amountFieldKey)).controller!.text, isEmpty);
      expect(_caps(_l10n.desktopSwapRefundAddressOn('Arbitrum')), findsOneWidget);
      expect(find.text(swapRecipient), findsOneWidget);

      await _typeAmount(tester, '100');
      await _rest(tester);

      final request = swaps.quoteRequests.last;
      expect(request.from, usdcOnArbitrum);
      expect(request.refundAddress, swapRecipient);
      expect(request.recipient, mainAccount.accountId);
    });

    testOnMac('the token list narrows to what is typed, by symbol or by chain, and says when nothing matches', (
      tester,
    ) async {
      await _openSheet(tester);
      await _press(tester, SwapSheet.tokenButtonKey);
      expect(_key(SwapSheet.tokenRowKey(usdtOnEthereum.assetId)), findsOneWidget);
      expect(_key(SwapSheet.tokenRowKey(wNear.assetId)), findsOneWidget);

      await tester.enterText(_key(SwapSheet.tokenSearchKey), 'eth');
      await tester.pumpAndSettle();

      expect(_key(SwapSheet.tokenRowKey(usdcOnEthereum.assetId)), findsOneWidget);
      expect(_key(SwapSheet.tokenRowKey(usdtOnEthereum.assetId)), findsOneWidget);
      expect(_key(SwapSheet.tokenRowKey(usdcOnArbitrum.assetId)), findsNothing);

      await tester.enterText(_key(SwapSheet.tokenSearchKey), 'near');
      await tester.pumpAndSettle();
      expect(_key(SwapSheet.tokenRowKey(wNear.assetId)), findsOneWidget);

      await tester.enterText(_key(SwapSheet.tokenSearchKey), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text(_l10n.swapTokenPickerNoMatch), findsOneWidget);
    });

    testOnMac('a token on the same chain keeps the address; one on another chain clears it', (tester) async {
      await _openSheet(tester);
      await _pickToken(tester, usdcOnEthereum);
      await _typeAddress(tester, swapRecipient);

      await _pickToken(tester, usdtOnEthereum);
      expect(_in(SwapSheet.receiveBoxKey, find.text('USDT')), findsOneWidget);
      expect(find.text(swapRecipient), findsOneWidget);

      await _pickToken(tester, usdcOnArbitrum);
      expect(_in(SwapSheet.receiveBoxKey, find.text('Arbitrum')), findsOneWidget);
      expect(find.text(swapRecipient), findsNothing);
      expect(_caps(_l10n.desktopSwapRecipientAddressOn('Arbitrum')), findsOneWidget);
    });

    testOnMac('picking QTC for the other side turns the swap around', (tester) async {
      await _openSheet(tester);

      await _pickToken(tester, listedQtc);

      expect(_in(SwapSheet.payBoxKey, find.text('USDC')), findsOneWidget);
      expect(_in(SwapSheet.receiveBoxKey, find.text('QTC')), findsOneWidget);
    });
  });

  group('the address', () {
    testOnMac('says whose it is and on which chain, and Paste fills it from the clipboard', (tester) async {
      await _openSheet(tester);
      expect(_caps(_l10n.desktopSwapRecipientAddressOn('Arbitrum')), findsOneWidget);
      expect(find.text(_l10n.swapRecipientAddressNotice('USDC')), findsOneWidget);

      _putOnClipboard(tester, '  $swapRecipient\n');
      await _press(tester, SwapSheet.pasteKey);

      expect(
        tester.widget<EditableText>(_in(SwapSheet.addressFieldKey, find.byType(EditableText))).controller.text,
        swapRecipient,
      );

      await _press(tester, SwapSheet.flipKey);
      expect(find.text(_l10n.swapRefundAddressNotice('USDC', 'Arbitrum')), findsOneWidget);
    });

    testOnMac('with no address, Review leads to the address field and opens nothing', (tester) async {
      final swaps = await _openSheet(tester);
      await _typeAmount(tester, '250');

      await _press(tester, SwapSheet.reviewKey);

      expect(_key(SwapSheet.confirmKey), findsNothing);
      expect(swaps.quoteRequests, isEmpty);
      final address = tester.widget<EditableText>(_in(SwapSheet.addressFieldKey, find.byType(EditableText)));
      expect(address.focusNode.hasFocus, isTrue);
    });
  });

  group('slippage', () {
    testOnMac('a tolerance picked is what the next quote asks for', (tester) async {
      final swaps = await _openSheet(tester);
      await _typeAmount(tester, '250');
      await _typeAddress(tester, swapRecipient);
      await _rest(tester);
      expect(swaps.quoteRequests.last.slippageBps, 100);

      await _press(tester, SwapSheet.slippageKey);
      await tester.tap(
        find.descendant(of: find.byKey(PopUpButton.menuKey), matching: find.text(_l10n.commonPercent('2'))),
      );
      await tester.pumpAndSettle();
      await _rest(tester);

      expect(swaps.quoteRequests.last.slippageBps, 200);
    });

    testOnMac('a custom tolerance applies once it is one; past the most allowed it says so and changes nothing', (
      tester,
    ) async {
      final swaps = await _openSheet(tester);
      await _typeAmount(tester, '250');
      await _typeAddress(tester, swapRecipient);

      await _press(tester, SwapSheet.slippageKey);
      await tester.tap(
        find.descendant(of: find.byKey(PopUpButton.menuKey), matching: find.text(_l10n.swapSlippageCustom)),
      );
      await tester.pumpAndSettle();
      await tester.enterText(_key(SwapSheet.customSlippageKey), '3.5');
      await _rest(tester);

      expect(swaps.quoteRequests.last.slippageBps, 350);

      await tester.enterText(_key(SwapSheet.customSlippageKey), '99.5');
      await _rest(tester);

      expect(find.text(_l10n.swapSlippageCustomMax('99')), findsOneWidget);
      expect(swaps.quoteRequests.last.slippageBps, 350);
    });
  });

  group('the review', () {
    testOnMac('lists the swap as quoted: what is paid and what for, the address whole, the terms and the total', (
      tester,
    ) async {
      final swaps = FakeSwapService();
      swaps.quote = (request) async => _requoted(
        fakeQuoteFor(request, withdrawFee: BigInt.from(20000), feeBps: 30),
        amountOut: BigInt.from(104370000),
        minAmountOut: BigInt.from(103330000),
      );
      await _openSheet(tester, swaps: swaps);

      await _openReview(tester);

      expect(_key(SwapSheet.amountFieldKey), findsNothing);
      expect(find.text('250'), findsOneWidget);
      expect(find.text(_l10n.desktopSwapForAmountOnNetwork('104.37 USDC', 'Arbitrum')), findsOneWidget);
      expect(find.text(swapRecipient), findsOneWidget);
      for (final label in [
        _l10n.swapRate,
        _l10n.swapReviewSwapFee,
        _l10n.swapReviewWithdrawalFee,
        _l10n.swapReviewNetworkFee,
        _l10n.swapReviewSlippage,
        _l10n.swapReviewGuaranteedMinimum,
        _l10n.swapYouPay,
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('103.33 USDC'), findsOneWidget);
      expect(find.text('250.0012 QTC'), findsOneWidget);
      expect(_button(tester, SwapSheet.confirmKey).isDisabled, isFalse);
    });

    testOnMac('Back, and the Back keys, return to the form as it was', (tester) async {
      await _openSheet(tester);
      await _openReview(tester);

      await _press(tester, SwapSheet.backKey);

      expect(tester.widget<TextField>(_key(SwapSheet.amountFieldKey)).controller!.text, '250');
      expect(find.text(swapRecipient), findsOneWidget);

      await _press(tester, SwapSheet.reviewKey);
      await _rest(tester);
      expect(_key(SwapSheet.confirmKey), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
      await tester.sendKeyEvent(LogicalKeyboardKey.bracketLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
      await tester.pumpAndSettle();

      expect(_key(SwapSheet.amountFieldKey), findsOneWidget);
    });

    testOnMac('a swap into QTC has no network fee, shows where a refund goes, and continues to its deposit', (
      tester,
    ) async {
      await _openSheet(tester);
      await _press(tester, SwapSheet.flipKey);

      await _openReview(tester, amount: '100');

      expect(find.text(_l10n.swapReviewNetworkFee), findsNothing);
      expect(_caps(_l10n.desktopSwapRefundAddressOn('Arbitrum')), findsOneWidget);
      expect(find.text(swapRecipient), findsOneWidget);
      expect(_button(tester, SwapSheet.confirmKey).label, _l10n.swapContinue);
      expect(find.text('100 USDC'), findsOneWidget);
    });

    testOnMac('an exact output says that what its payment does not use is refunded', (tester) async {
      await _openSheet(tester);
      await _typeAddress(tester, swapRecipient);
      await _typeAmount(tester, '250');
      await _press(tester, SwapSheet.otherAmountKey);
      await _typeAmount(tester, '100');
      await _rest(tester);

      await _press(tester, SwapSheet.reviewKey);

      expect(find.text(_l10n.swapReviewUnusedRefunded), findsOneWidget);
    });

    testOnMac('a fee that cannot be had blocks the swap until asking again gets it', (tester) async {
      final chain = FakeSendChain();
      await _openSheet(tester, chain: chain);
      // The review asks the fee of the amount quoted, which nothing has yet.
      chain.fee = () async => throw TimeoutException('slow');

      await _openReview(tester);

      expect(_text(tester, SwapSheet.noticeKey), _l10n.swapReviewFeeFailed);
      expect(_button(tester, SwapSheet.confirmKey).isDisabled, isTrue);

      chain.fee = () async => FakeSendChain.usualFee;
      await _press(tester, SwapSheet.retryFeeKey);

      expect(_key(SwapSheet.noticeKey), findsNothing);
      expect(_button(tester, SwapSheet.confirmKey).isDisabled, isFalse);
    });

    testOnMac('an amount the account cannot pay with its fee is said and blocked', (tester) async {
      final chain = FakeSendChain();
      await _openSheet(tester, chain: chain);
      // The fee grows once the review asks for it.
      await _typeAmount(tester, '1249.99');
      await _typeAddress(tester, swapRecipient);
      await _rest(tester);
      chain.fee = () async => _qtc(1);

      await _press(tester, SwapSheet.reviewKey);

      expect(_text(tester, SwapSheet.noticeKey), _l10n.swapReviewInsufficient('QTC'));
      expect(_button(tester, SwapSheet.confirmKey).isDisabled, isTrue);
    });

    testOnMac('a location that turns against swaps blocks the review, and says so', (tester) async {
      final config = FakeRemoteConfigService(RemoteConfigModel.defaults);
      await _openSheet(tester, remoteConfig: config);
      await _openReview(tester);

      config.remote = swapsNotOffered;
      unawaited(_container(tester).read(remoteConfigProvider.notifier).syncConfig());
      await tester.pumpAndSettle();

      expect(_text(tester, SwapSheet.noticeKey), _l10n.swapDisabledTitle);
      expect(_button(tester, SwapSheet.confirmKey).isDisabled, isTrue);
    });
  });

  group('confirming', () {
    testOnMac('a swap out is approved, its deposit sent, and the sheet gives way to the swap at the right', (
      tester,
    ) async {
      final chain = FakeSendChain();
      final approval = FakeUserApproval();
      final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
      final swaps = await _openSheet(tester, chain: chain, approval: approval, settings: settings);
      await _openReview(tester);

      await _press(tester, SwapSheet.confirmKey);

      expect(approval.reasons, hasLength(1));
      final transfer = chain.transfers.single;
      expect(transfer.from, mainAccount.accountId);
      expect(transfer.call.recipient, swapQuantusDepositAddress);
      expect(transfer.amount, _qtc(250));
      expect(swaps.deposits.single.hash, '0xhash');
      expect(find.byType(SwapSheet), findsNothing);
      expect(find.byType(SwapDetail), findsOneWidget);
      expect(find.byType(SwapRowView), findsOneWidget);
      expect(settings.activeSwap?.depositTxHash, '0xhash');
      expect(settings.activeSwap?.depositByHand, isFalse);
    });

    testOnMac('a swap in sends nothing: the sheet gives way to the deposit to make', (tester) async {
      final chain = FakeSendChain();
      final approval = FakeUserApproval();
      final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
      await _openSheet(tester, chain: chain, approval: approval, settings: settings);
      await _press(tester, SwapSheet.flipKey);
      await _openReview(tester, amount: '100');

      await _press(tester, SwapSheet.confirmKey);

      expect(approval.reasons, isEmpty);
      expect(chain.transfers, isEmpty);
      expect(find.byType(SwapSheet), findsNothing);
      expect(find.byType(SwapDetail), findsOneWidget);
      expect(find.text(_l10n.swapDepositSent), findsOneWidget);
      expect(settings.activeSwap?.depositByHand, isTrue);
    });

    testOnMac('a live quote that guarantees less replaces the terms and is confirmed with a second press', (
      tester,
    ) async {
      final chain = FakeSendChain();
      final swaps = FakeSwapService();
      swaps.create = (reviewed) async => SwapOrder(
        quote: _requoted(reviewed, amountOut: BigInt.from(99000000), minAmountOut: BigInt.from(98000000)),
        status: SwapStatus.pendingDeposit,
      );
      await _openSheet(tester, swaps: swaps, chain: chain);
      await _openReview(tester);

      await _press(tester, SwapSheet.confirmKey);

      expect(_text(tester, SwapSheet.noticeKey), _l10n.swapReviewPriceMoved);
      expect(find.text('98 USDC'), findsOneWidget);
      expect(chain.transfers, isEmpty);
      expect(find.byType(SwapSheet), findsOneWidget);

      await _press(tester, SwapSheet.confirmKey);

      expect(chain.transfers, hasLength(1));
      // The order taken is kept: its deposit address is the one paid.
      expect(swaps.created, hasLength(1));
      expect(find.byType(SwapSheet), findsNothing);
    });

    testOnMac('approval refused is said in place: nothing is sent or followed, and it can be asked again', (
      tester,
    ) async {
      final chain = FakeSendChain();
      final approval = FakeUserApproval()..answer = () async => ApprovalResult.declined;
      final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
      await _openSheet(tester, chain: chain, approval: approval, settings: settings);
      await _openReview(tester);

      await _press(tester, SwapSheet.confirmKey);

      expect(_text(tester, SwapSheet.noticeKey), _l10n.sendReviewAuthRequired);
      expect(chain.transfers, isEmpty);
      expect(settings.activeSwap, isNull);

      approval.answer = () async => ApprovalResult.approved;
      await _press(tester, SwapSheet.confirmKey);

      expect(chain.transfers, hasLength(1));
      expect(find.byType(SwapSheet), findsNothing);
    });

    testOnMac('a deposit the chain refuses, and a live quote 1Click refuses, are each said in place', (tester) async {
      final chain = FakeSendChain()..submit = () async => throw StateError('refused');
      final swaps = await _openSheet(tester, chain: chain);
      await _openReview(tester);

      await _press(tester, SwapSheet.confirmKey);
      expect(_text(tester, SwapSheet.noticeKey), _l10n.sendReviewSubmitFailed);

      await _press(tester, SwapSheet.backKey);
      await _typeAmount(tester, '251');
      await _rest(tester);
      await _press(tester, SwapSheet.reviewKey);
      swaps.create = (_) async => throw const SwapApiException(400, 'Quote expired');
      await _press(tester, SwapSheet.confirmKey);

      expect(_text(tester, SwapSheet.noticeKey), _l10n.swapQuoteError('Quote expired'));
      expect(find.byType(SwapSheet), findsOneWidget);
    });

    testOnMac('a review opened again takes a live order of its own: what an earlier review was offered is not '
        'what is paid', (tester) async {
      final chain = FakeSendChain();
      final approval = FakeUserApproval()..answer = () async => ApprovalResult.declined;
      final swaps = await _openSheet(tester, chain: chain, approval: approval);
      await _openReview(tester);
      // The live order for 250 is taken, and its approval refused.
      await _press(tester, SwapSheet.confirmKey);
      expect(swaps.created.single.amountIn, _qtc(250));

      await _press(tester, SwapSheet.backKey);
      await _typeAmount(tester, '100');
      await _rest(tester);
      await _press(tester, SwapSheet.reviewKey);
      approval.answer = () async => ApprovalResult.approved;
      await _press(tester, SwapSheet.confirmKey);

      expect(swaps.created.map((quote) => quote.amountIn), [_qtc(250), _qtc(100)]);
      expect(chain.transfers.single.amount, _qtc(100));
    });

    testOnMac('closing the sheet from the review sends nothing and follows nothing', (tester) async {
      final chain = FakeSendChain();
      final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
      final swaps = await _openSheet(tester, chain: chain, settings: settings);
      await _openReview(tester);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.byType(SwapSheet), findsNothing);
      expect(swaps.created, isEmpty);
      expect(chain.transfers, isEmpty);
      expect(settings.activeSwap, isNull);
      expect(find.byType(SwapRowView), findsNothing);
    });

    testOnMac('while it confirms, the sheet stays: neither the cross nor Escape closes it', (tester) async {
      final order = Completer<SwapOrder>();
      final swaps = FakeSwapService()..create = (_) => order.future;
      await _openSheet(tester, swaps: swaps);
      await _openReview(tester);

      await tester.tap(_key(SwapSheet.confirmKey));
      await tester.pump();
      expect(_button(tester, SwapSheet.confirmKey).isLoading, isTrue);
      expect(_button(tester, SwapSheet.backKey).isDisabled, isTrue);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.tap(find.byKey(ShellSheetHeader.closeGlyphKey));
      await tester.pump();
      expect(find.byType(SwapSheet), findsOneWidget);

      order.completeError(const SwapApiException(503, 'down'));
      await tester.pumpAndSettle();

      expect(_text(tester, SwapSheet.noticeKey), _l10n.swapQuoteError('down'));
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(SwapSheet), findsNothing);
    });
  });

  group('confirming, with the deposit going out', () {
    testOnMac("the way back in the sheet's title does nothing: the review stays until the deposit has landed, and "
        'its swap is followed', (tester) async {
      final landing = Completer<String>();
      final chain = FakeSendChain()..submit = () => landing.future;
      final settings = FakeSettingsService(activeAccount: const RegularAccount(mainAccount));
      final swaps = await _openSheet(tester, chain: chain, settings: settings);
      await _openReview(tester);

      await tester.tap(_key(SwapSheet.confirmKey));
      // Approved, and handed to the chain, which has not answered.
      await tester.pump();
      await tester.pump();
      expect(_button(tester, SwapSheet.confirmKey).isLoading, isTrue);

      await tester.tap(find.byKey(ShellSheetHeader.backKey));
      await tester.pump();

      // Still the review: no form to cancel from, or to start another swap on.
      expect(_key(SwapSheet.confirmKey), findsOneWidget);
      expect(_key(SwapSheet.amountFieldKey), findsNothing);
      expect(_key(SwapSheet.cancelKey), findsNothing);

      landing.complete('0xhash');
      await tester.pumpAndSettle();

      expect(find.byType(SwapSheet), findsNothing);
      expect(swaps.created, hasLength(1));
      expect(settings.activeSwap?.depositTxHash, '0xhash');
      expect(find.byType(SwapRowView), findsOneWidget);
    });
  });

  group('room', () {
    testOnMac('nothing overflows in the smallest window: the form, the token list, the review', (tester) async {
      final swaps = FakeSwapService();
      swaps.quote = (request) async => fakeQuoteFor(request, withdrawFee: BigInt.from(20000), feeBps: 30);
      await _openSheet(tester, swaps: swaps, window: const Size(960, 640));
      await _typeAmount(tester, '250');
      await _typeAddress(tester, _otherAddress);
      await _rest(tester);
      expect(tester.takeException(), isNull);

      await _press(tester, SwapSheet.tokenButtonKey);
      expect(tester.takeException(), isNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      await _press(tester, SwapSheet.reviewKey);
      expect(_key(SwapSheet.confirmKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
