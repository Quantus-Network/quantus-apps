import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/components/password_field.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';

/// Asks for the vault password and verifies it against the vault. Resolves to
/// true only after a successful verification.
Future<bool> showVerifyPasswordSheet(BuildContext context, {required String message}) async {
  final verified = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colorsV3.bgSurface,
    builder: (_) => _VerifyPasswordSheet(message: message),
  );
  return verified == true;
}

class _VerifyPasswordSheet extends ConsumerStatefulWidget {
  final String message;

  const _VerifyPasswordSheet({required this.message});

  @override
  ConsumerState<_VerifyPasswordSheet> createState() => _VerifyPasswordSheetState();
}

class _VerifyPasswordSheetState extends ConsumerState<_VerifyPasswordSheet> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(walletControllerProvider.notifier).unlockWithPassword(_password.text);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }
    setState(() {
      _busy = false;
      _error = 'Incorrect password';
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorsV3;
    final text = context.themeTextV3;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enter password', style: text.titleScreen.copyWith(color: colors.textContent)),
            const SizedBox(height: 8),
            Text(widget.message, style: text.body.copyWith(color: colors.textMuted)),
            const SizedBox(height: 24),
            PasswordField(controller: _password, hintText: 'Password', enabled: !_busy, onSubmitted: (_) => _submit()),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: text.caption.copyWith(color: colors.semanticEmber)),
            ],
            const SizedBox(height: 24),
            QuantusButton.simple(label: 'Continue', isLoading: _busy, onTap: _busy ? null : _submit),
          ],
        ),
      ),
    );
  }
}
