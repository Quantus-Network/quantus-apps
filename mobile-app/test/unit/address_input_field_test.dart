import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';
import 'package:resonance_network_wallet/v2/components/address_input_field.dart';

class _Harness extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onPaste;

  const _Harness({required this.controller, required this.focusNode, required this.onPaste});

  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return AddressInputField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      hasValid: widget.controller.text.isNotEmpty,
      recipientChecksum: null,
      hintText: 'Address',
      trailing: QuantusIconButton.ghost(icon: Icons.paste, onTap: widget.onPaste),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validAddress = 'qzrecipientxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(size: Size(375, 667)),
        child: Builder(
          builder: (context) => MaterialApp(
            theme: AppTheme.darkTheme(context),
            home: Scaffold(body: child),
          ),
        ),
      ),
    );
  }

  FocusNode? pasteFocus(WidgetTester tester) => Focus.maybeOf(tester.element(find.byIcon(Icons.paste)));

  testWidgets('a confirmed address keeps the paste button out of the focus tree', (tester) async {
    final controller = TextEditingController(text: validAddress);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var pasted = false;

    await pump(tester, _Harness(controller: controller, focusNode: focusNode, onPaste: () => pasted = true));

    pasteFocus(tester)?.requestFocus();
    await tester.pump();

    expect(
      pasteFocus(tester)?.hasPrimaryFocus,
      isFalse,
      reason: 'the hidden paste button must not be focusable behind the confirmed-address pill',
    );
    expect(pasted, isFalse);
  });

  testWidgets('an editable field keeps the paste button reachable', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await pump(tester, _Harness(controller: controller, focusNode: focusNode, onPaste: () {}));

    pasteFocus(tester)?.requestFocus();
    await tester.pump();

    expect(
      pasteFocus(tester)?.hasPrimaryFocus,
      isTrue,
      reason: 'paste must stay available to keyboard and switch users while the field is editable',
    );
  });

  testWidgets('tapping the pill clears the address and refocuses the field', (tester) async {
    final controller = TextEditingController(text: validAddress);
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await pump(tester, _Harness(controller: controller, focusNode: focusNode, onPaste: () {}));

    await tester.tap(find.text(AddressFormattingService.formatAddress(validAddress, prefix: 16, postFix: 16)));
    await tester.pumpAndSettle();

    expect(controller.text, isEmpty);
    expect(focusNode.hasPrimaryFocus, isTrue, reason: 'the field must take focus so the user can retype');
  });
}
