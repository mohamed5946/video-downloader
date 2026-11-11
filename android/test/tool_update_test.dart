// v1.0.5: the download tool self-updates, and extraction failures never
// leak raw technical text to the UI or the diagnostics log.
//
// The FORMATS tests replay the exact field failure from 2026-11-11
// (TikTok link, raw extractor error with a github.com link and a
// "yt-dlp -U" hint on screen) and prove the user now only ever sees
// the generic localized message.
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snapdl/services/engine_service.dart';
import 'package:snapdl/services/log_service.dart';
import 'package:snapdl/services/settings_service.dart';

/// The raw message from the 2026-11-11 field screenshot.
const _fieldError =
    'ERROR: [TikTok] 7706574092282989831: Unable to extract webpage video data; '
    'please report this issue on https://github.com/yt-dlp/yt-dlp/issues?q= , '
    'filling out the appropriate issue template. Confirm you are on the '
    'latest version using  yt-dlp -U';

const _fakeInfoJson = {
  'title': 'Test video',
  'duration': 42,
  'formats': [
    {
      'vcodec': 'avc1',
      'acodec': 'mp4a',
      'ext': 'mp4',
      'height': 720,
      'width': 1280,
      'url': 'https://example.com/v.mp4',
      'filesize': 12345,
    },
    {
      'vcodec': 'none',
      'acodec': 'mp4a',
      'ext': 'm4a',
      'url': 'https://example.com/a.m4a',
    },
  ],
  'thumbnails': [
    {'url': 'https://example.com/t.jpg', 'width': 640},
  ],
};

void main() {
  // Plain test()s (not testWidgets) need the binding initialized before
  // touching TestDefaultBinaryMessengerBinding.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.ensureLoaded();
  });

  group('sanitizeEngineText', () {
    test('strips the field error down to generic words', () {
      final out = EngineService.sanitizeEngineText(_fieldError);
      expect(out, isNot(contains('yt-dlp')));
      expect(out, isNot(contains('github.com')));
      expect(out, isNot(contains('http')));
      expect(out, isNot(contains('youtube-dl')));
      expect(out, isNot(contains('ffmpeg')));
      expect(out, contains('TikTok'));
      expect(out, contains('Unable to extract webpage video data'));
    });

    test('plain text without banned words passes through', () {
      expect(
        EngineService.sanitizeEngineText('Download failed — try again.'),
        'Download failed — try again.',
      );
    });
  });

  group('isUpdateDue', () {
    test('never updated → due', () {
      expect(EngineService.isUpdateDue(0, 1000000), isTrue);
    });

    test('updated 6 days ago → not due', () {
      final now = DateTime(2026, 11, 11).millisecondsSinceEpoch;
      final sixDaysAgo =
          now - const Duration(days: 6).inMilliseconds;
      expect(EngineService.isUpdateDue(sixDaysAgo, now), isFalse);
    });

    test('updated 8 days ago → due', () {
      final now = DateTime(2026, 11, 11).millisecondsSinceEpoch;
      final eightDaysAgo =
          now - const Duration(days: 8).inMilliseconds;
      expect(EngineService.isUpdateDue(eightDaysAgo, now), isTrue);
    });
  });

  group('fetchInfo FORMATS handling', () {
    // NOTE: EngineService is a singleton — the update-once flag is
    // per session. The failure test runs first (its update attempt
    // fails, so the flag stays clear); the retry test runs second.
    setUp(() {
      LogService.instance.clear();
    });

    Future<void> mockEngine(
      Future<dynamic> Function(MethodCall call) handler,
    ) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('com.valor.snapdl/engine'),
        handler,
      );
    }

    test('FORMATS failure shows only the generic message', () async {
      await mockEngine((call) async {
        if (call.method == 'init') return 'test';
        if (call.method == 'fetchFormats') {
          throw PlatformException(code: 'FORMATS', message: _fieldError);
        }
        return null; // updateTool: no update available in this test
      });

      Object? thrown;
      try {
        await EngineService.instance
            .fetchInfo('https://vt.tiktok.com/ZSpaFeLo1/');
      } catch (e) {
        thrown = e;
      }
      expect(thrown, isNotNull);
      final message = thrown.toString();
      expect(message, contains('تعذّر قراءة بيانات هذا الفيديو'));
      expect(message, isNot(contains('yt-dlp')));
      expect(message, isNot(contains('github.com')));
      expect(message, isNot(contains('http')));

      // And the diagnostics log carries the code only — no raw text.
      final logged = LogService.instance.entries
          .map((e) => '${e.message} ${e.detail ?? ''}')
          .join('\n');
      expect(logged, isNot(contains('yt-dlp')));
      expect(logged, isNot(contains('github.com')));
      expect(logged, contains('FORMATS'));
    });

    test('FORMATS failure updates the tool once, then the retry works',
        () async {
      var fetchCalls = 0;
      await mockEngine((call) async {
        if (call.method == 'init') return 'test';
        if (call.method == 'updateTool') {
          return <String, String>{'status': 'done'};
        }
        if (call.method == 'fetchFormats') {
          fetchCalls++;
          if (fetchCalls == 1) {
            throw PlatformException(code: 'FORMATS', message: _fieldError);
          }
          return jsonEncode(_fakeInfoJson);
        }
        return null;
      });

      final info = await EngineService.instance
          .fetchInfo('https://vt.tiktok.com/ZSpaFeLo1/');
      expect(info.title, 'Test video');
      expect(info.durationSeconds, 42);
      expect(info.formats, isNotEmpty);
      expect(fetchCalls, 2);
    });
  });
}
