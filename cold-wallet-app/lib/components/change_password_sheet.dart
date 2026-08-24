import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

/// Action pane for setting or changing the vault password. Resolves to true
/// when the password was changed.
Future<bool> showChangePasswordSheet(BuildContext context) async {
  final changed = await BottomSheetContainer.show<bool>(context, builder: (_) => const _ChangePasswordSheet());
  return changed == true;
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _done = false;
  bool _biometricDisabled = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_next.text != _confirm.text) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(walletControllerProvider.notifier)
          .changePassword(currentPassword: _current.text, newPassword: _next.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        switch (result) {
          case PasswordChangeResult.wrongPassword:
            _error = 'Current password is incorrect';
          case PasswordChangeResult.changed:
            _done = true;
          case PasswordChangeResult.changedBiometricDisabled:
            _done = true;
            _biometricDisabled = true;
        }
      });
    } catch (e, st) {
      debugPrint('Change password failed before commit: $e\n$st');
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not change password because secure storage failed. Nothing was changed.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    // The rotation must not look cancellable once it is running: block barrier
    // taps and back navigation until the result lands in this sheet.
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: BottomSheetContainer(
          title: _done ? 'Password changed' : 'Change password',
          child: _done ? _successContent(colors, text) : _formContent(colors, text),
        ),
      ),
    );
  }

  Widget _successContent(AppColorsV3 colors, AppTextThemeV3 text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle_outline_rounded, size: 48, color: colors.semanticSage),
        if (_biometricDisabled) ...[
          const SizedBox(height: 12),
          Text(
            'Biometric unlock was turned off because its key could not be updated for the new password. '
            'Unlock with your password.',
            style: text.body.copyWith(color: colors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        QuantusButton.simple(label: 'Done', onTap: () => Navigator.pop(context, true)),
      ],
    );
  }

  Widget _formContent(AppColorsV3 colors, AppTextThemeV3 text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your password encrypts the wallet key stored on this device. If you never set one, leave the current '
          'password empty.',
          style: text.body.copyWith(color: colors.textMuted),
        ),
        const SizedBox(height: 24),
        QuantusPasswordField(controller: _current, hint: 'Current password', enabled: !_busy),
        const SizedBox(height: 12),
        QuantusPasswordField(controller: _next, hint: 'New password', enabled: !_busy),
        const SizedBox(height: 12),
        QuantusPasswordField(
          controller: _confirm,
          hint: 'Confirm new password',
          enabled: !_busy,
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: text.caption.copyWith(color: colors.semanticEmber)),
        ],
        const SizedBox(height: 24),
        QuantusButton.simple(label: 'Change password', isLoading: _busy, onTap: _busy ? null : _submit),
      ],
    );
  }
}
