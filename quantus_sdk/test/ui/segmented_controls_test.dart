import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('exposes button labels and selected state to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    var selected = 0;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) => SegmentedControls<int>(
                  items: const [
                    SegmentedControlItem(value: 0, label: 'Account index'),
                    SegmentedControlItem(value: 1, label: 'Derivation path'),
                  ],
                  selectedValue: selected,
                  onChanged: (value) => setState(() => selected = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Finder segment(String label) =>
        find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == label);

    final accountIndex = tester.getSemantics(segment('Account index'));
    final derivationPath = tester.getSemantics(segment('Derivation path'));
    expect(accountIndex.flagsCollection.isButton, isTrue);
    expect(accountIndex.flagsCollection.isSelected, ui.Tristate.isTrue);
    expect(derivationPath.flagsCollection.isButton, isTrue);
    expect(derivationPath.flagsCollection.isSelected, ui.Tristate.isFalse);

    await tester.tap(find.text('Derivation path'));
    await tester.pumpAndSettle();

    expect(tester.getSemantics(segment('Account index')).flagsCollection.isSelected, ui.Tristate.isFalse);
    expect(tester.getSemantics(segment('Derivation path')).flagsCollection.isSelected, ui.Tristate.isTrue);
    semantics.dispose();
  });
}
