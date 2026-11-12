// Preview screenshots for Mohamed's approval — renders the REAL SnapDL UI
// with seeded demo state and writes golden PNGs.
// Run: flutter test --update-goldens test/preview_test.dart
// Output: test/goldens/snapdl-preview-{home,history,about,settings,watch}.png
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snapdl/main.dart';
import 'package:snapdl/screens/speed_test_screen.dart';
import 'package:snapdl/services/speed_test_service.dart';

/// Locate the MaterialIcons font in the Flutter SDK. The SDK lives at a
/// different path on every machine (and on CI), so resolve it from the
/// `flutter` executable on PATH (or FLUTTER_ROOT) instead of a hardcoded
/// author-machine path — the hardcoded path made setUpAll throw
/// PathNotFoundException on the GitHub runner and fail the whole file.
String _materialIconsPath() {
  const file =
      'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf';
  String? candidate(String sdkRoot) {
    final path = '$sdkRoot/$file';
    return File(path).existsSync() ? path : null;
  }

  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null && root.isNotEmpty) {
    final found = candidate(root);
    if (found != null) return found;
  }
  try {
    final result = Process.runSync('which', const ['flutter']);
    if (result.exitCode == 0) {
      final flutterBin =
          File((result.stdout as String).trim()).resolveSymbolicLinksSync();
      // <sdk>/bin/flutter -> <sdk>
      final sdkRoot = File(flutterBin).parent.parent.path;
      final found = candidate(sdkRoot);
      if (found != null) return found;
    }
  } catch (_) {
    // Fall through to the legacy path below.
  }
  // Last resort: the machine the test was first authored on.
  return '/home/hatch/sdk/flutter/$file';
}

Future<void> _loadRealFonts() async {
  Future<ByteData> bytes(String path) async {
    final data = await File(path).readAsBytes();
    return ByteData.view(data.buffer);
  }

  // Cairo (bundled in the app): Regular 400, Bold 700, Black 900.
  final cairo = FontLoader('Cairo')
    ..addFont(bytes('assets/fonts/Cairo-Regular.ttf'))
    ..addFont(bytes('assets/fonts/Cairo-Bold.ttf'))
    ..addFont(bytes('assets/fonts/Cairo-Black.ttf'));
  await cairo.load();

  // Material Icons ship with the Flutter SDK (not bundled in test assets).
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(bytes(_materialIconsPath()));
  await materialIcons.load();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadRealFonts();
    // Mock the native engine channel so EngineService.init() completes
    // in tests instead of hanging on an unanswered platform message.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.valor.snapdl/engine'),
      (MethodCall call) async {
        if (call.method == 'init') return 'test';
        return null;
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.valor.snapdl/engine_events'),
      (MethodCall call) async => null,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/package_info'),
      (MethodCall call) async => <String, dynamic>{
        'appName': 'SnapDL',
        'packageName': 'com.valor.snapdl',
        'version': '1.0.0',
        'buildNumber': '1',
      },
    );
  });

  Future<void> pumpPreview(WidgetTester tester, String which) async {
    SnapDLApp.testPreview = which;
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      SnapDLApp.testPreview = null;
    });
    await tester.pumpWidget(const SnapDLApp());
    // Advance fake time past the 300ms seed delay (pumpAndSettle alone
    // will not fire it — a delayed Future schedules no frame), then let
    // the demo seed, entrance animations and the logo asset settle.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    // Make sure the AppBar logo is decoded before the golden is taken —
    // the first test in the file otherwise catches it mid-load.
    await tester.runAsync(() async {
      final context = tester.element(find.byType(SnapDLApp));
      await precacheImage(
          const AssetImage('assets/images/snapdl-logo.png'), context);
    });
    await tester.pumpAndSettle();
  }

  testWidgets('preview: home (link + quality + download in progress)',
      (tester) async {
    await pumpPreview(tester, 'home');
    // The home screen scrolls: bring the active-download card (polished
    // bar + % + speed/ETA + quality) into frame before capturing.
    await tester.scrollUntilVisible(
      find.text('إيقاف مؤقت').first,
      100,
      scrollable: find.ancestor(
        of: find.text('إيقاف مؤقت').first,
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SnapDLApp),
      matchesGoldenFile('goldens/snapdl-preview-home.png'),
    );
  });

  testWidgets('preview: history', (tester) async {
    await pumpPreview(tester, 'history');
    await expectLater(
      find.byType(SnapDLApp),
      matchesGoldenFile('goldens/snapdl-preview-history.png'),
    );
  });

  testWidgets('preview: about', (tester) async {
    await pumpPreview(tester, 'settings');
    // The About row sits below the fold once the list grew — bring it
    // into view first, or the tap lands on the bottom nav instead.
    await tester.ensureVisible(find.text('عن التطبيق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عن التطبيق'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SnapDLApp),
      matchesGoldenFile('goldens/snapdl-preview-about.png'),
    );
  });

  testWidgets('preview: settings list', (tester) async {
    await pumpPreview(tester, 'settings');
    await expectLater(
      find.byType(SnapDLApp),
      matchesGoldenFile('goldens/snapdl-preview-settings.png'),
    );
  });

  testWidgets('preview: watch page', (tester) async {
    await pumpPreview(tester, 'watch');
    await expectLater(
      find.byType(SnapDLApp),
      matchesGoldenFile('goldens/snapdl-preview-watch.png'),
    );
  });

  testWidgets('preview: speed test gauge (v1.0.8, finished 47.6 Mbps)',
      (tester) async {
    await pumpPreview(tester, 'settings');
    // Seed a finished test so the gauge rests on a real reading:
    // needle between the 10 and 50 marks, number below the dial.
    final service = SpeedTestService.instance;
    service.phase = SpeedTestPhase.done;
    service.downloadMbps = 47.6;
    service.uploadMbps = 12.4;
    service.pingMs = 24;
    service.jitterMs = 3;
    addTearDown(() => SpeedTestService.instance.reset());
    await tester.ensureVisible(find.text('سرعة الإنترنت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سرعة الإنترنت'));
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(SpeedTestScreen),
      matchesGoldenFile('goldens/snapdl-preview-speed.png'),
    );
  });
}
