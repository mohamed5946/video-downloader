// SnapDL smoke tests: the app shell builds, tabs switch, settings rows
// open their sub-screens, and every row navigates.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:snapdl/main.dart';

/// Pop the current route. `tester.pageBack()` looks for the English
/// 'Back' tooltip, which does not exist when the UI is in Arabic.
Future<void> _goBack(WidgetTester tester) async {
  final context = tester.element(find.byType(Scaffold).first);
  Navigator.of(context).pop();
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // The native engine does not exist in tests: answer its channel so
    // EngineService.init() completes instead of hanging forever.
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

  testWidgets('SnapDL shell builds with Home tab (Arabic default, RTL)',
      (tester) async {
    await tester.pumpWidget(const SnapDLApp());
    await tester.pump();
    expect(find.text('SnapDL'), findsWidgets);
    expect(find.text('الصق رابطًا،'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField).first,
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    await tester.pump();
    expect(find.text('عرض خيارات التحميل'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('مشاهدة'), findsOneWidget);
    expect(find.text('السجل'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
  });

  testWidgets('Bottom nav switches to Watch, History and Settings',
      (tester) async {
    await tester.pumpWidget(const SnapDLApp());
    await tester.pump();
    await tester.tap(find.text('السجل'));
    await tester.pump();
    expect(find.text('لا توجد تحميلات بعد'), findsOneWidget);
    await tester.tap(find.text('الإعدادات').first);
    await tester.pump();
    expect(find.text('المظهر'), findsOneWidget);
    expect(find.text('مانع الإعلانات'), findsOneWidget);
    expect(find.text('سجل التشخيص'), findsOneWidget);
  });

  testWidgets('Settings rows open their sub-screens', (tester) async {
    await tester.pumpWidget(const SnapDLApp());
    await tester.pump();
    await tester.tap(find.text('الإعدادات').first);
    await tester.pumpAndSettle();

    // Appearance: three working theme options (Light / Night / System)
    // and tapping one applies it immediately.
    await tester.tap(find.text('المظهر'));
    await tester.pumpAndSettle();
    expect(find.text('فاتح'), findsOneWidget);
    expect(find.text('ليلي'), findsOneWidget);
    expect(find.text('تلقائي'), findsOneWidget);
    await tester.tap(find.text('ليلي'));
    await tester.pumpAndSettle();
    await _goBack(tester);
    await tester.pumpAndSettle();

    // Speed test: the row opens its screen, which never auto-runs —
    // it waits for the start button.
    await tester.ensureVisible(find.text('سرعة الإنترنت'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سرعة الإنترنت'));
    await tester.pumpAndSettle();
    expect(find.text('ابدأ القياس'), findsOneWidget);
    expect(find.text('التحميل'), findsWidgets);
    await _goBack(tester);
    await tester.pumpAndSettle();

    // About: developer + portfolio button (last row — scroll into view).
    await tester.ensureVisible(find.text('عن التطبيق'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('عن التطبيق'));
    await tester.pumpAndSettle();
    expect(find.text('Mohamed El Sayed'), findsOneWidget);
    expect(find.text('زيارة صفحة المطوّر'), findsOneWidget);
    await _goBack(tester);
    await tester.pumpAndSettle();

    // Diagnostics log viewer is labelled exactly "سجل التشخيص" and shows
    // real entries (the mocked service logs "Download service ready" at startup).
    await tester.ensureVisible(find.text('سجل التشخيص').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('سجل التشخيص').first);
    await tester.pumpAndSettle();
    expect(find.text('سجل التشخيص'), findsWidgets);
    expect(find.textContaining('Download service ready'), findsOneWidget);
  });

  testWidgets('Language switch to English applies immediately',
      (tester) async {
    await tester.pumpWidget(const SnapDLApp());
    await tester.pump();
    await tester.tap(find.text('الإعدادات').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('اللغة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    // The bottom nav sits under the pushed Language route, so pop back
    // before checking its (now English) labels.
    await _goBack(tester);
    await tester.tap(find.text('Home'));
    await tester.pump();
    expect(find.text('Paste a link,'), findsOneWidget);
  });
}
