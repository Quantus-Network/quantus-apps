import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const colors = AppColorsV3.dark();
  const labels = ScannerLabels(
    back: 'Back',
    torch: 'Torch',
    gallery: 'Gallery',
    cameraUnavailable: 'Camera unavailable',
    cameraPermissionDenied: 'Allow camera access',
    retry: 'Try again',
  );

  late MobileScannerController controller;

  setUp(() => controller = MobileScannerController());
  tearDown(() => controller.dispose());

  final window = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is ScanFramePainter);

  Future<void> pumpScanner(
    WidgetTester tester, {
    Widget? caption,
    Widget? footer,
    VoidCallback? onPickImage,
    String? busyLabel,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      Builder(
        builder: (context) => MaterialApp(
          theme: AppTheme.darkTheme(context),
          home: QuantusScanner(
            controller: controller,
            onDetect: (_) {},
            labels: labels,
            caption: caption,
            footer: footer,
            onPickImage: onPickImage,
            busyLabel: busyLabel,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void failCamera(MobileScannerErrorCode code) {
    controller.value = controller.value.copyWith(isInitialized: true, error: MobileScannerException(errorCode: code));
  }

  testWidgets('lays the Figma scanner out: Back, a centred 280 window, flare brackets, torch below', (tester) async {
    await pumpScanner(tester);

    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, colors.bgVoid);
    expect(tester.widget<Text>(find.text('Back')).style?.color, colors.textWhite);
    expect(tester.getRect(window), const Rect.fromLTWH(55, 282, 280, 280));

    final painter = tester.widget<CustomPaint>(window).painter! as ScanFramePainter;
    expect(painter.accent, colors.accentFlare);
    expect(painter.scrim, colors.bgVoid.useOpacity(0.8));
    expect(painter.radius, 32);

    expect(tester.getTopLeft(find.byType(ScannerControl)).dy, 611);
    expect(find.text('Torch'), findsOneWidget);
    expect(find.text('Gallery'), findsNothing);
    expect(find.byType(Icon), findsNothing, reason: 'the scanner draws no Material icons of its own');
  });

  testWidgets('offers the gallery only to callers that can read a still image', (tester) async {
    var picked = 0;
    await pumpScanner(tester, onPickImage: () => picked++);

    await tester.tap(find.text('Gallery'));

    expect(picked, 1);
  });

  testWidgets('keeps the full window while a caption and a footer still leave room for it', (tester) async {
    await pumpScanner(
      tester,
      caption: const SizedBox(key: Key('caption'), height: 100),
      footer: const SizedBox(key: Key('footer'), height: 150),
    );

    final frame = tester.getRect(window);
    expect(frame.size, const Size.square(280));
    expect(frame.top, greaterThanOrEqualTo(tester.getRect(find.byKey(const Key('caption'))).bottom + 24));
    expect(
      tester.getRect(find.byType(ScannerControl)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(const Key('footer'))).top - 24),
    );
  });

  testWidgets('shrinks the window rather than let it run into a tall footer', (tester) async {
    await pumpScanner(
      tester,
      caption: const SizedBox(key: Key('caption'), height: 100),
      footer: const SizedBox(key: Key('footer'), height: 220),
    );

    final frame = tester.getRect(window);
    expect(frame.width, lessThan(280));
    expect(frame.width, frame.height);
    expect(frame.center.dx, 195);
    expect(frame.top, greaterThanOrEqualTo(tester.getRect(find.byKey(const Key('caption'))).bottom + 24));
    expect(
      tester.getRect(find.byType(ScannerControl)).bottom,
      lessThanOrEqualTo(tester.getRect(find.byKey(const Key('footer'))).top - 24),
    );
  });

  testWidgets('inverts the torch control while the torch is lit', (tester) async {
    await pumpScanner(tester);
    expect(tester.widget<ScannerControl>(find.byType(ScannerControl)).isActive, isFalse);

    controller.value = controller.value.copyWith(torchState: TorchState.on);
    await tester.pump();

    expect(tester.widget<ScannerControl>(find.byType(ScannerControl)).isActive, isTrue);
  });

  testWidgets('keeps the whole layout over a placeholder when the device has no camera', (tester) async {
    await pumpScanner(tester);
    failCamera(MobileScannerErrorCode.unsupported);
    await tester.pump();

    expect(tester.getRect(window), const Rect.fromLTWH(55, 282, 280, 280));
    expect(find.text('Torch'), findsOneWidget);
    expect(find.text('Camera unavailable'), findsOneWidget);
    expect(find.text('Allow camera access'), findsNothing);
    expect(find.text('Try again'), findsNothing);
    expect(
      find.byWidgetPredicate((w) => w is ColoredBox && w.color == colors.bgSurface2),
      findsOneWidget,
      reason: 'the camera preview is replaced by a surface placeholder',
    );
  });

  testWidgets('explains a denied camera permission and offers a retry', (tester) async {
    await pumpScanner(tester);
    failCamera(MobileScannerErrorCode.permissionDenied);
    await tester.pump();

    expect(find.text('Camera unavailable'), findsOneWidget);
    expect(find.text('Allow camera access'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('holds the camera notice after the plugin drops the error, until the camera runs', (tester) async {
    await pumpScanner(tester);
    failCamera(MobileScannerErrorCode.permissionDenied);
    await tester.pump();

    controller.value = controller.value.copyWith(torchState: TorchState.unavailable);
    await tester.pump();

    expect(controller.value.error, isNull);
    expect(find.text('Camera unavailable'), findsOneWidget);

    controller.value = controller.value.copyWith(isRunning: true);
    await tester.pump();

    expect(find.text('Camera unavailable'), findsNothing);
  });

  testWidgets('offers no retry when a camera that does not exist is started again', (tester) async {
    await pumpScanner(tester);
    failCamera(MobileScannerErrorCode.unsupported);
    await tester.pump();

    failCamera(MobileScannerErrorCode.controllerAlreadyInitialized);
    await tester.pump();

    expect(find.text('Camera unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets('covers the screen with the busy label while the caller works', (tester) async {
    await pumpScanner(tester, busyLabel: 'Submitting transaction...');
    failCamera(MobileScannerErrorCode.unsupported);
    await tester.pump();

    expect(find.text('Submitting transaction...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Camera unavailable'), findsNothing, reason: 'the notice would sit under the spinner');
  });
}
