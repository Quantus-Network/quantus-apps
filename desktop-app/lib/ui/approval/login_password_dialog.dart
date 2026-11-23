import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quantus_desktop_wallet/providers/password_prompt_provider.dart';
import 'package:quantus_desktop_wallet/services/login_password.dart';
import 'package:quantus_desktop_wallet/ui/components/sheet_button.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:wallet_core/providers/l10n_provider.dart';

/// A check that could not be made, which closes the dialog.
class _CheckFailure {
  const _CheckFailure(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}

/// Shows [request] as a dialog over the window and answers whether a
/// password the person typed passed its check: false if they gave up. A
/// check that could not be made closes the dialog and is thrown.
Future<bool> showLoginPasswordDialog(BuildContext context, PasswordPromptRequest request) async {
  final outcome = await showGeneralDialog<Object>(
    context: context,
    // A stray click must not throw away a typed password: only Cancel and
    // Escape close the dialog.
    barrierDismissible: false,
    barrierColor: context.colorsV3.bgVoid.useOpacity(0.55),
    transitionDuration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 150),
    pageBuilder: (_, _, _) => Center(child: LoginPasswordDialog(request: request)),
  );
  return switch (outcome) {
    _CheckFailure(:final error, :final stackTrace) => Error.throwWithStackTrace(error, stackTrace),
    true => true,
    _ => false,
  };
}

/// Asks for the login password of the person at the computer, where the
/// system has no prompt of its own for the app to use (Linux). The password
/// is checked by the system; a wrong one can be tried again.
class LoginPasswordDialog extends ConsumerStatefulWidget {
  const LoginPasswordDialog({super.key, required this.request});

  final PasswordPromptRequest request;

  static const fieldKey = Key('login-password-field');
  static const confirmKey = Key('login-password-confirm');
  static const cancelKey = Key('login-password-cancel');

  static const double width = 380;

  @override
  ConsumerState<LoginPasswordDialog> createState() => _LoginPasswordDialogState();
}

class _LoginPasswordDialogState extends ConsumerState<LoginPasswordDialog> {
  final _password = TextEditingController();
  final _field = FocusNode();

  /// Whether the system is checking a password. The check cannot be
  /// interrupted, so nothing closes the dialog meanwhile.
  bool _isChecking = false;
  bool _wasRefused = false;

  /// The last thing the system said during a check, such as a fingerprint
  /// reader's instructions.
  String? _message;

  @override
  void initState() {
    super.initState();
    // Confirm follows whether there is anything to submit.
    _password.addListener(_rebuild);
    _field.requestFocus();
  }

  @override
  void dispose() {
    _password.dispose();
    _field.dispose();
    super.dispose();
  }

  void _rebuild() => setState(() {});

  void _cancel() {
    if (_isChecking) return;
    Navigator.of(context).pop(false);
  }

  Future<void> _submit() async {
    if (_isChecking) return;
    final password = _password.text;
    if (password.isEmpty) {
      // Enter gave the field's focus up; typing goes on.
      _field.requestFocus();
      return;
    }
    setState(() {
      _isChecking = true;
      _wasRefused = false;
      _message = null;
    });

    final LoginPasswordResult result;
    try {
      result = await widget.request.check(
        password,
        onMessage: (message) {
          if (mounted) setState(() => _message = message);
        },
      );
    } catch (error, stackTrace) {
      if (mounted) Navigator.of(context).pop(_CheckFailure(error, stackTrace));
      return;
    }
    if (!mounted) return;
    if (result == LoginPasswordResult.accepted) {
      Navigator.of(context).pop(true);
      return;
    }

    _password.clear();
    setState(() {
      _isChecking = false;
      _wasRefused = true;
    });
    // Once the field can take the focus again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _field.requestFocus();
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
    _cancel();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(l10nProvider);
    final colors = context.colorsV3;
    final text = context.themeTextV3;
    final body = text.body.copyWith(height: 1.5, color: colors.textMuted);
    final message = _message;

    // A scope of its own, so Escape is heard wherever the focus is in the
    // dialog, and when nothing in it has the focus.
    return FocusScope(
      onKeyEvent: _onKey,
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: LoginPasswordDialog.width,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colors.bgSurface,
            borderRadius: context.radiusV3.lgBorder,
            border: Border.all(color: colors.borderEmphasis),
            boxShadow: [BoxShadow(color: colors.bgVoid.useOpacity(0.7), blurRadius: 48, offset: const Offset(0, 18))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.desktopPasswordPromptTitle, style: text.titleScreen.copyWith(color: colors.textContent)),
              const SizedBox(height: 6),
              Text(widget.request.reason, style: body),
              const SizedBox(height: 18),
              Opacity(
                opacity: _isChecking ? 0.5 : 1,
                child: QuantusTextField(
                  key: LoginPasswordDialog.fieldKey,
                  controller: _password,
                  focusNode: _field,
                  enabled: !_isChecking,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  hint: l10n.desktopPasswordPromptHint,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  textStyle: text.body,
                  fillColor: colors.bgVoid,
                  borderRadius: context.radiusV3.smBorder,
                ),
              ),
              if (_wasRefused) ...[
                const SizedBox(height: 8),
                Text(l10n.desktopPasswordPromptWrong, style: body.copyWith(color: colors.semanticEmber)),
              ],
              if (message != null) ...[const SizedBox(height: 8), Text(message, style: body)],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SheetButton(
                    key: LoginPasswordDialog.cancelKey,
                    label: l10n.commonCancel,
                    kind: SheetButtonKind.secondary,
                    isDisabled: _isChecking,
                    onTap: _cancel,
                  ),
                  const SizedBox(width: 10),
                  SheetButton(
                    key: LoginPasswordDialog.confirmKey,
                    label: l10n.desktopPasswordPromptConfirm,
                    isDisabled: _password.text.isEmpty,
                    isLoading: _isChecking,
                    onTap: _submit,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
