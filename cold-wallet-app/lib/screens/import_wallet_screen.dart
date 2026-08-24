import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/derivation_field.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/screens/set_password_screen.dart';

class ImportWalletScreen extends StatefulWidget {
  const ImportWalletScreen({super.key});

  @override
  State<ImportWalletScreen> createState() => _ImportWalletScreenState();
}

class _ImportWalletScreenState extends State<ImportWalletScreen> {
  final _controller = ObscuringTextEditingController();
  final _focusNode = FocusNode();
  final _buttonKey = GlobalKey();
  bool _isLoading = false;
  String? _error;
  ColdAccount? _account = ColdAccount(label: 'Account 1', index: 0);

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

    final account = _account;
    if (account == null) {
      setState(() => _error = 'Enter a valid account index or derivation path');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Throws on an invalid phrase.
      HdWalletService().keyPairAtPath(mnemonic, account.derivationPath);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SetPasswordScreen(mnemonic: mnemonic, accounts: [account]),
        ),
      );
    } catch (e) {
      debugPrint('Import rejected: $e');
      if (mounted) setState(() => _error = 'Not a valid recovery phrase');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

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
                style: text.body.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 16),
              QuantusTextField(
                controller: _controller,
                focusNode: _focusNode,
                hint: 'Type in or paste your recovery phrase. Separate words with spaces.',
                error: _error,
                height: 202,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                enableSuggestions: false,
                onChanged: (_) => setState(() {}),
                trailing: QuantusIconButton.ghost(
                  icon: _controller.obscured ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  onTap: () => setState(() => _controller.obscured = !_controller.obscured),
                ),
              ),
              const SizedBox(height: 20),
              DerivationField(onChanged: (a) => setState(() => _account = a)),
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
