import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/components/advanced_section.dart';
import 'package:quantus_cold_wallet/components/scheme_picker.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/screens/rename_account_screen.dart';
import 'package:quantus_cold_wallet/ui/cold_theme.dart';

enum _Derivation { accountIndex, fullPath }

/// Names the account the vault's seed phrase derives next, and adds it. Which
/// account that is sits under ADVANCED: index or path, and signature type.
///
/// A screen rather than a sheet: the number pad covers most of a phone, and on
/// a sheet it covered the very field being edited along with the button that
/// committed it. Here the content scrolls clear of the keyboard, and the number
/// pad — which has no return key to dismiss it — is never the only way to
/// choose, because the steppers set the index without it.
class AddAccountScreen extends ConsumerStatefulWidget {
  const AddAccountScreen({super.key});

  @override
  ConsumerState<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends ConsumerState<AddAccountScreen> {
  static const _previewDelay = Duration(milliseconds: 250);

  late final TextEditingController _name;
  late final TextEditingController _index;
  final _path = TextEditingController();

  _Derivation _mode = _Derivation.accountIndex;

  DilithiumScheme _scheme = ColdAccount.newAccountScheme;

  /// Set once the path has been typed in rather than seeded, so the index stops
  /// writing over it. Lives with the screen: leaving and coming back is a fresh
  /// choice, and the path follows the index again.
  bool _userChangedPath = false;

  bool _adding = false;
  String? _error;

  /// The derivation the preview is for, held one step behind the field so a
  /// key derivation does not run on every keystroke.
  String? _previewPath;
  Timer? _previewDebounce;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _nextFreeLabel());
    _index = TextEditingController(text: '${_firstFreeIndex()}');
    _name.addListener(_onInputChanged);
    _index.addListener(_onInputChanged);
    _path.addListener(_onInputChanged);
    _previewPath = _account?.derivationPath;
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _name.dispose();
    _index.dispose();
    _path.dispose();
    super.dispose();
  }

  /// The lowest index this wallet does not already hold at [_scheme], so the
  /// field opens on an account that can actually be added.
  int _firstFreeIndex() {
    final scheme = _scheme;
    final taken = {
      for (final account in ref.read(accountsProvider))
        if (account.scheme == scheme) account.templateIndex,
    };
    for (var index = 0; ; index++) {
      if (!taken.contains(index)) return index;
    }
  }

  /// `Account 3` for the slot at index 2, or the next name in that numbering
  /// nobody holds.
  String _nextFreeLabel() {
    final taken = {for (final account in ref.read(accountsProvider)) account.label};
    for (var ordinal = _firstFreeIndex() + 1; ; ordinal++) {
      final label = 'Account $ordinal';
      if (!taken.contains(label)) return label;
    }
  }

  String get _label => _name.text.trim();

  ColdAccount? get _account => switch (_mode) {
    _Derivation.accountIndex => ColdAccount.atIndexText(_index.text, scheme: _scheme)?.withLabel(_label),
    _Derivation.fullPath => ColdAccount.atPath(_path.text, label: _label, scheme: _scheme),
  };

  /// The account already holding this derivation, if any. Adding it twice would
  /// put two rows with one address in the list.
  ColdAccount? get _duplicate {
    final target = _account;
    if (target == null) return null;
    return ref.read(accountsProvider).where(target.derivesSameKey).firstOrNull;
  }

  void _onInputChanged() {
    setState(() => _error = null);
    _previewDebounce?.cancel();
    _previewDebounce = Timer(_previewDelay, () {
      if (mounted) setState(() => _previewPath = _account?.derivationPath);
    });
  }

  void _setScheme(DilithiumScheme scheme) {
    if (scheme == _scheme) return;
    setState(() => _scheme = scheme);
    // The index moves to the first slot free at the new scheme, and a path not
    // typed by hand follows it, so the preview never offers an account that
    // cannot be added. A typed path is left as typed.
    _index.text = '${_firstFreeIndex()}';
    if (!_userChangedPath) _path.text = ColdAccount.atIndexText(_index.text, scheme: _scheme)?.derivationPath ?? '';
    _onInputChanged();
  }

  void _setMode(_Derivation mode) {
    if (mode == _mode) return;
    FocusScope.of(context).unfocus();
    // The path opens on the index that is on screen, so the two sides never
    // disagree about which account is being added. A path typed by hand follows
    // no template and is left alone.
    if (mode == _Derivation.fullPath && !_userChangedPath) {
      _path.text = ColdAccount.atIndexText(_index.text, scheme: _scheme)?.derivationPath ?? '';
    }
    setState(() {
      _mode = mode;
      _previewPath = null;
    });
    _onInputChanged();
  }

  void _stepIndex(int by) {
    final current = int.tryParse(_index.text.trim()) ?? 0;
    final next = (current + by).clamp(0, 999999999);
    if (next == current) return;
    HapticFeedback.selectionClick();
    _index.text = '$next';
  }

  Future<void> _add() async {
    final account = _account;
    if (account == null || _duplicate != null) return;

    setState(() {
      _adding = true;
      _error = null;
    });
    try {
      await ref.read(walletControllerProvider.notifier).addAccount(account);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('Add account failed: $e');
      if (mounted) {
        setState(() {
          _adding = false;
          _error = 'Could not add the account: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final account = _account;
    final duplicate = _duplicate;
    final nameError = nameTakenMessage(ref, _label);

    return GestureDetector(
      // The number pad has no return key, so tapping the page must dismiss it.
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: ScaffoldBase(
        appBar: const V2AppBar(title: 'Add Account'),
        mainContent: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text('Name this account', style: text.titleScreen.copyWith(color: colors.textContent)),
              const SizedBox(height: 16),
              QuantusTextField(
                controller: _name,
                hint: 'Account name',
                error: nameError,
                showClearButton: true,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Text(accountNameHelper, style: text.caption.copyWith(color: colors.textMuted)),
              const SizedBox(height: 32),
              AdvancedSection(
                children: [
                  SegmentedControls<_Derivation>(
                    selectedValue: _mode,
                    onChanged: _setMode,
                    items: const [
                      SegmentedControlItem(value: _Derivation.accountIndex, label: 'Account index'),
                      SegmentedControlItem(value: _Derivation.fullPath, label: 'Derivation path'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (_mode == _Derivation.accountIndex) _indexField(context) else _pathField(context),
                  const SizedBox(height: 24),
                  SchemePicker(value: _scheme, onChanged: _setScheme),
                  const SizedBox(height: 24),
                  _preview(context, account, duplicate),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: text.caption.copyWith(color: colors.semanticEmber),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
        bottomContent: ScaffoldBaseBottomContent(
          child: QuantusButton.simple(
            label: 'Create Account',
            padding: coldButtonPadding,
            isLoading: _adding,
            isDisabled: account == null || duplicate != null || _label.isEmpty || nameError != null,
            onTap: _add,
          ),
        ),
      ),
    );
  }

  /// The index, with steppers either side: the common move is one account along
  /// from the last, and that should not need the keyboard at all.
  Widget _indexField(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Row(
        children: [
          _StepperButton(
            glyph: Container(width: 12, height: 1.5, color: colors.textContent),
            onTap: () => _stepIndex(-1),
            semanticLabel: 'Previous account',
          ),
          Expanded(
            child: TextField(
              controller: _index,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              style: text.titleScreen.copyWith(color: colors.textContent),
              decoration: const InputDecoration(border: InputBorder.none, isCollapsed: true),
            ),
          ),
          _StepperButton(
            glyph: QuantusIcon(QuantusIcons.plus, size: 22, color: colors.textContent),
            onTap: () => _stepIndex(1),
            semanticLabel: 'Next account',
          ),
        ],
      ),
    );
  }

  Widget _pathField(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('DERIVATION PATH', style: text.labelMonogram.copyWith(color: colors.textMuted)),
        const SizedBox(height: 8),
        QuantusTextField(
          controller: _path,
          onChanged: (path) {
            _userChangedPath = true;
            // Typing a path whose last element names a scheme snaps the picker
            // to it; picking afterwards overrides it.
            final named = ColdAccount.schemeOfPath(path);
            if (named != null) setState(() => _scheme = named);
          },
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          // Wraps: a path longer than the field would otherwise scroll its
          // own start out of sight, and a path half-read is not verified.
          maxLines: null,
          keyboardType: TextInputType.text,
          hint: HdWalletService.pathForIndex(0, _scheme),
        ),
      ],
    );
  }

  /// What will be added, answered before it is: the path, and the address it
  /// derives to with its checkphrase, so the account can be recognised here
  /// rather than after the fact.
  Widget _preview(BuildContext context, ColdAccount? account, ColdAccount? duplicate) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    if (account == null) {
      return _notice(
        context,
        _mode == _Derivation.accountIndex ? 'Enter an account index.' : 'That is not a derivation path.',
        isError: _mode == _Derivation.fullPath && _path.text.trim().isNotEmpty,
      );
    }
    if (duplicate != null) {
      return _notice(context, 'This wallet already holds this account as ${duplicate.label}.', isError: true);
    }

    final path = account.derivationPath;
    final address = _previewPath == path
        ? ref.watch(derivedAddressProvider((path: path, scheme: account.scheme)))
        : const AsyncValue<String>.loading();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(path, style: text.caption.copyWith(color: colors.textMuted)),
          const SizedBox(height: 4),
          address.when(
            data: (value) => AddressWithCheckphrase(label: 'Address', address: value),
            loading: () => _addressPlaceholder(context),
            error: (e, _) {
              debugPrint('Address preview failed for $path: $e');
              return Text('Could not derive this account.', style: text.caption.copyWith(color: colors.semanticEmber));
            },
          ),
        ],
      ),
    );
  }

  /// Holds the address row's height while it derives, so the card does not jump
  /// as the preview settles.
  Widget _addressPlaceholder(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final width in const [0.4, 0.9, 0.55])
            FractionallySizedBox(
              widthFactor: width,
              child: Container(height: 12, margin: const EdgeInsets.only(bottom: 8), child: const Skeleton(height: 12)),
            ),
        ],
      ),
    );
  }

  Widget _notice(BuildContext context, String message, {required bool isError}) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Text(message, style: text.caption.copyWith(color: isError ? colors.semanticEmber : colors.textMuted));
  }
}

class _StepperButton extends StatelessWidget {
  final Widget glyph;
  final VoidCallback onTap;
  final String semanticLabel;

  const _StepperButton({required this.glyph, required this.onTap, required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // 44pt: the smallest target a finger hits reliably.
        child: SizedBox(width: 44, height: 44, child: Center(child: glyph)),
      ),
    );
  }
}
