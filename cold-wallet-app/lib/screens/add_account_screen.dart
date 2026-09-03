import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/address_with_checkphrase.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

enum _Derivation { accountIndex, fullPath }

/// Chooses which account the vault's seed phrase derives next, and adds it.
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

  late final TextEditingController _index;
  final _path = TextEditingController();

  _Derivation _mode = _Derivation.accountIndex;

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
    _index = TextEditingController(text: '${_firstFreeIndex()}');
    _index.addListener(_onInputChanged);
    _path.addListener(_onInputChanged);
    _previewPath = _account?.derivationPath;
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _index.dispose();
    _path.dispose();
    super.dispose();
  }

  /// Scheme new accounts of this wallet use, so an added account matches the
  /// ones already there.
  DilithiumScheme get _scheme => ColdAccount.walletScheme(ref.read(accountsProvider));

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

  /// `Account 3` for a path that follows no template this wallet numbers.
  String _nextFreeLabel() {
    final taken = {for (final account in ref.read(accountsProvider)) account.label};
    for (var ordinal = 1; ; ordinal++) {
      final label = 'Account $ordinal';
      if (!taken.contains(label)) return label;
    }
  }

  ColdAccount? get _account => switch (_mode) {
    _Derivation.accountIndex => ColdAccount.atIndexText(_index.text, scheme: _scheme),
    _Derivation.fullPath => ColdAccount.atPath(_path.text, label: _nextFreeLabel(), defaultScheme: _scheme),
  };

  /// The account already holding this derivation, if any. Adding it twice would
  /// put two rows with one address in the list.
  ColdAccount? get _duplicate {
    final target = _account;
    if (target == null) return null;
    for (final account in ref.read(accountsProvider)) {
      if (account.derivationPath == target.derivationPath && account.scheme == target.scheme) return account;
    }
    return null;
  }

  void _onInputChanged() {
    setState(() => _error = null);
    _previewDebounce?.cancel();
    _previewDebounce = Timer(_previewDelay, () {
      if (mounted) setState(() => _previewPath = _account?.derivationPath);
    });
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
              Text(
                'Every account comes from the same recovery phrase. Choose which one to add.',
                style: text.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 24),
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
              _preview(context, account, duplicate),
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
            label: 'Done',
            isLoading: _adding,
            isDisabled: account == null || duplicate != null,
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
          _StepperButton(icon: Icons.remove_rounded, onTap: () => _stepIndex(-1), semanticLabel: 'Previous account'),
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
          _StepperButton(icon: Icons.add_rounded, onTap: () => _stepIndex(1), semanticLabel: 'Next account'),
        ],
      ),
    );
  }

  Widget _pathField(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: context.radiusV3.mdBorder,
        border: Border.all(color: colors.borderHairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('DERIVATION PATH', style: text.labelMonogram.copyWith(color: colors.textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: _path,
            onChanged: (_) => _userChangedPath = true,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            // Wraps: a path longer than the field would otherwise scroll its
            // own start out of sight, and a path half-read is not verified.
            maxLines: null,
            keyboardType: TextInputType.text,
            style: text.dataAddressLarge.copyWith(
              color: colors.textContent,
              fontFamily: AppTextThemeV3.fontFamilySecondary,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              hintText: HdWalletService.pathForIndex(0, DilithiumSchemeExtension.current),
              hintStyle: text.dataAddressLarge.copyWith(
                color: colors.textMuted,
                fontFamily: AppTextThemeV3.fontFamilySecondary,
              ),
            ),
          ),
        ],
      ),
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
          Text(account.label, style: text.headingRow.copyWith(color: colors.textContent)),
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
  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  const _StepperButton({required this.icon, required this.onTap, required this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;

    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // 44pt: the smallest target a finger hits reliably.
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 22, color: colors.textContent)),
      ),
    );
  }
}
