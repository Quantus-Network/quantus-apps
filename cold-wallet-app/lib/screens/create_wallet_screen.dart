import 'package:flutter/material.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/advanced_section.dart';
import 'package:quantus_cold_wallet/components/scheme_picker.dart';
import 'package:quantus_cold_wallet/models/cold_account.dart';
import 'package:quantus_cold_wallet/screens/set_password_screen.dart';

class CreateWalletScreen extends StatefulWidget {
  const CreateWalletScreen({super.key});

  @override
  State<CreateWalletScreen> createState() => _CreateWalletScreenState();
}

class _CreateWalletScreenState extends State<CreateWalletScreen> {
  List<String>? _words;
  DilithiumScheme _scheme = DilithiumSchemeExtension.current;

  @override
  void initState() {
    super.initState();
    _generate();
  }

  Future<void> _generate() async {
    final mnemonic = await SubstrateService().generateMnemonic();
    if (!mounted) return;
    setState(() => _words = mnemonic.split(' '));
  }

  void _continue() {
    final words = _words;
    if (words == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SetPasswordScreen(
          mnemonic: words.join(' '),
          accounts: [ColdAccount(label: 'Account 1', index: 0, scheme: _scheme)],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final words = _words;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'Recovery phrase'),
      mainContent: words == null
          ? const Center(child: Loader(size: 24))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Write these words down in order and keep them offline. Anyone with this phrase controls your funds. '
                  'It is never shown again and cannot be copied from this device.',
                  style: text.body.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MnemonicGrid(words: words, isRevealed: true),
                        const SizedBox(height: 24),
                        _advancedSection(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      bottomContent: ScaffoldBaseBottomContent(
        child: QuantusButton.simple(label: "I've written it down", onTap: words == null ? null : _continue),
      ),
    );
  }

  /// Signature-scheme choice, collapsed by default so ordinary users never see
  /// it. New wallets stay ML-DSA-65 unless the user opts into ML-DSA-87 here.
  Widget _advancedSection(BuildContext context) {
    return AdvancedSection(
      children: [SchemePicker(value: _scheme, onChanged: (scheme) => setState(() => _scheme = scheme))],
    );
  }
}
