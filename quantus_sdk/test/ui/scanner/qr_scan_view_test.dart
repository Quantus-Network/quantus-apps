import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_sdk/quantus_sdk.dart';

final _header = RegExp(r'^ur:t/(\d+)-(\d+)/');

({int index, int total})? _sequenceFor(String part) {
  final match = _header.firstMatch(part);
  return match == null ? null : (index: int.parse(match[1]!), total: int.parse(match[2]!));
}

UrScanCollector _collector() => UrScanCollector(
  acceptsPart: (part) => part.startsWith('ur:'),
  isComplete: (parts) => parts.isNotEmpty && parts.toSet().length == _sequenceFor(parts.first)!.total,
  sequenceFor: _sequenceFor,
  maxParts: 16,
);

QrDetection _frame(int index, int total) => QrDetection(
  raw: 'ur:t/$index-$total/x',
  corners: const [Offset(500, 300), Offset(580, 300), Offset(580, 380), Offset(500, 380)],
  imageSize: const Size(1280, 720),
);

final _strings = QrScanStrings(
  idleHint: 'Point the camera at the cold wallet',
  collectingLabel: 'RECEIVING',
  progress: (scanned, total) => '$scanned / $total',
  scanning: (scanned) => '$scanned frames',
  stallHint: 'Move closer',
  missingFrames: (shown, more) => 'Missing ${shown.join(', ')}${more > 0 ? ' +$more' : ''}',
  errorHint: 'Could not read the code',
  completeLabel: 'Complete',
);

Future<StreamController<QrDetection>> _pump(
  WidgetTester tester, {
  required Future<void> Function(List<String>) onComplete,
  FutureOr<void> Function(Object)? onError,
}) async {
  final detections = StreamController<QrDetection>();
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Theme(
          data: AppTheme.darkTheme(context),
          child: Scaffold(
            body: SizedBox(
              width: 640,
              height: 360,
              child: QrScanView(
                collector: _collector(),
                detections: detections.stream,
                preview: const ColoredBox(color: Colors.black),
                onComplete: onComplete,
                onError: onError,
                strings: _strings,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  addTearDown(detections.close);
  return detections;
}

void main() {
  testWidgets('shows the hint until frames arrive, then the counter and frame map', (tester) async {
    final detections = await _pump(tester, onComplete: (_) async {});
    expect(find.text('Point the camera at the cold wallet'), findsOneWidget);

    detections.add(_frame(1, 3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.byType(QrFrameMap), findsOneWidget);
    expect(find.byType(QrScanHud), findsOneWidget);

    detections.add(_frame(1, 3));
    await tester.pump();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('hands the collected frames to onComplete once', (tester) async {
    final completions = <List<String>>[];
    final detections = await _pump(tester, onComplete: (parts) async => completions.add(parts));
    detections.add(_frame(2, 2));
    detections.add(_frame(1, 2));
    detections.add(_frame(1, 2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(completions, [
      ['ur:t/2-2/x', 'ur:t/1-2/x'],
    ]);
    expect(find.text('Complete'), findsOneWidget);
  });

  testWidgets('a failed completion is reported and the scan starts over', (tester) async {
    final errors = <Object>[];
    final detections = await _pump(
      tester,
      onComplete: (_) async => throw StateError('bad signature'),
      onError: errors.add,
    );
    detections.add(_frame(1, 1));
    await tester.pump();
    await tester.pump();
    expect(errors, hasLength(1));
    expect(find.text('Could not read the code'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.text('Point the camera at the cold wallet'), findsOneWidget);

    detections.add(_frame(1, 1));
    await tester.pump();
    await tester.pump();
    expect(errors, hasLength(2));
  });
}
