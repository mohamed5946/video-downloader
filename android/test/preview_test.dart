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
    ..addFont(bytes(
        '/home/hatch/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf'));
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
}
