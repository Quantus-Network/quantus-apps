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

/// Renders the seed phrase as `x` characters while keeping the real text
/// intact, since [TextField.obscureText] is unsupported for multiline fields.
///
/// The mask must keep the same character count as the real text so the caret
/// and selection positions stay accurate while typing.
class _ObscuringMnemonicController extends TextEditingController {
  bool obscured = true;

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (!obscured) {
      return super.buildTextSpan(context: context, style: style, withComposing: withComposing);
    }
    return TextSpan(style: style, text: 'x' * text.length);
  }
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final _controller = _ObscuringMnemonicController();
  final _focusNode = FocusNode();
  final _buttonKey = GlobalKey();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_revealButton);
  }

  void _revealButton() {
    if (_focusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 400), () {
        final ctx = _buttonKey.currentContext;
        if (mounted && ctx != null) {
          // ignore: use_build_context_synchronously
          Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
        }
      });
    }
  }

  bool get _hasInput => _controller.text.trim().isNotEmpty;

  Future<void> _import() async {
    final mnemonic = _controller.text.trim();

    if (!mnemonic.startsWith('//')) {
      final words = mnemonic.split(' ').where((w) => w.isNotEmpty).toList();
      if (words.length != 12 && words.length != 24) {
        setState(() => _error = 'Recovery phrase must be 12 or 24 words');
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Throws on an invalid phrase.
      HdWalletService().keyPairAtIndex(mnemonic, 0);

      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => SetPasswordScreen(mnemonic: mnemonic)));
    } catch (e) {
      debugPrint('Import rejected: $e');
      if (mounted) setState(() => _error = 'Not a valid recovery phrase');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;
    final fieldTextStyle = text.smallTitle?.copyWith(color: colors.checksum, fontWeight: FontWeight.w400);

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Import Wallet'),
      mainContent: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(
                'Restore an existing wallet with your 12 or 24 words recovery phrase',
                style: text.smallParagraph?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                height: 202,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceDeep,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: colors.borderButton, width: 1),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 36),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        onChanged: (_) => setState(() {}),
                        style: fieldTextStyle,
                        decoration: InputDecoration.collapsed(
                          hintText: 'Type in or paste your recovery phrase. Separate words with spaces.',
                          hintStyle: fieldTextStyle?.copyWith(color: colors.textSecondary),
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.done,
                        autocorrect: false,
                        enableSuggestions: false,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => setState(() => _controller.obscured = !_controller.obscured),
                        behavior: HitTestBehavior.opaque,
                        child: Icon(
                          _controller.obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          size: 22,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: text.detail?.copyWith(color: colors.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(
          key: _buttonKey,
          label: 'Import',
          onTap: _import,
          isLoading: _isLoading,
          isDisabled: !_hasInput,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_revealButton);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }
}
