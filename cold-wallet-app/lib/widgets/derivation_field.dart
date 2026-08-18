import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

/// Chooses which account a seed phrase derives: an index that fills the wallet's
/// own template, or a full path typed out for a seed created elsewhere.
class DerivationField extends StatefulWidget {
  final ValueChanged<ColdAccount?> onChanged;

  const DerivationField({super.key, required this.onChanged});

  @override
  State<DerivationField> createState() => _DerivationFieldState();
}

class _DerivationFieldState extends State<DerivationField> {
  final _index = TextEditingController(text: '0');
  final _path = TextEditingController(text: HdWalletService.pathForIndex(0));
  bool _expanded = false;
  bool _useFullPath = false;

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

  ColdAccount? get _account {
    try {
      if (_useFullPath) return ColdAccount(label: 'Account 1', path: _path.text.trim());
      final index = int.tryParse(_index.text.trim());
      if (index == null) return null;
      return ColdAccount(label: 'Account ${index + 1}', index: index);
    } catch (_) {
      return null;
    }
  }

  void _emit() => widget.onChanged(_account);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final account = _account;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _expanded = !_expanded),
          child: Row(
            children: [
              Text('ADVANCED', style: text.transactionDetailRowLabel?.copyWith(color: colors.textLabel)),
              const SizedBox(width: 6),
              Icon(_expanded ? Icons.expand_less : Icons.chevron_right, size: 18, color: colors.textLabel),
            ],
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 12),
          if (!_useFullPath)
            TextField(
              controller: _index,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
              style: text.smallParagraph?.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Account index',
                labelStyle: text.detail?.copyWith(color: colors.textSecondary),
              ),
            )
          else
            TextField(
              controller: _path,
              autocorrect: false,
              enableSuggestions: false,
              style: text.smallParagraph?.copyWith(color: colors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Derivation path',
                labelStyle: text.detail?.copyWith(color: colors.textSecondary),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            account == null ? 'Not a valid derivation' : account.derivationPath,
            style: text.detail?.copyWith(color: account == null ? colors.error : colors.textMuted),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _useFullPath = !_useFullPath);
              _emit();
            },
            child: Text(
              _useFullPath ? 'Use an account index instead' : 'Use a full derivation path',
              style: text.detail?.copyWith(color: colors.accentOrange),
            ),
          ),
        ],
      ],
    );
  }
}
