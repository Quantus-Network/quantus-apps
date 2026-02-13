import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/back_button.dart';
import 'package:resonance_network_wallet/v2/components/glass_container.dart';
import 'package:resonance_network_wallet/v2/components/gradient_background.dart';
import 'package:resonance_network_wallet/v2/components/success_check.dart';
import 'package:resonance_network_wallet/v2/theme/app_colors.dart';
import 'package:resonance_network_wallet/v2/theme/app_text_styles.dart';

enum _Step { enterCurrent, enterNew, confirmNew, success }

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends State<ChangePinScreen> {
  final _settingsService = SettingsService();
  final _focusNode = FocusNode();
  final _controller = TextEditingController();
  var _step = _Step.enterCurrent;
  String _newPin = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExistingPin();
    _controller.addListener(() {
      setState(() => _error = null);
      if (_controller.text.length == 6) _onContinue();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkExistingPin() async {
    final has = await _settingsService.hasPin();
    if (!mounted) return;
    setState(() => _step = has ? _Step.enterCurrent : _Step.enterNew);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  Future<void> _onContinue() async {
    final entry = _controller.text;
    if (entry.length != 6) return;

    switch (_step) {
      case _Step.enterCurrent:
        final ok = await _settingsService.verifyPin(entry);
        if (!ok) {
          setState(() => _error = 'Incorrect PIN');
          HapticFeedback.heavyImpact();
          return;
        }
        _controller.clear();
        setState(() => _step = _Step.enterNew);
        _focusNode.requestFocus();
      case _Step.enterNew:
        _newPin = entry;
        _controller.clear();
        setState(() => _step = _Step.confirmNew);
        _focusNode.requestFocus();
      case _Step.confirmNew:
        if (entry != _newPin) {
          setState(() => _error = 'PINs do not match');
          HapticFeedback.heavyImpact();
          return;
        }
        await _settingsService.setPin(_newPin);
        _focusNode.unfocus();
        setState(() => _step = _Step.success);
        HapticFeedback.mediumImpact();
      case _Step.success:
        break;
    }
  }

  String get _stepTitle {
    switch (_step) {
      case _Step.enterCurrent:
        return 'Enter Current PIN';
      case _Step.enterNew:
        return 'Enter New PIN';
      case _Step.confirmNew:
        return 'Confirm New PIN';
      case _Step.success:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Scaffold(
      backgroundColor: colors.background,
      resizeToAvoidBottomInset: false,
      body: GradientBackground(
        child: SafeArea(
          child: Stack(
            children: [
              Opacity(
                opacity: 0,
                child: SizedBox(
                  height: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    keyboardType: TextInputType.number,
                    keyboardAppearance: Brightness.dark,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    decoration: const InputDecoration(counterText: ''),
                  ),
                ),
              ),
              Column(
                children: [
                  const SizedBox(height: 16),
                  _header(colors, text),
                  Expanded(child: _step == _Step.success ? _successBody(colors, text) : _pinBody(colors, text)),
                  if (_step == _Step.success) ...[_doneButton(colors, text), const SizedBox(height: 24)],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(AppColorsV2 colors, AppTextTheme text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const AppBackButton(),
          Text('Change PIN', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _pinBody(AppColorsV2 colors, AppTextTheme text) {
    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          const SizedBox(height: 80),
          Text(
            _stepTitle,
            style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 24, fontWeight: FontWeight.w400),
          ),
          const SizedBox(height: 32),
          _pinDots(colors),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: text.detail?.copyWith(color: colors.error)),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  Widget _pinDots(AppColorsV2 colors) {
    final entry = _controller.text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (i) {
        final filled = i < entry.length;
        return Container(
          width: 40,
          height: 48,
          margin: EdgeInsets.only(left: i == 0 ? 0 : 8),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset('assets/v2/pin_number_background.png', width: 40, height: 48),
              if (filled)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _successBody(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      children: [
        const Spacer(flex: 2),
        const SuccessCheck(),
        const SizedBox(height: 64),
        Text('PIN Changed', style: text.smallTitle?.copyWith(color: colors.textPrimary, fontSize: 20)),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'Your PIN has been updated successfully',
            style: text.paragraph?.copyWith(color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
        const Spacer(flex: 3),
      ],
    );
  }

  Widget _doneButton(AppColorsV2 colors, AppTextTheme text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: GlassContainer(
          asset: GlassContainer.wideAsset,
          filled: true,
          child: Center(
            child: Text(
              'Done',
              style: text.paragraph?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}
