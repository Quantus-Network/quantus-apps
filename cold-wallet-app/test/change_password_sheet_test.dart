import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:quantus_cold_wallet/providers/wallet_providers.dart';
import 'package:quantus_cold_wallet/components/change_password_sheet.dart';

class _HangingController extends WalletController {
  final completer = Completer<PasswordChangeResult>();

  @override
  Future<PasswordChangeResult> changePassword({required String currentPassword, required String newPassword}) =>
      completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const text = AppTextThemeV3.standard();

  Future<void> openSheet(WidgetTester tester, {_HangingController? controller}) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [if (controller != null) walletControllerProvider.overrideWith(() => controller)],
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
  }

  testWidgets('password fields freeze while the rotation is in flight', (tester) async {
    final controller = _HangingController();
    await openSheet(tester, controller: controller);

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

  testWidgets('uses v3 title, body, error, and surface tokens', (tester) async {
    await openSheet(tester);

    final title = tester.widget<Text>(find.text('Change password').first);
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleScreen.fontSize);
    expect(title.style?.fontWeight, text.titleScreen.fontWeight);

    final body = tester.widget<Text>(
      find.textContaining('Your password encrypts the wallet key stored on this device'),
    );
    expect(body.style?.color, colors.textMuted);
    expect(body.style?.fontSize, text.body.fontSize);

    expect(tester.widget<BottomSheet>(find.byType(BottomSheet)).backgroundColor, colors.bgSurface);

    await tester.enterText(find.byType(TextField).at(1), 'beta');
    await tester.enterText(find.byType(TextField).at(2), 'gamma');
    await tester.tap(find.text('Change password').last);
    await tester.pump();

    final error = tester.widget<Text>(find.text('New passwords do not match'));
    expect(error.style?.color, colors.semanticEmber);
    expect(error.style?.fontSize, text.caption.fontSize);
  });

  testWidgets('success state uses sage icon and v3 title', (tester) async {
    final controller = _HangingController();
    await openSheet(tester, controller: controller);

    await tester.enterText(find.byType(TextField).at(1), 'beta');
    await tester.enterText(find.byType(TextField).at(2), 'beta');
    await tester.tap(find.text('Change password').last);
    controller.completer.complete(PasswordChangeResult.changed);
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(find.byIcon(Icons.check_circle_outline_rounded));
    expect(icon.color, colors.semanticSage);

    final title = tester.widget<Text>(find.text('Password changed'));
    expect(title.style?.color, colors.textContent);
    expect(title.style?.fontSize, text.titleScreen.fontSize);
    expect(title.style?.fontWeight, text.titleScreen.fontWeight);
  });
}
