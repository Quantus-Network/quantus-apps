import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/theme/app_theme.dart';
import 'package:quantus_cold_wallet/widgets/change_password_sheet.dart';

class _HangingController extends WalletController {
  final completer = Completer<PasswordChangeResult>();

  @override
  Future<PasswordChangeResult> changePassword({required String currentPassword, required String newPassword}) =>
      completer.future;
}

void main() {
  testWidgets('password fields freeze while the rotation is in flight', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    final controller = _HangingController();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [walletControllerProvider.overrideWith(() => controller)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Theme(
              data: AppTheme.darkTheme(context),
              child: Scaffold(
                body: Builder(
                  builder: (context) => Center(
                    child: TextButton(onPressed: () => showChangePasswordSheet(context), child: const Text('open')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), 'alpha');
    await tester.enterText(find.byType(TextField).at(1), 'beta');
    await tester.enterText(find.byType(TextField).at(2), 'beta');
    await tester.tap(find.text('Change password').last);
    await tester.pump();

    final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
    expect(fields, hasLength(3));
    for (final field in fields) {
      expect(field.enabled, isFalse);
    }

    controller.completer.complete(PasswordChangeResult.changed);
    await tester.pumpAndSettle();
    expect(find.text('Password changed'), findsOneWidget);
  });
}
