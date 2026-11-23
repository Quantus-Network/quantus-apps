import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:quantus_desktop_wallet/utils/ascii_field.dart';

// The expected fields and values below were produced by running the website's
// own `ascii.ts`, `base-math.ts` and mode table with the same arguments.
void main() {
  group('chladniRect', () {
    test('matches the website at sample points, time mix included', () {
      expect(chladniRect(-0.5, 0, 1, 2, 0), moreOrLessEquals(1));
      expect(chladniRect(0.3, -0.7, 2, 3, 1.7), moreOrLessEquals(-0.9197356846410705));
      expect(chladniRect(0.3, -0.7, 3, 4, 40), moreOrLessEquals(0.4226752279483633));
    });

    test('the second mode fades out and back as time passes', () {
      // cos(0.18 t) is zero at t = π / 0.36, leaving only the first mode,
      // which is zero on the line y = 0.
      expect(chladniRect(-0.5, 0, 1, 2, math.pi / 0.36), moreOrLessEquals(0));
    });
  });

  group('renderAsciiField', () {
    test('draws the website\'s full field for wave mode 2,3', () {
      expect(renderAsciiField(m: 2, n: 3, t: 1.7, cols: 28, rows: 8).split('\n'), [
        '############################',
        '#           .          .:x++',
        '#          :         |.    .',
        '#.     .,        ..         ',
        '#             x             ',
        '#         ..        ,.     .',
        '#.    .|         :          ',
        '#++x:.          .           ',
      ]);
    });

    test('draws the website\'s full field for wave mode 3,4 later in time', () {
      expect(renderAsciiField(m: 3, n: 4, t: 40, cols: 28, rows: 8).split('\n'), [
        '############################',
        '#       .        +        .,',
        '#.    .x.    .x.    .x.    .',
        '#        ·        x         ',
        '#      x      x      x      ',
        '#         x        ·        ',
        '#.    .x.    .x.    .x.    .',
        '#,.        +        .       ',
      ]);
    });

    test('a partial reveal draws only inside a circle around the centre', () {
      expect(renderAsciiField(m: 1, n: 2, t: 0.3, cols: 28, rows: 8, reveal: 0.5).split('\n'), [
        '                            ',
        '                            ',
        '                            ',
        '                 ,,         ',
        '              x             ',
        '          ,,                ',
        '                            ',
        '                            ',
      ]);
    });

    test('a reveal of 0 is blank apart from the centre point, and a reveal of 1.5 is the full field', () {
      final blank = renderAsciiField(m: 2, n: 3, t: 1.7, cols: 28, rows: 8, reveal: 0);
      expect(blank.replaceAll('\n', '').trim(), 'x');

      expect(
        renderAsciiField(m: 2, n: 3, t: 1.7, cols: 28, rows: 8, reveal: 1.5),
        renderAsciiField(m: 2, n: 3, t: 1.7, cols: 28, rows: 8),
      );
    });

    test('uses only the ramp\'s characters and has the size asked for', () {
      final lines = renderAsciiField(m: 4, n: 3, t: 12.5, cols: 61, rows: 17).split('\n');

      expect(lines, hasLength(17));
      expect(lines.every((line) => line.length == 61), isTrue);
      expect(lines.join().split('').toSet().difference(asciiRamp.split('').toSet()), isEmpty);
    });

    test('with no rows there is nothing to draw', () {
      expect(renderAsciiField(m: 1, n: 2, t: 0, cols: 10, rows: 0), '');
    });
  });

  group('waveModeAt', () {
    test('picks the website\'s mode for a cursor position', () {
      expect(waveModeAt(0, 0), (1, 2));
      expect(waveModeAt(0.5, 0.5), (3, 3));
      expect(waveModeAt(1, 1), (2, 1));
      expect(waveModeAt(0.9, 0.2), (2, 4));
      expect(waveModeAt(0.33, 0.71), (4, 2));
      expect(waveModeAt(0.999, 0.999), (2, 1));
    });
  });
}
