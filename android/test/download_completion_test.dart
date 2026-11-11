// v1.0.6 — completion recovery, first-run update order, mid-fetch
// tool refresh, and per-format byte sizes.
// The 2026-11-11 field reports: a download stuck at 100% with a
// complete file, a first paste that failed on a fresh install, and a
// FORMATS retry skipped because an update had already run.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapdl/services/download_controller.dart';
import 'package:snapdl/services/engine_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.valor.snapdl/engine');

  // The same fake info payload as tool_update_test, with filesizes so
  // the sizeBytes math is checkable.
  Map<String, dynamic> fakeInfoJson() => {
        'title': 'عمرك سألت نفسك ليه بارتيشن الـ C دايماً أحمر؟',
        'duration': 70,
        'thumbnail': '',
        'webpageUrl': 'https://vt.tiktok.com/ZSpa2eeKL/',
        'formats': [
          {
            'format_id': 'f398',
            'height': 720,
            'filesize': 12345,
            'vcodec': 'avc1',
            'ext': 'mp4',
            'acodec': 'none',
          },
          {
            'format_id': 'f251',
            'height': 0,
            'filesize': 5432,
            'vcodec': 'none',
            'ext': 'webm',
            'acodec': 'opus',
          },
        ],
      };

  group('v1.0.6 first-run init', () {
    late List<String> calls;
    late int fetchCalls;
    late int updateCalls;

    setUp(() {
      calls = [];
      fetchCalls = 0;
      updateCalls = 0;
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        calls.add(call.method);
        switch (call.method) {
          case 'init':
            return 'test';
          case 'updateTool':
            updateCalls++;
            return {'status': 'done', 'version': '2026.10.26'};
          case 'fetchFormats':
            fetchCalls++;
            return jsonEncode(fakeInfoJson());
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
        'first fetch on a fresh install finishes the tool update '
        'BEFORE fetching formats', () async {
      // toolLastCheckMs == 0 here (fresh SharedPreferences): the
      // first-run update must be awaited inside init(), so the order
      // is init -> updateTool -> fetchFormats.
      final info = await EngineService.instance.fetchInfo(
        'https://vt.tiktok.com/ZSpa2eeKL/',
      );
      expect(info.title, contains('بارتيشن'));
      expect(
        calls.indexOf('updateTool'),
        lessThan(calls.indexOf('fetchFormats')),
        reason: 'the tool update must land before the first fetch',
      );
      expect(fetchCalls, 1);
      expect(updateCalls, 1,
          reason: 'exactly one first-run tool update');
    });
  });

  group('v1.0.6 mid-fetch tool refresh', () {
    late int fetchCalls;
    late int updateCalls;

    setUp(() {
      fetchCalls = 0;
      updateCalls = 0;
      // Already-initialized install (update check done this week) so
      // init() does not await anything — the only update in this test
      // is the one that lands DURING the fetch.
      SharedPreferences.setMockInitialValues({'toolLastCheckMs': 1});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'init':
            return 'test';
          case 'updateTool':
            updateCalls++;
            if (updateCalls == 1) {
              return {'status': 'done', 'version': '2026.10.26'};
            }
            return {'status': 'up_to_date'};
          case 'fetchFormats':
            fetchCalls++;
            if (fetchCalls == 1) {
              // The tool update lands mid-fetch (e.g. the background
              // weekly check finishing), then the fetch fails with a
              // FORMATS error — the retry must still happen, because
              // the fresh tool was not in place when the fetch ran.
              await EngineService.instance.updateTool();
              throw PlatformException(
                code: 'FORMATS',
                message: 'Unable to extract webpage video data',
              );
            }
            return jsonEncode(fakeInfoJson());
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test(
        'FORMATS retry is NOT skipped when the tool was refreshed '
        'mid-fetch', () async {
      final info = await EngineService.instance.fetchInfo(
        'https://vt.tiktok.com/ZSpa2eeKL/',
      );
      expect(info.title, contains('بارتيشن'));
      expect(fetchCalls, 2, reason: 'the fetch must be retried once');
      expect(updateCalls, 2,
          reason: 'mid-fetch update + the retry-path update check');
    });
  });

  group('v1.0.6 sizeBytes', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({'toolLastCheckMs': 1});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
        switch (call.method) {
          case 'init':
            return 'test';
          case 'fetchFormats':
            return jsonEncode(fakeInfoJson());
          default:
            return null;
        }
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('Highest = video + audio bytes; audio-only = audio bytes',
        () async {
      final info = await EngineService.instance.fetchInfo(
        'https://vt.tiktok.com/ZSpa2eeKL/',
      );
      final highest =
          info.formats.firstWhere((f) => f.label == 'Highest');
      expect(highest.sizeBytes, 12345 + 5432);
      final audio = info.formats.firstWhere((f) => f.isAudioOnly);
      expect(audio.sizeBytes, 5432);
    });
  });

  group('v1.0.6 pickFinishedFile', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('snapdl-pick-');
    });

    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    Future<File> makeFile(String name, int bytes,
        {Duration? age}) async {
      final f = File('${dir.path}/$name');
      await f.writeAsBytes(List.filled(bytes, 0x41));
      if (age != null) {
        await f.setLastModified(DateTime.now().subtract(age));
      }
      return f;
    }

    test('prefers the title-matching file, ignores .part/empty/old',
        () async {
      const title = 'عمرك سألت نفسك ليه بارتيشن الـ C دايماً أحمر؟';
      final since = DateTime.now().subtract(const Duration(minutes: 1));
      final titled = await makeFile(
          'عمرك سألت نفسك ليه بارتيشن الـ C دايماً أحمر.mp4', 1000);
      await makeFile('other video.mp4', 2000); // newer, no title match
      await makeFile('عمرك سألت نفسك ليه بارتيشن الـ C.mp4.part', 50);
      await makeFile('empty.mp4', 0);
      await makeFile('old video.mp4', 100,
          age: const Duration(hours: 1));
      final files = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      final picked = DownloadController.pickFinishedFile(files, title, since);
      expect(picked?.path, titled.path);
    });

    test('falls back to the newest file when nothing matches the title',
        () async {
      final since = DateTime.now().subtract(const Duration(minutes: 1));
      final first = await makeFile('aaa.mp4', 100);
      await Future.delayed(const Duration(milliseconds: 20));
      final newest = await makeFile('zzz.mp4', 200);
      final files = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      expect(first.path, isNot(newest.path));
      final picked =
          DownloadController.pickFinishedFile(files, 'no match here', since);
      expect(picked?.path, newest.path);
    });

    test('returns null when nothing usable exists', () async {
      await makeFile('only.part', 100);
      final files = await dir
          .list()
          .where((e) => e is File)
          .cast<File>()
          .toList();
      final since = DateTime.now().subtract(const Duration(minutes: 1));
      expect(
          DownloadController.pickFinishedFile(files, 'anything', since),
          isNull);
    });
  });
}
