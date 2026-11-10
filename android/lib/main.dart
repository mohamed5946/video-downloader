import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/watch_screen.dart';
import 'services/download_controller.dart';
import 'services/history_service.dart';
import 'services/log_service.dart';
import 'services/settings_service.dart';
import 'services/update_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LogService.instance.ensureLoaded();
  await HistoryService.instance.ensureLoaded();
  await SettingsService.instance.ensureLoaded();
  runApp(const SnapDLApp());
}

class SnapDLApp extends StatefulWidget {
  const SnapDLApp({super.key});

  /// Test hook: widget tests set this to 'home' | 'history' | 'about' |
  /// 'settings' | 'watch' to seed demo state (the web build uses
  /// ?preview= instead).
  static String? testPreview;

  @override
  State<SnapDLApp> createState() => _SnapDLAppState();
}

class _SnapDLAppState extends State<SnapDLApp> {
  late final DownloadController _controller;
  int _tab = 0;
  bool _autoCheckDone = false;

  @override
  void initState() {
    super.initState();
    _controller = DownloadController();
    _maybeSeedPreview();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _maybeAutoCheck(context));
  }

  /// Web-only: ?preview=home|history|about|settings|watch seeds realistic
  /// demo state so screenshots show the real UI with real data.
  Future<void> _maybeSeedPreview() async {
    if (!kIsWeb && SnapDLApp.testPreview == null) return;
    final which =
        kIsWeb ? Uri.base.queryParameters['preview'] : SnapDLApp.testPreview;
    if (which == null) return;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (which == 'home' || which == 'history') {
      await _controller.seedDemo(which);
    }
    if (mounted) {
      setState(() {
        _tab = switch (which) {
          'history' => 2,
          'settings' || 'about' => 3,
          'watch' => 1,
          _ => 0,
        };
      });
    }
  }

  /// Auto-check for updates once at startup (if enabled in Settings).
  Future<void> _maybeAutoCheck(BuildContext context) async {
    if (_autoCheckDone) return;
    _autoCheckDone = true;
    if (kIsWeb || SnapDLApp.testPreview != null) return;
    if (!SettingsService.instance.autoCheckUpdates) return;
    final check = await UpdateService.instance.checkForUpdate();
    if (!context.mounted || !check.available) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(SettingsService.instance
            .trf('update_available_snackbar', {'v': check.version ?? ''})),
      ),
    );
  }

  /// A video URL from the in-app YouTube page → Home tab + fetch formats.
  void _onWatchDownloadUrl(String url) {
    _controller.setUrl(url);
    setState(() => _tab = 0);
    _controller.fetchFormats();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return MaterialApp(
          title: 'SnapDL',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          // Full language switch: Arabic = RTL, English = LTR.
          locale: Locale(settings.language),
          supportedLocales: const [Locale('en'), Locale('ar')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              return AppBackground(
                child: Scaffold(
                  backgroundColor: Colors.transparent,
                  // The body flows UNDER the floating bottom pill, so the
                  // screen content stays visible through the pill's
                  // transparent rounded corners (standing UI rule).
                  extendBody: true,
                  appBar: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    title: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/images/snapdl-logo.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'SnapDL',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  body: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: _buildTab(),
                  ),
                  bottomNavigationBar: _BottomNav(
                    tab: _tab,
                    onTab: (i) => setState(() => _tab = i),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTab() {
    switch (_tab) {
      case 1:
        return WatchScreen(
            key: const ValueKey('watch'),
            onDownloadUrl: _onWatchDownloadUrl);
      case 2:
        return HistoryScreen(
            key: const ValueKey('history'), controller: _controller);
      case 3:
        return const SettingsScreen(key: ValueKey('settings'));
      case 0:
      default:
        return HomeScreen(
            key: const ValueKey('home'), controller: _controller);
    }
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.tab, required this.onTab});

  final int tab;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final items = [
      (Icons.home_rounded, settings.tr('nav_home')),
      (Icons.play_circle_outline_rounded, settings.tr('nav_watch')),
      (Icons.history_rounded, settings.tr('nav_history')),
      (Icons.settings_rounded, settings.tr('nav_settings')),
    ];
    // Floating pill: the outer container has NO color at all (not even a
    // transparent one — a transparent color would still swallow taps over
    // its whole rect), so the screen content stays visible in the corners
    // beside the rounded ends AND taps pass through to the content below.
    // Only the pill itself (translucent white + blur + shadow) covers
    // content — the floating 3D effect (standing UI rule).
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.72),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F2A43).withOpacity(0.14),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: List.generate(items.length, (i) {
                final selected = tab == i;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTab(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            items[i].$1,
                            size: 22,
                            color: selected
                                ? AppColors.glowCyan
                                : AppColors.textFaint,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            items[i].$2,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selected
                                  ? AppColors.textPrimary
                                  : AppColors.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}
