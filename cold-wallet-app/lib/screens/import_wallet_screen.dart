import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/components/scaffold_base.dart';
import 'package:quantus_cold_wallet/components/scaffold_base_bottom_content.dart';
import 'package:quantus_cold_wallet/components/v2_app_bar.dart';
import 'package:quantus_cold_wallet/screens/set_password_screen.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final List<String> _words = [];
  final TextEditingController _input = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<String> _suggestions = [];
  String? _error;

  static const int _maxWords = 24;
  static final List<String> _wordlist = Language.english.list;

  @override
  void dispose() {
    _input.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  int get _count => _words.length + (_input.text.trim().isEmpty ? 0 : 1);
  bool get _isComplete => _count == 12 || _count == 24;
  bool get _isFull => _words.length >= _maxWords;

  void _onChanged(String value) {
    final parts = value.split(RegExp(r'\s+'));
    if (parts.length > 1) {
      for (var i = 0; i < parts.length - 1; i++) {
        final word = parts[i].trim().toLowerCase();
        if (word.isNotEmpty && _words.length < _maxWords) _words.add(word);
      }
      _input.text = _isFull ? '' : parts.last.toLowerCase();
      _input.selection = TextSelection.collapsed(offset: _input.text.length);
    }
    setState(() {
      _error = null;
      _suggestions = _isFull ? const [] : _computeSuggestions(_input.text);
    });
  }

  List<String> _computeSuggestions(String input) {
    final query = input.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _wordlist.where((w) => w.startsWith(query)).take(4).toList();
  }

  void _commit(String word) {
    if (_isFull) return;
    setState(() {
      _words.add(word);
      _input.clear();
      _suggestions = const [];
      _error = null;
    });
    if (!_isFull) _focusNode.requestFocus();
  }

  void _commitTyped() {
    final word = _input.text.trim().toLowerCase();
    if (word.isEmpty) return;
    _commit(word);
  }

  void _removeAt(int index) {
    setState(() => _words.removeAt(index));
  }

  void _import() {
    final pending = _input.text.trim().toLowerCase();
    final words = [..._words, if (pending.isNotEmpty) pending];
    final sentence = words.join(' ');
    try {
      Mnemonic.fromSentence(sentence, Language.english);
    } catch (e) {
      setState(() => _error = 'Invalid recovery phrase. Check your words and try again.');
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => SetPasswordScreen(mnemonic: sentence)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Import wallet'),
      mainContent: GestureDetector(
        onTap: () => _focusNode.requestFocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter your 12 or 24 word recovery phrase, one word at a time.',
              style: text.smallParagraph?.copyWith(color: colors.textTertiary),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_words.isNotEmpty) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_words.length, (i) => _wordChip(i, colors, text)),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (!_isFull) _inputField(colors, text),
                    if (!_isFull && _suggestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _suggestions.map((w) => _suggestionChip(w, colors, text)).toList(),
                      ),
                    ],
                    if (_isFull) ...[
                      const SizedBox(height: 4),
                      Text(
                        'All $_maxWords words entered. Tap a word above to edit it.',
                        style: text.detail?.copyWith(color: colors.textTertiary),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(_error!, style: text.detail?.copyWith(color: colors.error)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          label: 'Import ($_count / ${_count > 12 ? 24 : 12})',
          onTap: _isComplete ? _import : null,
          isDisabled: !_isComplete,
        ),
      ),
    );
  }

  Widget _inputField(AppColorsV2 colors, AppTextTheme text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderButton, width: 1),
      ),
      child: Row(
        children: [
          Text('${_words.length + 1}', style: text.detail?.copyWith(color: colors.textTertiary)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _input,
              focusNode: _focusNode,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.visiblePassword,
              style: text.smallParagraph?.copyWith(color: colors.checksum),
              decoration: const InputDecoration(hintText: 'word'),
              onChanged: _onChanged,
              onSubmitted: (_) => _commitTyped(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wordChip(int index, AppColorsV2 colors, AppTextTheme text) {
    return GestureDetector(
      onTap: () => _removeAt(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: colors.surfaceDeep, borderRadius: BorderRadius.circular(10)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${index + 1}', style: text.detail?.copyWith(color: colors.textTertiary)),
            const SizedBox(width: 8),
            Text(_words[index], style: text.detail?.copyWith(color: colors.checksum)),
            const SizedBox(width: 6),
            Icon(Icons.close, size: 12, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String word, AppColorsV2 colors, AppTextTheme text) {
    return GestureDetector(
      onTap: () => _commit(word),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.borderButton),
        ),
        child: Text(word, style: text.smallParagraph?.copyWith(color: colors.textPrimary)),
      ),
    );
  }
}
