import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/services/qr_frame_decoder.dart';
import 'package:zxing2/qrcode.dart';

const _address = 'qzK7cVw3NpR8tLd2YhXm5QsGa9FeZo4UiBn6Tj1Wk8rEy';
const _tickPortName = 'qr-frame-decoder-test-ticks';

/// [text] as a camera would see it: a QR code on a white page.
({Uint8List luma, int width, int height}) _frameOf(String text) {
  const scale = 4;
  const margin = 16;
  final matrix = Encoder.encode(text, ErrorCorrectionLevel.m).matrix!;
  final side = matrix.width * scale + margin * 2;
  final luma = Uint8List(side * side)..fillRange(0, side * side, 255);
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) != 1) continue;
      for (var row = 0; row < scale; row++) {
        final start = (margin + y * scale + row) * side + margin + x * scale;
        luma.fillRange(start, start + scale, 0);
      }
    }
  }
  return (luma: luma, width: side, height: side);
}

String? _neverReturns(Uint8List luma, int width, int height) {
  final ticks = IsolateNameServer.lookupPortByName(_tickPortName)!;
  final watch = Stopwatch()..start();
  while (true) {
    if (watch.elapsedMilliseconds >= 5) {
      ticks.send(1);
      watch.reset();
    }
  }
}

String? _throwsUnexpectedly(Uint8List luma, int width, int height) => throw StateError('a defect in the decoder');

void main() {
  group('decodeQrLuma', () {
    test('reads a real QR code exactly', () {
      final frame = _frameOf(_address);

      expect(decodeQrLuma(frame.luma, frame.width, frame.height), _address);
    });

    test('finds nothing on a blank frame', () {
      const side = 200;
      final blank = Uint8List(side * side)..fillRange(0, side * side, 255);

      expect(decodeQrLuma(blank, side, side), isNull);
    });

    test('counts noise as no code', () {
      const side = 300;
      final random = Random(7);
      final noise = Uint8List.fromList([for (var i = 0; i < side * side; i++) random.nextInt(256)]);

      expect(decodeQrLuma(noise, side, side), isNull);
    });

    test('refuses a frame whose bytes do not match its size', () {
      final frame = _frameOf(_address);

      expect(decodeQrLuma(frame.luma, frame.width + 1, frame.height), isNull);
      expect(decodeQrLuma(frame.luma, 0, 0), isNull);
    });

    test('refuses one part of a multi-part code', () {
      final part = Result(_address, null, BarcodeFormat.qrCode)
        ..putMetadata(ResultMetadataType.structuredAppendSequence, 0x12);

      expect(textOfQrResult(part), isNull);
    });

    test('keeps the text of a whole code', () {
      final whole = Result(_address, null, BarcodeFormat.qrCode);

      expect(textOfQrResult(whole), _address);
    });
  });

  group('QrFrameDecoder', () {
    test('decodes in a worker', () async {
      final decoder = QrFrameDecoder();
      addTearDown(decoder.close);
      final frame = _frameOf(_address);

      expect(await decoder.decode(frame.luma, frame.width, frame.height), _address);
    });

    test('kills a decode that passes its limit, and the next one works', () async {
      final ticks = ReceivePort();
      addTearDown(ticks.close);
      addTearDown(() => IsolateNameServer.removePortNameMapping(_tickPortName));
      IsolateNameServer.registerPortWithName(ticks.sendPort, _tickPortName);
      var tickCount = 0;
      ticks.listen((_) => tickCount++);

      final stuck = QrFrameDecoder(limit: const Duration(milliseconds: 200), decoder: _neverReturns);
      addTearDown(stuck.close);
      final frame = _frameOf(_address);

      expect(await stuck.decode(frame.luma, frame.width, frame.height), isNull);
      expect(tickCount, greaterThan(0), reason: 'The worker should have been running.');

      // Ticks already sent arrive first; after that a live worker would add more.
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final afterKill = tickCount;
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(tickCount, afterKill, reason: 'The worker should be dead.');

      final next = QrFrameDecoder();
      addTearDown(next.close);
      expect(await next.decode(frame.luma, frame.width, frame.height), _address);
    });

    test('reports a decoder that fails in a way it should not', () async {
      final decoder = QrFrameDecoder(decoder: _throwsUnexpectedly);
      addTearDown(decoder.close);
      final frame = _frameOf(_address);

      await expectLater(decoder.decode(frame.luma, frame.width, frame.height), throwsA(isA<QrDecodeFailure>()));
    });

    test('decodes one frame at a time', () async {
      final decoder = QrFrameDecoder();
      addTearDown(decoder.close);
      final frame = _frameOf(_address);

      final first = decoder.decode(frame.luma, frame.width, frame.height);
      await expectLater(decoder.decode(frame.luma, frame.width, frame.height), throwsStateError);
      expect(await first, _address);
    });

    test('closing it ends a decode in flight with no code', () async {
      final ticks = ReceivePort();
      addTearDown(ticks.close);
      addTearDown(() => IsolateNameServer.removePortNameMapping(_tickPortName));
      IsolateNameServer.registerPortWithName(ticks.sendPort, _tickPortName);
      final tick = Completer<void>();
      ticks.listen((_) {
        if (!tick.isCompleted) tick.complete();
      });

      final decoder = QrFrameDecoder(limit: const Duration(minutes: 1), decoder: _neverReturns);
      final frame = _frameOf(_address);
      final decoding = decoder.decode(frame.luma, frame.width, frame.height);
      await tick.future;

      decoder.close();

      expect(await decoding, isNull);
    });
  });
}
