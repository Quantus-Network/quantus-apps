import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/scaffold_base.dart';
import 'package:resonance_network_wallet/v2/components/v2_app_bar.dart';
import 'package:resonance_network_wallet/v2/screens/pos/pos_qr_screen.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

class PosAmountScreen extends ConsumerStatefulWidget {
  const PosAmountScreen({super.key});

  @override
  ConsumerState<PosAmountScreen> createState() => _PosAmountScreenState();
}

class _PosAmountScreenState extends ConsumerState<PosAmountScreen> {
  String _input = '0';
  final _fmt = NumberFormattingService();

  void _onDigit(String digit) {
    setState(() {
      if (_input == '0' && digit != '.') {
        _input = digit;
      } else if (digit == '.' && _input.contains('.')) {
        return;
      } else if (_input.contains('.') && _input.split('.').last.length >= 12) {
        return;
      } else {
        _input += digit;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_input.length <= 1) {
        _input = '0';
      } else {
        _input = _input.substring(0, _input.length - 1);
      }
    });
  }

  void _onClear() => setState(() => _input = '0');

  void _onCharge() {
    final amount = _fmt.parseAmount(_input);
    if (amount == null || amount <= BigInt.zero) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PosQrScreen(amount: _input)),
    );
  }

  bool get _isValid {
    final amount = _fmt.parseAmount(_input);
    return amount != null && amount > BigInt.zero;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return ScaffoldBase(
      appBar: const V2AppBar(title: 'New Charge'),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$_input ${AppConstants.tokenSymbol}',
                  style: text.extraLargeTitle?.copyWith(
                    color: colors.textPrimary,
                    fontSize: 56,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          _buildKeypad(colors, text),
          const SizedBox(height: 16),
          _buildChargeButton(colors, text),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildKeypad(AppColorsV2 colors, AppTextTheme text) {
    const keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['.', '0', 'backspace'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((key) => _buildKey(key, colors, text)).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildKey(String key, AppColorsV2 colors, AppTextTheme text) {
    return Expanded(
      child: GestureDetector(
        onTap: () => key == 'backspace' ? _onBackspace() : _onDigit(key),
        onLongPress: key == 'backspace' ? _onClear : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 60,
          alignment: Alignment.center,
          child: key == 'backspace'
              ? Icon(Icons.backspace_outlined, color: colors.textPrimary, size: 28)
              : Text(
                  key,
                  style: text.mediumTitle?.copyWith(color: colors.textPrimary, fontSize: 28),
                ),
        ),
      ),
    );
  }

  Widget _buildChargeButton(AppColorsV2 colors, AppTextTheme text) {
    final disabled = !_isValid;
    return GestureDetector(
      onTap: disabled ? null : _onCharge,
      child: Container(
        width: double.infinity,
        height: 58,
        decoration: BoxDecoration(
          color: disabled ? colors.buttonDisabled : colors.accentGreen,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: Text(
            _isValid ? 'Charge $_input ${AppConstants.tokenSymbol}' : 'Enter Amount',
            style: text.smallTitle?.copyWith(
              color: disabled ? colors.textTertiary : Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
