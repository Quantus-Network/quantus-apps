import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';

/// Chooses which account a seed phrase derives: the signature scheme (which sets
/// the derivation path's trailing index), an account index that fills the
/// wallet's template, or a full path typed out for a seed created elsewhere.
class DerivationField extends StatefulWidget {
  final ValueChanged<ColdAccount?> onChanged;

  const DerivationField({super.key, required this.onChanged});

  @override
  State<DerivationField> createState() => _DerivationFieldState();
}

class _DerivationFieldState extends State<DerivationField> {
  final _index = TextEditingController(text: '0');
  final _path = TextEditingController(text: HdWalletService.pathForIndex(0, DilithiumSchemeExtension.current));
  bool _expanded = false;
  bool _useFullPath = false;
  bool _userEditedPath = false;
  DilithiumScheme _scheme = DilithiumSchemeExtension.current;

  @override
  void initState() {
    super.initState();
    _index.addListener(_emit);
    _path.addListener(_emit);
  }

  @override
  void dispose() {
    _index.dispose();
    _path.dispose();
    super.dispose();
  }

  ColdAccount? get _account => _useFullPath
      ? ColdAccount.atPath(_path.text, label: 'Account 1', defaultScheme: _scheme)
      : ColdAccount.atIndexText(_index.text, scheme: _scheme);

  void _emit() => widget.onChanged(_account);

  /// The path an untouched full-path field shows: the current index at the
  /// current scheme, so the field always reflects the chosen crypto level.
  String get _templatePath => ColdAccount.atIndexText(_index.text, scheme: _scheme)?.derivationPath ?? _path.text;

  void _setScheme(DilithiumScheme scheme) {
    setState(() {
      _scheme = scheme;
      // A path the user has not hand-edited follows the chosen level.
      if (_useFullPath && !_userEditedPath) _path.text = _templatePath;
    });
    _emit();
  }

  void _toggleFullPath() {
    setState(() {
      _useFullPath = !_useFullPath;
      // Entering path mode opens on the index/scheme currently on screen so the
      // two never disagree; a hand-edited path is left alone.
      if (_useFullPath && !_userEditedPath) _path.text = _templatePath;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final account = _account;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Text('ADVANCED', style: text.labelMonogram.copyWith(color: colors.textMuted)),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less : Icons.chevron_right, size: 18, color: colors.textMuted),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          Text('SIGNATURE TYPE', style: text.labelMonogram.copyWith(color: colors.textMuted)),
          const SizedBox(height: 8),
          SegmentedControls<DilithiumScheme>(
            selectedValue: _scheme,
            onChanged: _setScheme,
            items: const [
              SegmentedControlItem(value: DilithiumSchemeExtension.current, label: 'ML-DSA-65'),
              SegmentedControlItem(value: DilithiumSchemeExtension.legacy, label: 'ML-DSA-87'),
            ],
          ),
          const SizedBox(height: 16),
          if (!_useFullPath)
            TextField(
              controller: _index,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              style: text.body.copyWith(color: colors.textContent),
              decoration: InputDecoration(
                labelText: 'Account index',
                labelStyle: text.caption.copyWith(color: colors.textMuted),
              ),
            )
          else
            TextField(
              controller: _path,
              autocorrect: false,
              enableSuggestions: false,
              onChanged: (_) => _userEditedPath = true,
              style: text.body.copyWith(color: colors.textContent),
              decoration: InputDecoration(
                labelText: 'Derivation path',
                labelStyle: text.caption.copyWith(color: colors.textMuted),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            account == null ? 'Not a valid derivation' : account.derivationPath,
            style: text.caption.copyWith(color: account == null ? colors.semanticEmber : colors.textMuted),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleFullPath,
            child: Text(
              _useFullPath ? 'Use an account index instead' : 'Use a full derivation path',
              style: text.caption.copyWith(color: colors.accentFlare),
            ),
          ),
        ],
      ],
    );
  }
}
