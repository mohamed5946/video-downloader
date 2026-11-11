// v1.0.7 — speed-test display math: unit formatting, the log-scale
// gauge mapping, and jitter from ping samples.
//
// Pure helpers only (no network, no platform channels): these tests
// pin the exact numbers the gauge and the result cards show.
import 'package:flutter_test/flutter_test.dart';
import 'package:snapdl/services/speed_test_service.dart';

void main() {
  group('formatSpeed', () {
    test('Mbps shows the value as-is with one decimal', () {
      expect(SpeedTestService.formatSpeed(80, 'Mbps'), '80.0 Mbps');
      expect(SpeedTestService.formatSpeed(12.34, 'Mbps'), '12.3 Mbps');
      expect(SpeedTestService.formatSpeed(0, 'Mbps'), '0.0 Mbps');
    });

    test('MB/s divides by 8 with one decimal', () {
      expect(SpeedTestService.formatSpeed(80, 'MB/s'), '10.0 MB/s');
      expect(SpeedTestService.formatSpeed(100, 'MB/s'), '12.5 MB/s');
      expect(SpeedTestService.formatSpeed(0, 'MB/s'), '0.0 MB/s');
    });

    test('unknown unit falls back to Mbps', () {
      expect(SpeedTestService.formatSpeed(42, 'weird'), '42.0 Mbps');
    });
  });

  group('gaugeFraction', () {
    test('0 Mbps → 0 and 1000 Mbps → 1', () {
      expect(SpeedTestService.gaugeFraction(0), 0);
      expect(SpeedTestService.gaugeFraction(1000), 1);
    });

    test('clamps outside 0–1000', () {
      expect(SpeedTestService.gaugeFraction(-5), 0);
      expect(SpeedTestService.gaugeFraction(5000), 1);
    });

    test('monotonic across the dial marks 0, 5, 10, 50, 100, 250, 500, 750, 1000',
        () {
      const marks = [0.0, 5, 10, 50, 100, 250, 500, 750, 1000];
      var prev = -1.0;
      for (final m in marks) {
        final f = SpeedTestService.gaugeFraction(m);
        expect(f, greaterThan(prev), reason: 'fraction must rise at $m');
        expect(f, inInclusiveRange(0.0, 1.0));
        prev = f;
      }
    });

    test('log scale keeps the low end readable', () {
      // 10 Mbps sits about a third of the way round the dial,
      // 100 Mbps about two thirds — not 1% / 10% as a linear scale
      // would give.
      expect(SpeedTestService.gaugeFraction(10), inInclusiveRange(0.3, 0.4));
      expect(SpeedTestService.gaugeFraction(100), inInclusiveRange(0.6, 0.7));
    });
  });

  group('computeJitter', () {
    test('mean absolute difference between successive samples', () {
      // |24-20| = 4, |22-24| = 2 → (4+2)/2 = 3.
      expect(SpeedTestService.computeJitter([20, 24, 22]), 3.0);
    });

    test('steady ping → zero jitter', () {
      expect(SpeedTestService.computeJitter([15, 15, 15]), 0);
    });

    test('fewer than 2 samples → zero jitter', () {
      expect(SpeedTestService.computeJitter([]), 0);
      expect(SpeedTestService.computeJitter([21]), 0);
    });
  });
}
