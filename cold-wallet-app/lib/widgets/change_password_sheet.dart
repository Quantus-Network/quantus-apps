import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_cold_wallet/components/quantus_button.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_colors.dart';
import 'package:quantus_cold_wallet/theme/app_text_styles.dart';
import 'package:quantus_cold_wallet/widgets/password_field.dart';

/// Action pane for setting or changing the vault password. Resolves to true
/// when the password was changed.
Future<bool> showChangePasswordSheet(BuildContext context) async {
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.sheetBackground,
    builder: (_) => const _ChangePasswordSheet(),
  );
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
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text != _confirm.text) {
      setState(() => _error = 'New passwords do not match');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ok = await ref
          .read(walletControllerProvider.notifier)
          .changePassword(currentPassword: _current.text, newPassword: _next.text);
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _busy = false;
          _error = 'Current password is incorrect';
        });
        return;
      }
      setState(() {
        _busy = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Could not change password: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.themeText;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: _done ? _successContent(colors, text) : _formContent(colors, text),
      ),
    );
  }

  Widget _successContent(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(Icons.check_circle_outline_rounded, size: 48, color: colors.success),
        const SizedBox(height: 16),
        Text(
          'Password changed',
          style: text.smallTitle?.copyWith(color: colors.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        QuantusButton.simple(label: 'Done', onTap: () => Navigator.pop(context, true)),
      ],
    );
  }

  Widget _formContent(AppColorsV2 colors, AppTextTheme text) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Change password', style: text.smallTitle?.copyWith(color: colors.textPrimary)),
        const SizedBox(height: 8),
        Text(
          'Your password encrypts the wallet key stored on this device. If you never set one, leave the current '
          'password empty.',
          style: text.detail?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 24),
        PasswordField(controller: _current, hintText: 'Current password'),
        const SizedBox(height: 12),
        PasswordField(controller: _next, hintText: 'New password'),
        const SizedBox(height: 12),
        PasswordField(controller: _confirm, hintText: 'Confirm new password', onSubmitted: (_) => _submit()),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: text.detail?.copyWith(color: colors.error)),
        ],
        const SizedBox(height: 24),
        QuantusButton.simple(label: 'Change password', isLoading: _busy, onTap: _busy ? null : _submit),
      ],
    );
  }
}
