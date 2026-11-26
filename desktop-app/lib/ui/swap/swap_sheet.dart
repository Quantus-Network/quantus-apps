import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_desktop_wallet/providers/activity_providers.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/ui/activity/inspector_parts.dart';
import 'package:quantus_desktop_wallet/ui/components/account_label.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/context_menu.dart';
import 'package:quantus_desktop_wallet/ui/components/desktop_checkbox.dart';
import 'package:quantus_desktop_wallet/ui/components/notice_box.dart';
import 'package:quantus_desktop_wallet/ui/components/pop_up_button.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/summary_row.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_form_parts.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/ui/swap/swap_form_parts.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/active_swaps_provider.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/remote_config_provider.dart';
import 'package:wallet_core/providers/swap_providers.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/user_approval.dart';
import 'package:wallet_core/swap/swap_confirmation.dart';
import 'package:wallet_core/swap/swap_form.dart';
import 'package:wallet_core/swap/swap_review.dart';
import 'package:wallet_core/utils/account_utils.dart';

enum _Step { form, review }

/// What a swap out draws on: the account's balance, the most of it that can
/// go in once the deposit's fee is known, and that fee's own state.
typedef _Funds = ({AsyncValue<BigInt> balance, BigInt? max, AsyncValue<BigInt>? fee, (Account, BigInt)? feeKey});

/// Starts a swap between QTC in the active account and a token on another
/// chain, either way: the form, then the review of its quote. Once the swap
/// is confirmed the sheet closes, and the swap is followed in the window.
///
/// Only a transparent account whose key signs here swaps. Where swaps are
/// not allowed, while as many run as can be followed, until 1Click lists QTC
/// with a price, or when 1Click cannot be reached, the form gives way to a
/// notice.
class SwapSheet extends ConsumerStatefulWidget {
  const SwapSheet({super.key});

  static const amountFieldKey = Key('swap-amount');
  static const otherAmountKey = Key('swap-other-amount');
  static const payBoxKey = Key('swap-pay');
  static const receiveBoxKey = Key('swap-receive');
  static const flipKey = Key('swap-flip');
  static const tokenButtonKey = Key('swap-token');
  static const tokenSearchKey = Key('swap-token-search');
  static const tokenListKey = Key('swap-token-list');
  static const maxKey = Key('swap-max');
  static const addressFieldKey = Key('swap-address');
  static const pasteKey = Key('swap-paste');
  static const slippageKey = Key('swap-slippage');
  static const customSlippageKey = Key('swap-custom-slippage');
  static const retryFeeKey = Key('swap-retry-fee');
  static const problemKey = Key('swap-problem');
  static const noticeKey = Key('swap-notice');
  static const tryAgainKey = Key('swap-try-again');
  static const cancelKey = Key('swap-cancel');
  static const reviewKey = Key('swap-review');
  static const backKey = Key('swap-back');
  static const confirmKey = Key('swap-confirm');
  static const closeKey = Key('swap-close');
  static const savedListKey = Key('swap-saved');
  static const saveAddressKey = Key('swap-save-address');
  static const savedProblemKey = Key('swap-saved-problem');

  /// A token's row in the list.
  static Key tokenRowKey(String assetId) => ValueKey('swap-token-$assetId');

  /// A saved address's row.
  static Key savedRowKey(String address) => ValueKey('swap-saved-$address');

  @override
  ConsumerState<SwapSheet> createState() => _SwapSheetState();
}

class _SwapSheetState extends ConsumerState<SwapSheet> {
  /// The tolerance the pop-up stands on while one is typed.
  static const _customSlippage = -1;

  /// The sheet opens on the active account and stays on it while it is open.
  late final Account _account;

  final _amount = TextEditingController();
  final _amountFocus = FocusNode();
  final _address = TextEditingController();
  final _addressFocus = FocusNode();
  final _slippage = TextEditingController();
  final _slippageFocus = FocusNode();

  /// Holds the keyboard's focus on the review, which has no field, so the
  /// sheet's keys still reach it.
  final _stepFocus = FocusNode(skipTraversal: true);
  final _tokenButton = GlobalKey();

  _Step _step = _Step.form;

  List<SwapToken> _tokens = const [];
  SwapToken? _foreign;
  SwapToken? _quantus;
  bool _loadingTokens = true;
  bool _loadFailed = false;

  /// Counts the loads of the tokens, so one a newer load has overtaken is
  /// dropped: a listing fetched before a config change never comes back.
  int _loads = 0;

  /// A swap out of QTC pays from the account; a swap in pays into it.
  bool _swapOut = true;

  /// Whether the amount typed is what the lower side receives, the upper
  /// side then paying what it costs, rather than what the upper side pays.
  bool _exactOutput = false;

  /// Whether the amount is the most the account can put in, and follows it.
  bool _isMax = false;

  /// Whether a tolerance of the person's own is being typed, and what is
  /// wrong with the one in the field.
  bool _typesSlippage = false;
  String? _slippageProblem;

  /// Whether the review is waiting for the form's quote.
  bool _quoting = false;

  /// Bumped on every change to what a quote is for, so a quote the form
  /// moved past while it was out opens nothing.
  int _edits = 0;

  /// The read of the clipboard that Paste is waiting on, if any.
  Object? _pendingPaste;

  /// The addresses saved on the other chain's network, most recent first,
  /// and what kept them from being read, added to or removed from.
  List<String> _saved = const [];
  String? _savedProblem;

  /// Counts the reads of the saved addresses, so one for a chain the form
  /// has left is dropped.
  int _savedLoads = 0;

  /// Whether the address typed is to be saved once its swap is reviewed.
  bool _savesAddress = false;

  /// The quote under review; the live one's terms replace it when they are
  /// worse.
  SwapQuote? _reviewed;

  /// Confirms what is under review. It lives as long as that review does: a
  /// live order it keeps is for that review's swap, and no other's.
  SwapConfirmation? _confirmation;
  bool _confirming = false;

  /// Why the last confirmation started nothing; a caution when the terms
  /// only changed.
  String? _notice;
  bool _noticeIsCaution = false;

  @override
  void initState() {
    super.initState();
    final active = ref.read(activeAccountProvider).value;
    if (active is! RegularAccount || !active.account.signsLocally) {
      throw StateError('Swap was opened on an account that cannot swap: $active');
    }
    _account = active.account;
    _amount.addListener(_edited);
    _address.addListener(_edited);
    _amountFocus.addListener(_redraw);
    unawaited(_loadTokens());
  }

  @override
  void dispose() {
    _amount.dispose();
    _amountFocus.dispose();
    _address.dispose();
    _addressFocus.dispose();
    _slippage.dispose();
    _slippageFocus.dispose();
    _stepFocus.dispose();
    super.dispose();
  }

  void _edited() => setState(() => _edits++);

  void _redraw() => setState(() {});

  /// Loads the tokens from the service of the moment. The form waits for
  /// them.
  Future<void> _loadTokens({bool forceRefresh = false}) async {
    final load = ++_loads;
    if (mounted) {
      setState(() {
        _loadingTokens = true;
        _loadFailed = false;
        _quantus = null;
      });
    }
    try {
      final service = ref.read(swapServiceProvider);
      final tokens = await service.getFromTokens(forceRefresh: forceRefresh);
      final quantus = await service.getListedQuantusToken();
      if (!mounted || load != _loads) return;
      setState(() {
        _tokens = tokens;
        _foreign ??= tokens.firstWhere((token) => !token.isQuantus);
        _quantus = quantus;
      });
      unawaited(_loadSaved(_foreign!.network));
    } catch (e) {
      quantusPrint('Swap tokens failed to load: $e');
      if (mounted && load == _loads) setState(() => _loadFailed = true);
    } finally {
      if (mounted && load == _loads) setState(() => _loadingTokens = false);
    }
  }

  /// Whether the form is on [network]: what is known of the addresses saved
  /// on another chain is not this form's to show.
  bool _isOn(String network) => mounted && _foreign?.network == network;

  /// Reads the addresses saved on [network]. What cannot be read is said,
  /// and the form goes on without them. A read for a chain the form has
  /// left, or one a newer read has overtaken, changes nothing.
  Future<void> _loadSaved(String network) async {
    final load = ++_savedLoads;
    try {
      final saved = await ref.read(swapServiceProvider).getSavedAddresses(network);
      if (!_isOn(network) || load != _savedLoads) return;
      setState(() => _saved = saved);
    } catch (e) {
      quantusPrint('Saved swap addresses failed to load: $e');
      if (!_isOn(network) || load != _savedLoads) return;
      setState(() {
        _saved = const [];
        _savedProblem = ref.read(l10nProvider).desktopSwapSavedAddressesUnavailable('$e');
      });
    }
  }

  /// Forgets [address] on [network]. One that cannot be removed is said, and
  /// stays. Once the form has moved to another chain, how the removal ended
  /// is no longer shown: neither its failure nor the list it leaves.
  Future<void> _removeSaved(String network, String address) async {
    try {
      await ref.read(swapServiceProvider).removeSavedAddress(network, address);
    } catch (e) {
      quantusPrint('Saved swap address failed to be removed: $e');
      if (_isOn(network)) {
        setState(() => _savedProblem = ref.read(l10nProvider).desktopSwapSavedAddressesUnavailable('$e'));
      }
      return;
    }
    if (!_isOn(network)) return;
    setState(() => _savedProblem = null);
    await _loadSaved(network);
  }

  void _setSavesAddress(bool saves) => setState(() {
    _savesAddress = saves;
    // What a save could not do no longer stands in the way.
    if (!saves) _savedProblem = null;
  });

  // ------------------------------------------------------- what the form says

  /// The external address in the field; null while there is none.
  String? get _externalAddress {
    final address = _address.text.trim();
    return address.isEmpty ? null : address;
  }

  /// The amount typed, in base units of the side it is typed on.
  BigInt _typed(SwapToken from, SwapToken to) => swapTypedAmount(
    ref.read(numberFormattingServiceProvider),
    _amount.text,
    from: from,
    to: to,
    exactOutput: _exactOutput,
  );

  (BigInt, BigInt) _amounts(SwapToken from, SwapToken to, SwapQuote? quote) =>
      swapFormAmountsOf(typed: _typed(from, to), from: from, to: to, exactOutput: _exactOutput, quote: quote);

  SwapQuoteRequest? _request(SwapToken from, SwapToken to) => swapQuoteRequestOf(
    from: from,
    to: to,
    swapOut: _swapOut,
    typed: _typed(from, to),
    exactOutput: _exactOutput,
    address: _externalAddress,
    own: ref.read(swapPreflightProvider)?.address ?? _account.accountId,
    slippageBps: ref.read(swapSlippageBpsProvider),
  );

  /// [amount] of [token] as it is typed into the field.
  String _amountText(BigInt amount, SwapToken token) => ref
      .read(numberFormattingServiceProvider)
      .formatBalance(amount, decimals: token.decimals, maxDecimals: token.decimals, addThousandsSeparators: false);

  /// Whether the app sends the deposit itself: a swap out, unless the
  /// preflight's stand-in is paid by hand.
  bool get _sendsDeposit => _swapOut && ref.read(swapPreflightProvider) == null;

  /// Null when the other side pays.
  _Funds? _funds({required bool watch}) {
    if (!_sendsDeposit) return null;
    T get<T>(ProviderListenable<T> provider) => watch ? ref.watch(provider) : ref.read(provider);
    final balance = get(effectiveBalanceProviderFamily(_account.accountId));
    final spendable = balance.value;
    if (spendable == null) return (balance: balance, max: null, fee: null, feeKey: null);
    final key = (_account, spendable);
    final fee = get(swapDepositFeeProvider(key));
    final feeValue = fee.value;
    return (balance: balance, max: feeValue == null ? null : swapMaxIn(spendable, feeValue), fee: fee, feeKey: key);
  }

  // ------------------------------------------------------ what the form does

  void _flip() {
    setState(() {
      _swapOut = !_swapOut;
      _exactOutput = false;
      _isMax = false;
      _edits++;
    });
    _amount.clear();
  }

  /// Moves typing to the other side, starting from the amount shown there,
  /// selected so that typing replaces it.
  void _typeOtherSide(SwapToken from, SwapToken to, SwapQuote? quote) {
    final (amountIn, amountOut) = _amounts(from, to, quote);
    final token = _exactOutput ? from : to;
    final shown = _exactOutput ? amountIn : amountOut;
    final text = shown == BigInt.zero ? '' : _amountText(shown, token);
    setState(() => _exactOutput = !_exactOutput);
    _amount.value = TextEditingValue(
      text: text,
      selection: TextSelection(baseOffset: 0, extentOffset: text.length),
    );
    _amountFocus.requestFocus();
  }

  void _setMax(bool isMax) {
    setState(() {
      _isMax = isMax;
      if (isMax) _exactOutput = false;
    });
    _followMax();
  }

  /// Keeps a maximum amount on the most the account can put in, which moves
  /// with its balance and the deposit's fee.
  void _followMax() {
    if (!_isMax) return;
    final quantus = _quantus;
    final max = _funds(watch: false)?.max;
    if (quantus == null || max == null) return;
    final text = _amountText(max, quantus);
    if (_amount.text != text) _amount.text = text;
  }

  Future<void> _paste() async {
    final paste = _pendingPaste = Object();
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim() ?? '';
    // An answer that comes once the form was left, or after a later press of
    // Paste, is no longer the one that was asked for.
    if (!mounted || paste != _pendingPaste) return;
    _pendingPaste = null;
    if (text.isEmpty) return;
    _address.text = text;
  }

  /// Picks the other chain's token. QTC heads the list: picking it turns the
  /// swap around.
  Future<void> _pickToken(AppLocalizations l10n, SwapToken tapped) async {
    final picked = await showSwapTokenList(
      _tokenButton.currentContext!,
      tokens: _tokens,
      current: tapped,
      searchHint: l10n.swapTokenPickerSearchHint,
      noMatch: l10n.swapTokenPickerNoMatch,
      searchKey: SwapSheet.tokenSearchKey,
      listKey: SwapSheet.tokenListKey,
      rowKey: (token) => SwapSheet.tokenRowKey(token.assetId),
    );
    if (picked == null || !mounted) return;
    final pick = swapTokenPickOf(tapped: tapped, picked: picked, foreign: _foreign);
    if (pick == null) return;
    final foreign = pick.foreign;
    if (foreign != null) {
      final movesChain = foreign.network != _foreign?.network;
      setState(() {
        _foreign = foreign;
        _edits++;
        // Another chain has its own saved addresses.
        if (movesChain) {
          _saved = const [];
          _savedProblem = null;
          _savesAddress = false;
        }
      });
      if (pick.clearsAddress) _address.clear();
      if (movesChain) unawaited(_loadSaved(foreign.network));
    }
    if (pick.flips) _flip();
  }

  void _pickSlippage(int bps) {
    if (bps == _customSlippage) {
      setState(() => _typesSlippage = true);
      _slippage.text = slippagePercentLabel(ref.read(swapSlippageBpsProvider));
      _slippageFocus.requestFocus();
      return;
    }
    setState(() {
      _typesSlippage = false;
      _slippageProblem = null;
      _edits++;
    });
    ref.read(swapSlippageBpsProvider.notifier).state = bps;
  }

  /// Takes the tolerance typed once it is one; past the most allowed it is
  /// said, and the tolerance in use stays.
  void _onSlippageTyped(AppLocalizations l10n, String text) {
    final percent = ref.read(numberFormattingServiceProvider).parseAmount(text, decimals: 2);
    if (percent == null || percent == BigInt.zero) {
      setState(() => _slippageProblem = null);
      return;
    }
    final bps = percent.toInt();
    if (bps > swapSlippageMaxBps) {
      setState(() => _slippageProblem = l10n.swapSlippageCustomMax(slippagePercentLabel(swapSlippageMaxBps)));
      return;
    }
    setState(() {
      _slippageProblem = null;
      _edits++;
    });
    ref.read(swapSlippageBpsProvider.notifier).state = bps;
  }

  /// Opens the review of the form's quote for [request], waiting for it
  /// while it is out, and asking again for one that failed. The form takes
  /// no input meanwhile. A quote that fails is said on the form. An address
  /// to be saved is saved first, on [network]: where that fails it is said,
  /// and the review stays shut.
  Future<void> _openReview(SwapQuoteRequest request, {required String network}) async {
    if (_quoting) return;
    final provider = swapFormQuoteProvider(request);
    if (ref.read(provider).hasError) ref.invalidate(provider);
    final edits = _edits;
    setState(() => _quoting = true);
    final quoted = ref.listenManual(provider.future, (_, _) {});
    try {
      final quote = await quoted.read();
      if (!mounted || edits != _edits) return;
      final external = _externalAddress;
      if (_savesAddress && external != null && !_saved.contains(external)) {
        try {
          await ref.read(swapServiceProvider).saveAddress(network, external);
        } catch (e) {
          quantusPrint('Swap address failed to be saved: $e');
          if (mounted) {
            setState(() => _savedProblem = ref.read(l10nProvider).desktopSwapSavedAddressesUnavailable('$e'));
          }
          return;
        }
        if (!mounted || edits != _edits) return;
        _savesAddress = false;
        _savedProblem = null;
        unawaited(_loadSaved(network));
      }
      setState(() {
        _reviewed = quote;
        _confirmation = SwapConfirmation(account: _account);
        _notice = null;
        _step = _Step.review;
      });
      _stepFocus.requestFocus();
    } catch (e) {
      // The form says it: it shows what became of its quote.
      quantusPrint('The swap quote to review failed: $e');
    } finally {
      quoted.close();
      if (mounted) setState(() => _quoting = false);
    }
  }

  /// Back to the form, by whichever way: the button, the keys, or the path
  /// in the sheet's title. Not while a swap is being confirmed: its deposit
  /// may be going out, and the form would let the sheet be closed, or another
  /// swap be started, under it.
  void _backToForm() {
    if (_confirming) return;
    setState(() {
      _step = _Step.form;
      _reviewed = null;
      _confirmation = null;
      _notice = null;
    });
  }

  // -------------------------------------------------- what the review does

  /// Confirms the terms shown, and says how it went: the sheet gives way to
  /// the swap in the window, live terms that are worse replace the ones
  /// shown, and what stopped it otherwise is said in place.
  Future<void> _confirm(SwapQuote quote) async {
    final l10n = ref.read(l10nProvider);
    final confirmation = _confirmation;
    if (confirmation == null) throw StateError('A swap was confirmed with no review open.');
    setState(() {
      _confirming = true;
      _notice = null;
    });
    try {
      final outcome = await confirmation.confirm(
        ref,
        quote,
        isActive: () => mounted && identical(confirmation, _confirmation),
      );
      if (!mounted) return;
      switch (outcome) {
        case SwapConfirmed(:final swap):
          ref.read(openedActivityProvider.notifier).open(OpenedSwap(swap.id));
          Navigator.of(context).pop();
        case SwapConfirmDropped():
          break;
        case SwapTooManyFollowed():
          _say(l10n.swapTooManyFollowed(ActiveSwapsNotifier.maxFollowed));
        case SwapTermsChanged(:final quote):
          setState(() {
            _reviewed = quote;
            _notice = l10n.swapReviewPriceMoved;
            _noticeIsCaution = true;
          });
        case SwapListingChanged():
          _say(l10n.swapReviewListingChanged);
        case SwapNotAllowed():
          _say(l10n.swapDisabledTitle);
        case SwapQuoteRefused(:final message):
          _say(l10n.swapQuoteError(message));
        case SwapApprovalRequired():
          _say(l10n.sendReviewAuthRequired);
        case SwapDepositFailed():
          _say(l10n.sendReviewSubmitFailed);
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _say(String problem) => setState(() {
    _notice = problem;
    _noticeIsCaution = false;
  });

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    ref.listen(swapServiceProvider, (_, _) {
      _confirmation?.serviceRebuilt();
      unawaited(_loadTokens());
    });
    final l10n = ref.watch(l10nProvider);
    final available = ref.watch(remoteConfigProvider.select((config) => config.swapAvailable));
    final foreign = _foreign;
    final quantus = _quantus;
    final atLimit = ref.watch(swapsAtLimitProvider);
    final isReview = _step == _Step.review;
    final List<Widget> content;
    if (isReview) {
      content = _review(l10n, available: available);
    } else if (!available) {
      content = _unavailable(l10n, disabled: true);
    } else if (atLimit) {
      content = _limitReached(l10n);
    } else if (foreign == null || quantus == null) {
      content = _unavailable(l10n, disabled: false);
    } else {
      content = _form(l10n, quantus, foreign);
    }

    return PopScope(
      canPop: !_confirming,
      child: SheetBackShortcut(
        onBack: isReview && !_confirming ? _backToForm : null,
        child: Focus(
          focusNode: _stepFocus,
          skipTraversal: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShellSheetHeader(
                title: isReview ? l10n.desktopSendReview : l10n.swapTitle,
                account: _account,
                parent: isReview ? (title: l10n.swapTitle, onBack: _backToForm) : null,
              ),
              ...content,
            ],
          ),
        ),
      ),
    );
  }

  Widget _attribution(AppLocalizations l10n) => Text(
    l10n.desktopSwapPoweredByNearIntents,
    style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted2),
  );

  // ------------------------------------------------- in place of the form

  Widget _close(AppLocalizations l10n) => SheetButton(
    key: SwapSheet.closeKey,
    label: l10n.commonClose,
    kind: SheetButtonKind.secondary,
    // Asked, not told, as the cross in the title is: a sheet that is
    // confirming a swap stays.
    onTap: () => unawaited(Navigator.of(context).maybePop()),
  );

  /// What stands in place of the form: [title] as a status, what [body] adds
  /// to it, and Close, with [action] across from it when there is one.
  List<Widget> _inPlaceOfForm(AppLocalizations l10n, {required String title, String? body, Widget? action}) {
    final colors = context.colorsV3;
    return [
      const SizedBox(height: 26),
      inspectorStatusLine(
        context,
        mark: Icon(CupertinoIcons.exclamationmark_circle, size: 13, color: colors.semanticEmber),
        label: title,
        color: colors.semanticEmber,
      ),
      if (body != null) ...[
        const SizedBox(height: 14),
        Text(body, style: context.themeTextV3.body.copyWith(color: colors.textContent)),
      ],
      const SizedBox(height: 22),
      Row(children: [?action, const Spacer(), _close(l10n)]),
    ];
  }

  /// In place of the form: that the tokens are loading; that swaps are
  /// disabled, where they are for this location or while 1Click does not
  /// list QTC with a price, saying nothing about why or when; or that 1Click
  /// cannot be reached, with a way to ask again.
  List<Widget> _unavailable(AppLocalizations l10n, {required bool disabled}) {
    if (_loadingTokens && !disabled) {
      return [
        const SizedBox(height: 26),
        Row(
          children: [
            const Loader(size: 12),
            const SizedBox(width: 10),
            Text(l10n.desktopSwapLoadingTokens, style: context.sendBody()),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Expanded(child: _attribution(l10n)),
            _close(l10n),
          ],
        ),
      ];
    }
    if (disabled || !_loadFailed) return _inPlaceOfForm(l10n, title: l10n.swapDisabledTitle);
    return _inPlaceOfForm(
      l10n,
      title: l10n.swapUnavailableTitle,
      body: l10n.swapUnavailableUnreachable,
      action: ToolbarAction.symbol(
        key: SwapSheet.tryAgainKey,
        symbol: CupertinoIcons.arrow_clockwise,
        label: l10n.commonTryAgain,
        onPressed: () => unawaited(_loadTokens(forceRefresh: true)),
      ),
    );
  }

  /// In place of the form while as many swaps run as can be followed: that
  /// no other can start until one of them finishes. The form takes its place
  /// again as soon as one has, or is put away.
  List<Widget> _limitReached(AppLocalizations l10n) => _inPlaceOfForm(
    l10n,
    title: l10n.swapUnavailableTitle,
    body: l10n.swapTooManyFollowed(ActiveSwapsNotifier.maxFollowed),
  );

  // --------------------------------------------------------------- the form

  TextStyle _amountStyle(Color color) =>
      context.themeTextV3.titleScreen.copyWith(color: color, fontFeatures: const [FontFeature.tabularFigures()]);

  List<Widget> _form(AppLocalizations l10n, SwapToken quantus, SwapToken foreign) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final funds = _funds(watch: true);
    // A maximum follows what it is the most of.
    ref.listen(effectiveBalanceProviderFamily(_account.accountId), (_, _) => _followMax());
    final feeKey = funds?.feeKey;
    if (feeKey != null) ref.listen(swapDepositFeeProvider(feeKey), (_, _) => _followMax());

    final from = _swapOut ? quantus : foreign;
    final to = _swapOut ? foreign : quantus;
    final request = _request(from, to);
    final quoted = request == null ? null : ref.watch(swapFormQuoteProvider(request));
    final quote = quoted == null || quoted.hasError ? null : quoted.value;
    final quoteError = quoted?.error;
    final (amountIn, amountOut) = _amounts(from, to, quote);
    final priced = from.usdPrice > 0 && to.usdPrice > 0;
    final preflight = ref.watch(swapPreflightProvider);
    final sendsDeposit = _swapOut && preflight == null;

    final max = funds?.max;
    final action = swapFormActionOf(
      amountIn: amountIn,
      amountOut: amountOut,
      canPay: max ?? funds?.balance.value,
      hasAddress: _externalAddress != null,
    );
    // A swap whose deposit the app sends needs this computer's approval.
    final availability = sendsDeposit ? ref.watch(approvalAvailabilityProvider) : null;
    final approvalNote = switch (availability) {
      AsyncData(:final value) => approvalUnavailableNote(l10n, value),
      AsyncError(:final error) => l10n.desktopApprovalFailed('$error'),
      _ => null,
    };
    final canApprove = availability == null || availability.value == ApprovalAvailability.available;
    final feeFailed = funds?.fee?.hasError ?? false;
    final problem = action.step == SwapFormStep.insufficient
        ? l10n.sendLogicInsufficientBalance
        : feeFailed
        ? l10n.swapReviewFeeFailed
        : null;
    void typeOtherSide() => _typeOtherSide(from, to, quote);

    final owner = funds == null
        ? _account.name
        : l10n.desktopSwapAccountAvailable(
            _account.name,
            max != null
                ? formatSwapAmount(l10n, fmt, max, quantus)
                : funds.balance.hasError || feeFailed
                ? '—'
                : '…',
          );
    Widget tokenOf(SwapToken token) => token.isQuantus
        ? SwapTokenLabel(token: token)
        : SwapTokenButton(
            key: SwapSheet.tokenButtonKey,
            token: token,
            semanticLabel: token == from ? l10n.swapTokenPickerPayWith : l10n.swapTokenPickerReceive,
            onPressed: () => unawaited(_pickToken(l10n, token)),
          );
    Widget amountOf({required bool isTyped, required SwapToken token, required BigInt amount}) => isTyped
        ? _amountField(token)
        : _otherAmount(
            fmt.formatAmount(amount, decimals: token.decimals),
            isEstimate: quote == null && amount > BigInt.zero,
            isEmpty: amount == BigInt.zero,
            onPressed: _isMax ? null : typeOtherSide,
          );

    return [
      const SizedBox(height: 16),
      Flexible(
        child: AbsorbPointer(
          absorbing: _quoting,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (preflight != null) ...[
                  NoticeBox(
                    tone: colors.semanticSand,
                    symbol: CupertinoIcons.exclamationmark_triangle,
                    child: Text(
                      l10n.swapPreflightBanner(quantus.symbol, quantus.networkName),
                      style: text.body.copyWith(color: colors.textContent),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwapSideBox(
                          key: SwapSheet.payBoxKey,
                          label: l10n.swapYouPay,
                          owner: _swapOut ? owner : l10n.swapExternalWallet,
                          amount: amountOf(isTyped: !_exactOutput, token: from, amount: amountIn),
                          usd: _usd(amountIn, from),
                          token: KeyedSubtree(key: from.isQuantus ? null : _tokenButton, child: tokenOf(from)),
                          isActive: !_exactOutput && _amountFocus.hasFocus,
                        ),
                        const SizedBox(height: 6),
                        SwapSideBox(
                          key: SwapSheet.receiveBoxKey,
                          label: l10n.swapYouReceive,
                          owner: _swapOut ? l10n.swapExternalWallet : _account.name,
                          amount: amountOf(isTyped: _exactOutput, token: to, amount: amountOut),
                          usd: _usd(amountOut, to),
                          token: KeyedSubtree(key: to.isQuantus ? null : _tokenButton, child: tokenOf(to)),
                          isActive: _exactOutput && _amountFocus.hasFocus,
                        ),
                      ],
                    ),
                    _FlipButton(key: SwapSheet.flipKey, label: '${l10n.swapFrom} ⇄ ${l10n.swapTo}', onPressed: _flip),
                  ],
                ),
                if (problem != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          problem,
                          key: SwapSheet.problemKey,
                          style: text.caption.copyWith(color: colors.semanticEmber),
                        ),
                      ),
                      if (feeFailed && feeKey != null) ...[
                        const SizedBox(width: 8),
                        ToolbarAction.symbol(
                          key: SwapSheet.retryFeeKey,
                          symbol: CupertinoIcons.arrow_clockwise,
                          label: l10n.homeActivityRetry,
                          onPressed: () => ref.invalidate(swapDepositFeeProvider(feeKey)),
                        ),
                      ],
                    ],
                  ),
                ],
                if (funds != null) ...[
                  const SizedBox(height: 8 - DesktopCheckbox.boxInset),
                  // The box on the content's edge, under the start of the
                  // boxes above.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Transform.translate(
                      offset: const Offset(-DesktopCheckbox.boxInset, 0),
                      child: DesktopCheckbox(
                        key: SwapSheet.maxKey,
                        value: _isMax,
                        label: l10n.desktopSwapMaximum,
                        onChanged: max == null ? null : _setMax,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10 - DesktopCheckbox.boxInset),
                ] else
                  const SizedBox(height: 14),
                SendFieldLabel(
                  label: _swapOut
                      ? l10n.desktopSwapRecipientAddressOn(foreign.networkName)
                      : l10n.desktopSwapRefundAddressOn(foreign.networkName),
                  actions: [
                    ToolbarAction.symbol(
                      key: SwapSheet.pasteKey,
                      symbol: CupertinoIcons.doc_on_clipboard,
                      label: l10n.desktopImportPaste,
                      onPressed: () => unawaited(_paste()),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SendField(
                  key: SwapSheet.addressFieldKey,
                  controller: _address,
                  focusNode: _addressFocus,
                  hint: l10n.swapAddressHint(foreign.networkName),
                  style: context.sendMono(colors.textWhite),
                  onSubmitted: (_) => _pressReview(action, request, foreign),
                ),
                ..._savedAddresses(l10n, foreign),
                const SizedBox(height: 8),
                Text(
                  _swapOut
                      ? l10n.swapRecipientAddressNotice(foreign.symbol)
                      : l10n.swapRefundAddressNotice(foreign.symbol, foreign.networkName),
                  style: text.caption.copyWith(color: colors.textMuted2),
                ),
                const SizedBox(height: 14),
                _terms(l10n, fmt, quantus, foreign, quote: quote, priced: priced),
                const SizedBox(height: 6),
                if (quote != null)
                  for (final row in swapQuoteFeeRowsOf(l10n, fmt, quote)) _termLine(row.label, row.value)
                else if (quoteError != null)
                  Text(
                    l10n.swapQuoteError(describeSwapError(l10n, quoteError)),
                    style: text.caption.copyWith(color: colors.semanticEmber),
                  )
                else if (priced)
                  Text(l10n.swapEstimateNotice, style: text.caption.copyWith(color: colors.textMuted2)),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: approvalNote == null ? _attribution(l10n) : Text(approvalNote, style: context.sendBody()),
            ),
          ),
          SheetButton(
            key: SwapSheet.cancelKey,
            label: l10n.commonCancel,
            kind: SheetButtonKind.secondary,
            onTap: () => unawaited(Navigator.of(context).maybePop()),
          ),
          const SizedBox(width: 10),
          SheetButton(
            key: SwapSheet.reviewKey,
            label: l10n.desktopSendReview,
            isLoading: _quoting,
            isDisabled: !action.isEnabled || !canApprove,
            onTap: () => _pressReview(action, request, foreign),
          ),
        ],
      ),
    ];
  }

  /// What Review does: asks for the address while there is none, else opens
  /// the review.
  void _pressReview(SwapFormAction action, SwapQuoteRequest? request, SwapToken foreign) {
    if (!action.isEnabled) return;
    switch (action.step) {
      case SwapFormStep.insufficient:
        return;
      case SwapFormStep.addAddress:
        _addressFocus.requestFocus();
      case SwapFormStep.review:
        if (request != null) unawaited(_openReview(request, network: foreign.network));
    }
  }

  /// Under the address field: what kept the saved addresses from being used;
  /// while the field is empty, the addresses saved on [foreign]'s chain, a
  /// press picking one and its menu forgetting it; and for an address typed
  /// that is not among them, whether to save it.
  List<Widget> _savedAddresses(AppLocalizations l10n, SwapToken foreign) {
    final colors = context.colorsV3;
    final external = _externalAddress;
    final problem = _savedProblem;

    return [
      if (problem != null) ...[
        const SizedBox(height: 6),
        Text(
          problem,
          key: SwapSheet.savedProblemKey,
          style: context.themeTextV3.caption.copyWith(color: colors.semanticEmber),
        ),
      ],
      if (external == null && _saved.isNotEmpty) ...[
        const SizedBox(height: 12),
        CapsText(l10n.swapSavedAddressesTitle, style: context.sendCaps()),
        const SizedBox(height: 6),
        // A few are in sight; the rest scroll within the list.
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 116),
          child: ListView(
            key: SwapSheet.savedListKey,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            children: [
              for (final address in _saved)
                ContextMenuRegion(
                  items: () => [
                    ContextMenuItem(
                      l10n.desktopSwapRemoveSavedAddress,
                      isDestructive: true,
                      onSelected: () => unawaited(_removeSaved(foreign.network, address)),
                    ),
                  ],
                  child: SendRecentRow(
                    key: SwapSheet.savedRowKey(address),
                    address: address,
                    showsCheckphrase: false,
                    onPressed: () {
                      // A Control-click opened the menu; it picks nothing.
                      if (ContextMenuRegion.isControlClick) return;
                      _address.text = address;
                    },
                  ),
                ),
            ],
          ),
        ),
      ] else if (external != null && !_saved.contains(external)) ...[
        const SizedBox(height: 10 - DesktopCheckbox.boxInset),
        Align(
          alignment: Alignment.centerLeft,
          child: Transform.translate(
            offset: const Offset(-DesktopCheckbox.boxInset, 0),
            child: DesktopCheckbox(
              key: SwapSheet.saveAddressKey,
              value: _savesAddress,
              label: l10n.swapSaveAddress,
              onChanged: _setSavesAddress,
            ),
          ),
        ),
      ],
    ];
  }

  String _usd(BigInt amount, SwapToken token) => '\$${swapUsdValue(amount, token).toStringAsFixed(2)}';

  /// The field of the side typed on.
  Widget _amountField(SwapToken token) {
    final colors = context.colorsV3;

    return Opacity(
      opacity: _isMax ? 0.5 : 1,
      child: TextField(
        key: SwapSheet.amountFieldKey,
        controller: _amount,
        focusNode: _amountFocus,
        enabled: !_isMax,
        maxLines: 1,
        style: _amountStyle(colors.textWhite),
        cursorColor: colors.accentFlare,
        decoration: InputDecoration.collapsed(hintText: '0', hintStyle: _amountStyle(colors.textMuted2)),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          DecimalInputFilter(localeConfig: ref.watch(localeNumberConfigProvider), maxDecimalPlaces: token.decimals),
        ],
      ),
    );
  }

  /// The side not typed on: its amount as quoted, or dimmed and marked while
  /// it is only an estimate at listed prices. A press moves typing there.
  Widget _otherAmount(
    String amount, {
    required bool isEstimate,
    required bool isEmpty,
    required VoidCallback? onPressed,
  }) {
    final colors = context.colorsV3;
    final color = isEmpty
        ? colors.textMuted2
        : isEstimate
        ? colors.textMuted
        : colors.textWhite;

    return Align(
      alignment: Alignment.centerLeft,
      child: FocusableActionDetector(
        enabled: onPressed != null,
        mouseCursor: onPressed == null ? MouseCursor.defer : SystemMouseCursors.text,
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => onPressed?.call())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Text(
            estimateLabel(amount, estimate: isEstimate),
            key: SwapSheet.otherAmountKey,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _amountStyle(color),
          ),
        ),
      ),
    );
  }

  /// The rate at the line's start, an estimate until the quote is in, and
  /// the slippage tolerance at its end.
  Widget _terms(
    AppLocalizations l10n,
    NumberFormattingService fmt,
    SwapToken quantus,
    SwapToken foreign, {
    required SwapQuote? quote,
    required bool priced,
  }) {
    final bps = ref.watch(swapSlippageBpsProvider);
    final oneQuantus = BigInt.from(10).pow(quantus.decimals);
    final problem = _slippageProblem;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: quote == null && !priced
                  ? const SizedBox.shrink()
                  : Text(
                      (quote != null ? l10n.swapRateLabel : l10n.swapRateEstimateLabel)(
                        quantus.symbol,
                        fmt.formatAmount(
                          quote != null ? swapQuoteRate(quote) : swapEstimateOut(oneQuantus, quantus, foreign),
                          decimals: foreign.decimals,
                        ),
                        foreign.symbol,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.sendBody(),
                    ),
            ),
            const SizedBox(width: 12),
            Text(l10n.swapSlippageTitle, style: context.sendBody()),
            const SizedBox(width: 8),
            PopUpButton<int>(
              key: SwapSheet.slippageKey,
              semanticLabel: l10n.swapSlippageTitle,
              items: [
                for (final option in swapSlippageOptionsBps)
                  PopUpItem(option, l10n.commonPercent(slippagePercentLabel(option))),
                PopUpItem(_customSlippage, l10n.swapSlippageCustom),
              ],
              value: _typesSlippage || !swapSlippageOptionsBps.contains(bps) ? _customSlippage : bps,
              onSelected: _pickSlippage,
            ),
            if (_typesSlippage) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: SendField(
                  key: SwapSheet.customSlippageKey,
                  controller: _slippage,
                  focusNode: _slippageFocus,
                  hint: '',
                  style: context.themeTextV3.body.copyWith(color: context.colorsV3.textContent),
                  suffix: l10n.commonPercent(''),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    DecimalInputFilter(localeConfig: ref.watch(localeNumberConfigProvider), maxDecimalPlaces: 2),
                  ],
                  onChanged: (text) => _onSlippageTyped(l10n, text),
                ),
              ),
            ],
          ],
        ),
        if (problem != null) ...[
          const SizedBox(height: 4),
          Text(
            problem,
            textAlign: TextAlign.end,
            style: context.themeTextV3.caption.copyWith(color: context.colorsV3.semanticEmber),
          ),
        ],
      ],
    );
  }

  /// A fee the quote's amounts already hold, under the rate.
  Widget _termLine(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        Text(label, style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted2)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.themeTextV3.caption.copyWith(color: context.colorsV3.textMuted),
          ),
        ),
      ],
    ),
  );

  // ------------------------------------------------------------- the review

  List<Widget> _review(AppLocalizations l10n, {required bool available}) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final quote = _reviewed;
    if (quote == null) throw StateError('The review step has no quote to show.');
    final from = quote.fromToken;
    final to = quote.toToken;
    final swapOut = from.isQuantus;
    final foreign = swapOut ? to : from;
    final sendsDeposit = swapOut && ref.watch(swapPreflightProvider) == null;
    final feeKey = (_account, quote.amountIn);
    final fee = sendsDeposit ? ref.watch(swapDepositFeeProvider(feeKey)) : null;
    final spendable = sendsDeposit ? ref.watch(effectiveBalanceProviderFamily(_account.accountId)).value : null;
    final review = swapReviewOf(l10n, fmt, quote, available: available, fee: fee, spendable: spendable);
    final address = review.rows.whereType<SwapRowAddress>().single;
    // What leaves the paying side in all: the app's own deposit carries its
    // chain fee.
    final total = formatSwapAmount(l10n, fmt, quote.amountIn + (fee?.value ?? BigInt.zero), from);
    // Beside the buttons: what stops the swap, or why the last press started
    // nothing.
    final (String? notice, bool isCaution) = !available
        ? (l10n.swapDisabledTitle, false)
        : review.insufficient
        ? (l10n.swapReviewInsufficient(from.symbol), false)
        : review.feeFailed
        ? (l10n.swapReviewFeeFailed, false)
        : (_notice, _noticeIsCaution);

    return [
      const SizedBox(height: 26),
      CapsText(l10n.swapStepSwapping, style: context.sendCaps()),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              fmt.formatAmount(quote.amountIn, decimals: from.decimals),
              overflow: TextOverflow.ellipsis,
              style: text.displayBalance.copyWith(color: colors.textContent),
            ),
          ),
          const SizedBox(width: 8),
          Text(from.symbol, style: text.dataAddressLarge.copyWith(color: colors.textMuted)),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        l10n.desktopSwapForAmountOnNetwork(formatSwapAmount(l10n, fmt, quote.amountOut, to), to.networkName),
        style: text.body.copyWith(color: colors.textContent),
      ),
      const SizedBox(height: 18),
      CapsText(
        swapOut
            ? l10n.desktopSwapRecipientOn(foreign.networkName)
            : l10n.desktopSwapRefundAddressOn(foreign.networkName),
        style: context.sendCaps(),
      ),
      const SizedBox(height: 8),
      // Whole, as every address on another chain is.
      Text(address.address, style: context.sendMono(colors.textWhite)),
      const SizedBox(height: 14),
      const MenuDivider(),
      const SizedBox(height: 4),
      // The lines scroll where the window is too low for them all; what is
      // paid in all and the buttons stay under them in the sheet.
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SummaryRow(
                label: inspectorLabel(context, swapOut ? l10n.swapFrom : l10n.swapTo),
                value: AccountLabel(account: _account),
              ),
              for (final row in review.rows)
                if (row case SwapRowText(:final label, :final value)) FigureRow(label: label, value: value),
              if (review.unusedRefunded)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6),
                  child: Text(l10n.swapReviewUnusedRefunded, style: text.caption.copyWith(color: colors.textMuted2)),
                ),
            ],
          ),
        ),
      ),
      const MenuDivider(),
      const SizedBox(height: 4),
      FigureRow(label: l10n.swapYouPay, value: total, isStrong: true),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: notice == null
                  ? _attribution(l10n)
                  : Text(
                      notice,
                      key: SwapSheet.noticeKey,
                      style: context.sendBody(color: isCaution ? colors.semanticSand : colors.semanticEmber),
                    ),
            ),
          ),
          if (review.feeFailed) ...[
            ToolbarAction.symbol(
              key: SwapSheet.retryFeeKey,
              symbol: CupertinoIcons.arrow_clockwise,
              label: l10n.homeActivityRetry,
              onPressed: () => ref.invalidate(swapDepositFeeProvider(feeKey)),
            ),
            const SizedBox(width: 10),
          ],
          SheetButton(
            key: SwapSheet.backKey,
            label: l10n.commonBack,
            kind: SheetButtonKind.secondary,
            isDisabled: _confirming,
            onTap: _backToForm,
          ),
          const SizedBox(width: 10),
          SheetButton(
            key: SwapSheet.confirmKey,
            label: swapOut ? l10n.swapTitle : l10n.swapContinue,
            isLoading: _confirming,
            isDisabled: review.blocked,
            onTap: () => unawaited(_confirm(quote)),
          ),
        ],
      ),
    ];
  }
}

/// Turns the swap around, from between its two sides.
class _FlipButton extends StatefulWidget {
  const _FlipButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_FlipButton> createState() => _FlipButtonState();
}

class _FlipButtonState extends State<_FlipButton> {
  bool _isHovered = false;
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.basic,
        onShowHoverHighlight: (isHovered) => setState(() => _isHovered = isHovered),
        onShowFocusHighlight: (isFocused) => setState(() => _isFocused = isFocused),
        actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed())},
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _isHovered ? colors.bgSurface2 : colors.bgSurface,
              shape: BoxShape.circle,
              border: Border.all(
                color: _isFocused ? colors.accentFlare.useOpacity(0.7) : colors.borderEmphasis,
                width: _isFocused ? 2 : 1,
              ),
            ),
            child: Icon(CupertinoIcons.arrow_up_arrow_down, size: 13, color: colors.accentFlare),
          ),
        ),
      ),
    );
  }
}
