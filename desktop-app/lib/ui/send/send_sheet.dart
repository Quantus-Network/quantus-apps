import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:quantus_desktop_wallet/providers/approval_providers.dart';
import 'package:quantus_desktop_wallet/services/external_links.dart';
import 'package:quantus_desktop_wallet/ui/components/caps_text.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_desktop_wallet/ui/components/toolbar_action.dart';
import 'package:quantus_desktop_wallet/ui/send/send_form_parts.dart';
import 'package:quantus_desktop_wallet/ui/send/send_styles.dart';
import 'package:quantus_desktop_wallet/ui/send/send_summary.dart';
import 'package:quantus_desktop_wallet/ui/shell/shell_sheet_view.dart';
import 'package:quantus_desktop_wallet/utils/send_strategies.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/l10n/app_localizations.dart';
import 'package:wallet_core/providers/account_providers.dart';
import 'package:wallet_core/providers/l10n_provider.dart';
import 'package:wallet_core/providers/wallet_providers.dart';
import 'package:wallet_core/send/send_review.dart';
import 'package:wallet_core/send/send_review_row.dart';
import 'package:wallet_core/send/send_screen_logic.dart';
import 'package:wallet_core/send/send_strategy.dart';
import 'package:wallet_core/services/user_approval.dart';

/// The steps of the Send sheet.
enum _Step { form, review, receipt }

/// The Send sheet: a form for who is paid and how much, a review of the send
/// before the system is asked to approve it, and a receipt once it has been
/// handed to the network.
///
/// The send leaves the account the sheet opened on. Its flow, a first fee
/// quote with it, was started by the press that opened the sheet.
class SendSheet extends ConsumerStatefulWidget {
  const SendSheet({super.key});

  static const addressFieldKey = Key('send-address');
  static const amountFieldKey = Key('send-amount');
  static const pasteKey = Key('send-paste');
  static const maxKey = Key('send-max');
  static const retryFeeKey = Key('send-retry-fee');
  static const cancelKey = Key('send-cancel');
  static const reviewKey = Key('send-review');
  static const backKey = Key('send-back');
  static const sendKey = Key('send-send');
  static const explorerKey = Key('send-explorer');
  static const doneKey = Key('send-done');

  /// The row of [address] among the addresses paid before.
  static Key recentKey(String address) => ValueKey('send-recent-$address');

  /// How many of the addresses paid before the form offers.
  static const recentsShown = 4;

  @override
  ConsumerState<SendSheet> createState() => _SendSheetState();
}

class _SendSheetState extends ConsumerState<SendSheet> {
  /// The sheet opens on the active account and stays on it while it is open.
  late final BaseAccount _account;
  late final SendStrategy _strategy;

  final _address = TextEditingController();
  final _amountText = TextEditingController();
  final _addressFocus = FocusNode();
  final _amountFocus = FocusNode();

  /// Holds the keyboard's focus on the steps that have no field, so the
  /// sheet's keys still reach it.
  final _stepFocus = FocusNode(skipTraversal: true);

  _Step _step = _Step.form;

  /// The addresses paid before that the form offers.
  List<String> _recents = const [];

  /// What is known of the address in the field: whether it is one at all,
  /// then the send's own verdict on it, which may take a while or fail.
  bool _isAddress = false;
  RecipientBlock? _block;
  bool _isChecking = false;
  bool _checkFailed = false;
  String _lastAddress = '';
  StreamSubscription<RecipientBlock?>? _blockSubscription;

  /// The read of the clipboard that Paste is waiting on, if any.
  Object? _pendingPaste;

  /// Who the review opened on. From then on this is who is paid, whatever
  /// becomes of the field.
  String? _reviewedRecipient;

  /// The amount in the field, zero while it holds none or one that cannot
  /// be read.
  BigInt _amount = BigInt.zero;
  bool _amountUnreadable = false;

  /// The amount is whatever the fee leaves of the balance.
  bool _sendAll = false;

  /// The fee the review opened with.
  SendFee? _openedWith;

  /// The system is being asked, or the send is on its way to the network:
  /// neither can be interrupted.
  bool _isSending = false;

  /// Why the last press of Send sent nothing.
  String? _error;

  /// The submitted send, and its figures as the review showed them last.
  SendTerminalContent? _submitted;
  List<SendReviewRow> _submittedRows = const [];

  @override
  void initState() {
    super.initState();
    final active = ref.read(activeAccountProvider).value;
    final strategy = sendStrategyFor(active);
    if (active == null || strategy == null) {
      throw StateError('Send was opened on an account this app cannot send from.');
    }
    _account = active.account;
    _strategy = strategy;
    _address.addListener(_onAddressChanged);
    _addressFocus.requestFocus();
    unawaited(_loadRecents());
  }

  @override
  void dispose() {
    _blockSubscription?.cancel();
    _address.dispose();
    _amountText.dispose();
    _addressFocus.dispose();
    _amountFocus.dispose();
    _stepFocus.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ who is paid

  String get _typedAddress => _address.text.trim();

  /// Who is paid: the address in the field while the form is open, then the
  /// one the review opened on.
  String get _recipient => _reviewedRecipient ?? _typedAddress;

  /// The recipient can be paid: the address in the field passed its checks,
  /// as the one under review did before the review opened.
  bool get _recipientAccepted =>
      _reviewedRecipient != null || (_isAddress && _block == null && !_isChecking && !_checkFailed);

  Future<void> _loadRecents() async {
    final all = await ref.read(recentAddressesServiceProvider).getAddresses();
    if (!mounted) return;
    setState(() {
      _recents = all.where((a) => a != _strategy.sourceAccountId).take(SendSheet.recentsShown).toList();
    });
  }

  /// The controller also tells of selection changes, so an unchanged address
  /// is only looked up again when its last check failed.
  void _onAddressChanged() {
    final address = _typedAddress;
    if (address == _lastAddress && !_checkFailed) return;
    _lastAddress = address;
    _blockSubscription?.cancel();
    final isAddress = address.isNotEmpty && ref.read(substrateServiceProvider).isValidSS58Address(address);
    setState(() {
      _isAddress = isAddress;
      _block = null;
      _isChecking = isAddress;
      _checkFailed = false;
    });
    if (!isAddress) return;
    // Verdicts come as the send has them, the check against its own account
    // first. The latest stands; any edit cancels the subscription.
    _blockSubscription = _strategy
        .recipientBlock(ref, address)
        .listen(
          (block) {
            if (!mounted) return;
            setState(() {
              _block = block;
              _isChecking = false;
            });
          },
          onError: (Object e) {
            quantusPrint('The check of a send\'s recipient failed: $e');
            if (!mounted) return;
            // A check that failed keeps the send closed.
            setState(() {
              _isChecking = false;
              _checkFailed = true;
            });
          },
        );
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

  /// What is wrong with the address in the field, if anything.
  String? _addressProblem(AppLocalizations l10n) {
    if (_recipient.isEmpty) return null;
    if (!_isAddress) return l10n.desktopSendAddressInvalid;
    if (_checkFailed) return l10n.sendRecipientCheckFailedMessage;
    return switch (_block) {
      RecipientBlock.self => l10n.desktopSendAddressSelf,
      RecipientBlock.oneClickDeposit => l10n.encryptedSendNearIntentsTitle,
      null => null,
    };
  }

  // --------------------------------------------------------------- how much

  ProviderListenable<SendFeeState> get _feeProvider =>
      _strategy.feeProvider(recipient: _recipientAccepted ? _recipient : '', amount: _amount);

  /// Prices a send of [amount]. Until there is someone to pay it is priced
  /// to the account itself: a transfer costs the same whoever it pays.
  void _requestFee(BigInt amount, {bool immediate = false}) {
    final recipient = _recipientAccepted ? _recipient : _strategy.sourceAccountId;
    if (recipient == null) return;
    _strategy.requestFee(ref.read, recipient: recipient, amount: amount, sendAll: _sendAll, immediate: immediate);
  }

  bool _feeApplies(SendFeeState feeState) {
    final fee = feeState.fee;
    return fee != null && feeState.settled && _strategy.feeApplies(fee, amount: _amount, sendAll: _sendAll);
  }

  BigInt _maxSendable(SendFee? fee) => SendScreenLogic.calculateMaxSendableAmount(
    balance: ref.read(_strategy.spendableBalanceProvider).value ?? BigInt.zero,
    networkFee: _strategy.feeChargedToBalance(fee),
  );

  String _amountAsTyped(BigInt amount) => amount == BigInt.zero
      ? ''
      : ref
            .read(numberFormattingServiceProvider)
            .formatBalance(amount, smartDecimals: AppConstants.decimals, addThousandsSeparators: false);

  /// Puts [amount] in the field, as Max and a fee that moves a max send do.
  void _setAmount(BigInt amount) {
    if (amount == _amount) return;
    _amountText.text = _amountAsTyped(amount);
    setState(() {
      _amount = amount;
      _amountUnreadable = false;
    });
  }

  void _onAmountChanged(String text) {
    final amount = ref.read(numberFormattingServiceProvider).parseAmount(text);
    setState(() {
      _amount = amount ?? BigInt.zero;
      _amountUnreadable = amount == null;
      _sendAll = false;
    });
    if (_amount > BigInt.zero) _requestFee(_amount);
  }

  /// Max sends everything that can be spent. A send that can move the whole
  /// balance in one call prices that call at once, and the amount follows
  /// its fee as it lands.
  void _setMax() {
    final max = _maxSendable(ref.read(_feeProvider).fee);
    setState(() => _sendAll = _strategy.supportsSendAll);
    _setAmount(max);
    if (max > BigInt.zero) _requestFee(max, immediate: _sendAll);
  }

  /// What is wrong with an amount of [status], if anything worth saying. An
  /// amount still to be typed is not.
  String? _amountProblem(AppLocalizations l10n, AmountStatus status, {required SendFee? fee}) {
    final fmt = ref.read(numberFormattingServiceProvider);
    String amount(BigInt value) => l10n.commonAmountBalance(fmt.formatBalance(value), AppConstants.tokenSymbol);

    return switch (status) {
      AmountStatus.valid || AmountStatus.zero => null,
      AmountStatus.negative => l10n.sendLogicInvalidAmount,
      AmountStatus.belowMinimum => l10n.sendLogicBelowMinimum(
        fmt.formatAmount(SendScreenLogic.minimumSendAmount),
        AppConstants.tokenSymbol,
      ),
      AmountStatus.insufficientBalance => l10n.desktopSendAmountTooMuch(amount(_maxSendable(fee))),
    };
  }

  // ------------------------------------------------------------- the steps

  void _openReview() {
    // Review is offered by the form as it was last drawn; the address may
    // have changed since.
    if (!_recipientAccepted) return;
    final feeState = ref.read(_feeProvider);
    final fee = feeState.fee;
    if (fee == null) throw StateError('The review was opened before the send had a fee.');
    // The review prices the exact send; a quote may still be waiting its turn.
    if (!_feeApplies(feeState)) _requestFee(_amount, immediate: true);
    _stepFocus.requestFocus();
    _pendingPaste = null;
    setState(() {
      _reviewedRecipient = _typedAddress;
      _openedWith = fee;
      _error = null;
      _step = _Step.review;
    });
  }

  void _backToForm() {
    if (_isSending) return;
    // Back where the typing left off, once the field is there again.
    _amountFocus.requestFocus();
    setState(() {
      _reviewedRecipient = null;
      _error = null;
      _step = _Step.form;
    });
  }

  Future<void> _send(SendReview review, List<SendReviewRow> rows) async {
    if (_isSending || review.confirmBlocked) return;
    setState(() {
      _isSending = true;
      _error = null;
    });

    final failed = ref.read(l10nProvider).sendReviewSubmitFailed;
    SendOutcome outcome;
    try {
      outcome = await _strategy.submit(
        ref,
        recipientAddress: _recipient,
        amount: review.amount,
        fee: review.fee,
        isPayMode: false,
        sendAll: _sendAll,
      );
    } catch (e, st) {
      quantusPrint('Send failed: $e\n$st');
      outcome = SendFailed(failed);
    }
    if (!mounted) return;

    switch (outcome) {
      case SendSubmitted(:final terminal):
        setState(() {
          _isSending = false;
          _submitted = terminal;
          _submittedRows = rows;
          _step = _Step.receipt;
        });
      case SendFailed(:final message):
        setState(() {
          _isSending = false;
          _error = message;
        });
      case SendNeedsHardwareSignature() || SendNeedsProving():
        setState(() {
          _isSending = false;
          _error = failed;
        });
        // Send is offered only on accounts whose key signs in the app, in
        // the open.
        throw StateError('The desktop app cannot finish this send: $outcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    // A max send follows its fee, on whichever step the sheet is.
    ref.listen(_feeProvider, (_, next) {
      if (_sendAll && _step != _Step.receipt && next.fee != null) _setAmount(_maxSendable(next.fee));
    });
    final title = _strategy.strings(l10n).flowTitle;
    final isReview = _step == _Step.review;

    return PopScope(
      canPop: !_isSending,
      child: SheetBackShortcut(
        onBack: isReview && !_isSending ? _backToForm : null,
        child: Focus(
          focusNode: _stepFocus,
          skipTraversal: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ShellSheetHeader(
                title: isReview ? l10n.desktopSendReview : title,
                account: _account,
                parent: isReview ? (title: title, onBack: _backToForm) : null,
              ),
              ...switch (_step) {
                _Step.form => _form(l10n),
                _Step.review => _review(l10n),
                _Step.receipt => _receipt(l10n),
              },
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------- the form

  List<Widget> _form(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final balance = ref.watch(_strategy.spendableBalanceProvider);
    final feeState = ref.watch(_feeProvider);
    final fee = feeState.fee;
    final availability = ref.watch(approvalAvailabilityProvider);
    // Said beside the buttons where a send could not be approved.
    final approvalNote = switch (availability) {
      AsyncData(:final value) => approvalUnavailableNote(l10n, value),
      AsyncError(:final error) => l10n.desktopApprovalFailed('$error'),
      _ => null,
    };

    final amountStatus = SendScreenLogic.getAmountStatus(
      _amount,
      balance.value ?? BigInt.zero,
      _strategy.feeChargedToBalance(fee),
    );
    final affordabilityError = fee == null ? null : _strategy.affordabilityError(ref, fee, l10n);
    // A balance that is not known is not a shortfall: Review is unavailable
    // without the amount being called too much.
    final amountProblem = _amountUnreadable
        ? l10n.sendInputAmountInvalidAmount
        : amountStatus == AmountStatus.insufficientBalance && !balance.hasValue
        ? null
        : _amountProblem(l10n, amountStatus, fee: fee) ?? affordabilityError;
    final canReview =
        _recipientAccepted &&
        fee != null &&
        balance.hasValue &&
        !_strategy.extraBalancesLoading(ref) &&
        affordabilityError == null &&
        amountStatus == AmountStatus.valid &&
        availability.value == ApprovalAvailability.available;

    return [
      const SizedBox(height: 14),
      SendFieldLabel(
        label: l10n.sendTxSubmittedToLabel,
        actions: [
          ToolbarAction.symbol(
            key: SendSheet.pasteKey,
            symbol: CupertinoIcons.doc_on_clipboard,
            label: l10n.desktopImportPaste,
            onPressed: _paste,
          ),
        ],
      ),
      const SizedBox(height: 6),
      SendField(
        key: SendSheet.addressFieldKey,
        controller: _address,
        focusNode: _addressFocus,
        hint: l10n.desktopSendAddressHint,
        style: context.sendMono(colors.textWhite),
        error: _addressProblem(l10n),
        onSubmitted: (_) => _amountFocus.requestFocus(),
      ),
      if (_recipient.isEmpty && _recents.isNotEmpty) ...[
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: CapsText(l10n.sendSelectRecipientRecents, style: context.sendCaps()),
        ),
        for (final address in _recents)
          SendRecentRow(key: SendSheet.recentKey(address), address: address, onPressed: () => _address.text = address),
      ] else if (_isChecking) ...[
        const SizedBox(height: 10),
        Text(l10n.sendRecipientChecking, style: context.sendBody()),
      ] else if (_recipientAccepted) ...[
        const SizedBox(height: 10),
        Row(
          children: [
            CapsText(l10n.componentCheckphraseLabel, style: context.sendCaps()),
            const SizedBox(width: 12),
            Flexible(
              child: CheckphraseText(
                _recipient,
                style: context.sendMono(colors.semanticLilac),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 18),
      SendFieldLabel(
        label: l10n.sendReviewAmount,
        actions: [
          ToolbarAction.symbol(
            key: SendSheet.maxKey,
            symbol: CupertinoIcons.arrow_up_to_line,
            label: l10n.sendInputAmountMax,
            onPressed: balance.hasValue ? _setMax : null,
          ),
        ],
      ),
      const SizedBox(height: 6),
      SendField(
        key: SendSheet.amountFieldKey,
        controller: _amountText,
        focusNode: _amountFocus,
        hint: '0',
        style: context.themeTextV3.amountRow,
        error: amountProblem,
        suffix: AppConstants.tokenSymbol,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [DecimalInputFilter(localeConfig: ref.watch(localeNumberConfigProvider))],
        onChanged: _onAmountChanged,
        onSubmitted: (_) {
          if (canReview) _openReview();
        },
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Text(l10n.desktopSendAvailable, style: context.sendBody()),
          const SizedBox(width: 8),
          Text(switch (ref.watch(_strategy.displayBalanceProvider)) {
            AsyncValue(:final value?) => l10n.commonAmountBalance(fmt.formatBalance(value), AppConstants.tokenSymbol),
            AsyncError() => '—',
            _ => '…',
          }, style: context.sendBody()),
          const Spacer(),
          ..._feeLine(l10n, fmt, feeState),
        ],
      ),
      const SizedBox(height: 26),
      Row(
        children: [
          Expanded(
            child: approvalNote == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(approvalNote, style: context.sendBody()),
                  ),
          ),
          SheetButton(
            key: SendSheet.cancelKey,
            label: l10n.commonCancel,
            kind: SheetButtonKind.secondary,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 10),
          SheetButton(
            key: SendSheet.reviewKey,
            label: l10n.desktopSendReview,
            isDisabled: !canReview,
            onTap: _openReview,
          ),
        ],
      ),
    ];
  }

  /// What the network takes, at the end of the line under the amount: an
  /// estimate until the fee priced exactly this send, and a way to ask again
  /// when it could not be had.
  List<Widget> _feeLine(AppLocalizations l10n, NumberFormattingService fmt, SendFeeState feeState) {
    final fee = feeState.fee;
    final retry = ToolbarAction.symbol(
      key: SendSheet.retryFeeKey,
      symbol: CupertinoIcons.arrow_clockwise,
      label: l10n.homeActivityRetry,
      onPressed: () => _strategy.retryFee(ref, recipient: _recipient, amount: _amount),
    );

    return [
      if (fee == null && feeState.failed)
        Text(
          _strategy.strings(l10n).feeFetchFailedMessage,
          style: context.sendBody(color: context.colorsV3.semanticEmber),
        )
      else ...[
        Text(l10n.swapReviewNetworkFee, style: context.sendBody()),
        const SizedBox(width: 8),
        if (fee == null)
          const Loader(size: 12)
        else
          Text(
            estimateLabel(
              l10n.commonAmountBalance(fmt.formatBalance(fee.displayFee, smartDecimals: 5), AppConstants.tokenSymbol),
              estimate: !_feeApplies(feeState),
            ),
            style: context.sendBody(),
          ),
      ],
      if (feeState.failed) ...[const SizedBox(width: 4), retry],
    ];
  }

  // ------------------------------------------------------------- the review

  List<Widget> _review(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final fmt = ref.watch(numberFormattingServiceProvider);
    final openedWith = _openedWith;
    if (openedWith == null) throw StateError('The review step has no fee to open with.');
    final review = SendReview.of(
      _strategy,
      feeState: ref.watch(_feeProvider),
      openedWith: openedWith,
      spendable: ref.watch(_strategy.spendableBalanceProvider).value,
      enteredAmount: _amount,
      sendAll: _sendAll,
    );
    final rows = _strategy.reviewRows(
      ref,
      recipientAddress: _recipient,
      amount: review.amount,
      fee: review.fee,
      feeIsEstimate: !review.feeApplies,
      sendAll: _sendAll,
    );
    final strings = _strategy.strings(l10n);
    // Beside the buttons: what stops the send, or why the last press sent
    // nothing.
    final problem =
        _amountProblem(l10n, review.amountStatus, fee: review.fee) ??
        (review.feeFailed ? strings.feeFetchFailedMessage : _error);

    return [
      const SizedBox(height: 26),
      CapsText(strings.reviewHeroLabel, style: context.sendCaps()),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              // A max send's amount moves with its fee until that is exact.
              estimateLabel(
                fmt.formatBalance(review.amount, smartDecimals: AppConstants.decimals),
                estimate: _sendAll && !review.feeApplies,
              ),
              overflow: TextOverflow.ellipsis,
              style: text.displayBalance.copyWith(color: colors.textContent),
            ),
          ),
          const SizedBox(width: 8),
          Text(AppConstants.tokenSymbol, style: text.dataAddressLarge.copyWith(color: colors.textMuted)),
        ],
      ),
      const SizedBox(height: 24),
      SendSummary(l10n: l10n, recipient: _recipient, from: _account.name, rows: rows, totalLabel: l10n.swapYouPay),
      const SizedBox(height: 22),
      Row(
        children: [
          Expanded(
            child: problem == null
                ? const SizedBox.shrink()
                : Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Text(problem, style: context.sendBody(color: colors.semanticEmber)),
                  ),
          ),
          if (review.feeFailed) ...[
            ToolbarAction.symbol(
              key: SendSheet.retryFeeKey,
              symbol: CupertinoIcons.arrow_clockwise,
              label: l10n.homeActivityRetry,
              onPressed: () => _strategy.retryFee(ref, recipient: _recipient, amount: _amount),
            ),
            const SizedBox(width: 10),
          ],
          SheetButton(
            key: SendSheet.backKey,
            label: l10n.commonBack,
            kind: SheetButtonKind.secondary,
            isDisabled: _isSending,
            onTap: _backToForm,
          ),
          const SizedBox(width: 10),
          SheetButton(
            key: SendSheet.sendKey,
            label: strings.flowTitle,
            isLoading: _isSending,
            isDisabled: review.confirmBlocked,
            onTap: () => _send(review, rows),
          ),
        ],
      ),
    ];
  }

  // ------------------------------------------------------------ the receipt

  List<Widget> _receipt(AppLocalizations l10n) {
    final colors = context.colorsV3;
    final submitted = _submitted;
    if (submitted == null) throw StateError('The receipt step has no submitted send.');
    final explorerUrl = submitted.explorerUrl;

    return [
      const SizedBox(height: 26),
      Row(
        children: [
          Icon(CupertinoIcons.checkmark_alt, size: 13, color: colors.semanticSage),
          const SizedBox(width: 8),
          CapsText(l10n.desktopSendSubmitted, style: context.sendCaps(color: colors.semanticSage, spacing: 2.4)),
        ],
      ),
      const SizedBox(height: 14),
      Text(
        submitted.headline,
        style: context.themeTextV3.titleHero.copyWith(
          fontSize: 26,
          height: 1.05,
          letterSpacing: -0.65,
          color: colors.textWhite,
        ),
      ),
      const SizedBox(height: 10),
      Text(submitted.subline, style: context.sendBody()),
      const SizedBox(height: 24),
      SendSummary(
        l10n: l10n,
        recipient: submitted.recipientAddress,
        from: _account.name,
        rows: _submittedRows,
        totalLabel: l10n.desktopSendYouPaid,
      ),
      const SizedBox(height: 22),
      Row(
        children: [
          if (explorerUrl != null)
            ToolbarActionRow(
              edge: ToolbarActionEdge.leading,
              children: [
                ToolbarAction.symbol(
                  key: SendSheet.explorerKey,
                  symbol: CupertinoIcons.arrow_up_right_square,
                  label: l10n.desktopViewInExplorer,
                  onPressed: () => ref.read(openExternalUrlProvider)(Uri.parse(explorerUrl)),
                ),
              ],
            ),
          const Spacer(),
          SheetButton(key: SendSheet.doneKey, label: submitted.doneLabel, onTap: () => Navigator.of(context).pop()),
        ],
      ),
    ];
  }
}
