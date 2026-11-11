// v1.0.7 — in-app update download progress math.
//
// UpdateDownloadProgress.compute is pure (no network, no platform
// channels): percent from received/total, ETA from the remaining
// bytes at the current speed, plus the speed/ETA strings the update
// card shows.
import 'package:flutter_test/flutter_test.dart';
import 'package:snapdl/services/update_service.dart';

void main() {
  group('UpdateDownloadProgress.compute', () {
    test('half downloaded at 100 B/s → 50% and 5 s left', () {
      final p = UpdateDownloadProgress.compute(
        received: 500,
        total: 1000,
        speedBps: 100,
      );
      expect(p.percent, 0.5);
      expect(p.etaSeconds, 5);
      expect(p.received, 500);
      expect(p.total, 1000);
      expect(p.speedBps, 100);
    });

    test('total 0 (unknown size) → percent 0, eta 0', () {
      final p = UpdateDownloadProgress.compute(
        received: 1234,
        total: 0,
        speedBps: 100,
      );
      expect(p.percent, 0);
      expect(p.etaSeconds, 0);
    });

    test('unknown speed → eta 0, never infinite', () {
      final p = UpdateDownloadProgress.compute(
        received: 500,
        total: 1000,
        speedBps: 0,
      );
      expect(p.percent, 0.5);
      expect(p.etaSeconds, 0);
    });

    test('finished download → 100% and eta 0', () {
      final p = UpdateDownloadProgress.compute(
        received: 1000,
        total: 1000,
        speedBps: 500,
      );
      expect(p.percent, 1.0);
      expect(p.etaSeconds, 0);
    });

    test('received past total clamps percent to 1 and eta to 0', () {
      final p = UpdateDownloadProgress.compute(
        received: 1200,
        total: 1000,
        speedBps: 500,
      );
      expect(p.percent, 1.0);
      expect(p.etaSeconds, 0);
    });

    test('ETA rounds up to the next whole second', () {
      // 501 bytes left at 100 B/s = 5.01 s → 6 s.
      final p = UpdateDownloadProgress.compute(
        received: 499,
        total: 1000,
        speedBps: 100,
      );
      expect(p.etaSeconds, 6);
    });
  });

  group('speedText / etaText', () {
    test('speed formats as MB/s, KB/s or B/s', () {
      expect(
        UpdateDownloadProgress.compute(
                received: 0, total: 100, speedBps: 2.5 * 1024 * 1024)
            .speedText,
        '2.5 MB/s',
      );
      expect(
        UpdateDownloadProgress.compute(
                received: 0, total: 100, speedBps: 2048)
            .speedText,
        '2 KB/s',
      );
      expect(
        UpdateDownloadProgress.compute(
                received: 0, total: 100, speedBps: 512)
            .speedText,
        '512 B/s',
      );
      expect(
        UpdateDownloadProgress.compute(
                received: 0, total: 100, speedBps: 0)
            .speedText,
        '—',
      );
    });

    test('ETA formats as mm:ss', () {
      expect(
        UpdateDownloadProgress.compute(
                received: 0, total: 8300, speedBps: 100)
            .etaText,
        '01:23',
      );
      expect(
        UpdateDownloadProgress.compute(
                received: 0, total: 0, speedBps: 0)
            .etaText,
        '00:00',
      );
    });
  });
}
