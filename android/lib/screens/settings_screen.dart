import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../models.dart';
import '../services/adblock_service.dart';
import '../services/engine_service.dart';
import '../services/log_service.dart';
import '../services/settings_service.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/staggered_entrance.dart';
import 'about_screen.dart';
import 'logs_screen.dart';
import 'speed_test_screen.dart';

/// Settings — a clean list of buttons (DeliveryFlow style). Every row
/// opens its own dedicated sub-screen; nothing is jumbled together.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final adblock = AdBlockService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([settings, adblock]),
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: StaggeredScope(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                settings.tr('settings_title'),
                style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              StaggeredItem(
                index: 0,
                child: _SettingsRow(
                icon: Icons.dark_mode_rounded,
                title: settings.tr('settings_appearance'),
                subtitle: settings.tr('settings_appearance_sub'),
                onTap: () => _push(context, settings.tr('appearance_title'),
                    const AppearanceScreen()),

                ),
              ),
              StaggeredItem(
                index: 1,
                child: _SettingsRow(
                icon: Icons.language_rounded,
                title: settings.tr('settings_language'),
                subtitle:
                    '${settings.tr('settings_language_sub')} · ${settings.language == 'ar' ? 'العربية' : 'English'}',
                onTap: () => _push(context, settings.tr('language_title'),
                    const LanguageScreen()),

                ),
              ),
              StaggeredItem(
                index: 2,
                child: _SettingsRow(
                icon: Icons.download_rounded,
                title: settings.tr('settings_downloads'),
                subtitle: settings.tr('settings_downloads_sub'),
                onTap: () => _push(context, settings.tr('downloads_title'),
                    const DownloadsScreen()),

                ),
              ),
              StaggeredItem(
                index: 3,
                child: _SettingsRow(
                icon: Icons.shield_rounded,
                title: settings.tr('settings_adblock'),
                subtitle:
                    '${settings.tr('settings_adblock_sub')} · ${adblock.running ? settings.tr('adblock_on') : settings.tr('adblock_off')}',
                onTap: () => _push(context, settings.tr('adblock_title'),
                    const AdBlockerScreen()),

                ),
              ),
              StaggeredItem(
                index: 4,
                child: _SettingsRow(
                icon: Icons.system_update_rounded,
                title: settings.tr('settings_updates'),
                subtitle: settings.tr('settings_updates_sub'),
                onTap: () => _push(context, settings.tr('updates_title'),
                    const UpdatesScreen()),

                ),
              ),
              StaggeredItem(
                index: 5,
                child: _SettingsRow(
                icon: Icons.speed_rounded,
                title: settings.tr('settings_speedtest'),
                subtitle: settings.tr('settings_speedtest_sub'),
                onTap: () => _push(context, settings.tr('speedtest_title'),
                    const SpeedTestScreen()),

                ),
              ),
              StaggeredItem(
                index: 6,
                child: _SettingsRow(
                icon: Icons.terminal_rounded,
                title: 'سجل التشخيص',
                subtitle: settings.tr('settings_logs_sub'),
                onTap: () => _push(
                    context, 'سجل التشخيص', const LogsScreen(),
                    wrap: true),

                ),
              ),
              StaggeredItem(
                index: 7,
                child: _SettingsRow(
                icon: Icons.info_outline_rounded,
                title: settings.tr('settings_about'),
                subtitle: settings.tr('settings_about_sub'),
                onTap: () => _push(
                    context, settings.tr('about_title'), const AboutScreen(),
                    wrap: true),

                ),
              ),
            ],
            ),
          ),
        );
      },
    );
  }

  void _push(BuildContext context, String title, Widget child,
      {bool wrap = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SubScreen(title: title, child: child),
      ),
    );
  }
}

class _SubScreen extends StatelessWidget {
  const _SubScreen({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: AppColors.textPrimaryOf(context)),
          title: Text(
            title,
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
        ),
        body: child,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                            color: AppColors.textFaintOf(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    color: AppColors.textFaintOf(context), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                              color: AppColors.textFaintOf(context), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: selected ? AppColors.accentGradient : null,
                    color: selected ? null : Colors.white.withOpacity(0.08),
                    border: Border.all(
                        color: selected
                            ? Colors.white.withOpacity(0.4)
                            : AppColors.glassBorderOf(context)),
                  ),
                  child: selected
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 15)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                        color: AppColors.textFaintOf(context), fontSize: 12),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: value,
              activeColor: AppColors.glowCyan,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      opacity: 0.05,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.textFaintOf(context), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  color: AppColors.textSecondaryOf(context), fontSize: 13, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _settingsBody({required List<Widget> children}) {
  return SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

// --------------------------------------------------------------- appearance

// v1.0.4: real theme choice — Light / Night / System, persisted in
// SettingsService and applied immediately via MaterialApp.themeMode.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return _settingsBody(children: [
          _OptionRow(
            title: settings.tr('appearance_light'),
            subtitle: settings.tr('appearance_light_sub'),
            selected: settings.themeMode == 'light',
            onTap: () => settings.setThemeMode('light'),
          ),
          _OptionRow(
            title: settings.tr('appearance_dark'),
            subtitle: settings.tr('appearance_dark_sub'),
            selected: settings.themeMode == 'dark',
            onTap: () => settings.setThemeMode('dark'),
          ),
          _OptionRow(
            title: settings.tr('appearance_system'),
            subtitle: settings.tr('appearance_system_sub'),
            selected: settings.themeMode == 'system',
            onTap: () => settings.setThemeMode('system'),
          ),
          const SizedBox(height: 12),
          _NoteCard(text: settings.tr('appearance_note')),
        ]);
      },
    );
  }
}

// ----------------------------------------------------------------- language

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return _settingsBody(children: [
          _OptionRow(
            title: 'العربية',
            subtitle: 'Arabic',
            selected: settings.language == 'ar',
            onTap: () => settings.setLanguage('ar'),
          ),
          _OptionRow(
            title: 'English',
            subtitle: 'الإنجليزية',
            selected: settings.language == 'en',
            onTap: () => settings.setLanguage('en'),
          ),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------- downloads

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  static const _qualities = [
    'Highest',
    '4K',
    '1080p',
    '720p',
    'Lowest',
    'Audio MP3',
  ];

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return _settingsBody(children: [
          Text(
            settings.tr('downloads_folder'),
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          _OptionRow(
            title: settings.tr('downloads_folder_public'),
            selected: settings.downloadLocation == 'public',
            onTap: () => settings.setDownloadLocation('public'),
          ),
          _OptionRow(
            title: settings.tr('downloads_folder_app'),
            selected: settings.downloadLocation == 'app',
            onTap: () => settings.setDownloadLocation('app'),
          ),
          const SizedBox(height: 12),
          Text(
            settings.tr('downloads_quality'),
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          ..._qualities.map((q) => _OptionRow(
                title: settings.qualityLabel(q),
                selected: settings.defaultQuality == q,
                onTap: () => settings.setDefaultQuality(q),
              )),
          const SizedBox(height: 12),
          _SwitchRow(
            title: settings.tr('downloads_wifi'),
            subtitle: settings.tr('downloads_wifi_sub'),
            value: settings.wifiOnly,
            onChanged: (v) => settings.setWifiOnly(v),
          ),
          Text(
            settings.tr('downloads_max'),
            style: TextStyle(
              color: AppColors.textPrimaryOf(context),
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [1, 2, 3].map((n) {
              final selected = settings.maxSimultaneous == n;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: n < 3 ? 8 : 0),
                  child: GlassButton(
                    label: '$n',
                    gradient: selected
                        ? AppColors.accentGradient
                        : const LinearGradient(
                            colors: [Color(0xFF334155), Color(0xFF475569)]),
                    onPressed: () => settings.setMaxSimultaneous(n),
                  ),
                ),
              );
            }).toList(),
          ),
        ]);
      },
    );
  }
}

// --------------------------------------------------------------- ad blocker

class AdBlockerScreen extends StatefulWidget {
  const AdBlockerScreen({super.key});

  @override
  State<AdBlockerScreen> createState() => _AdBlockerScreenState();
}

class _AdBlockerScreenState extends State<AdBlockerScreen>
    with WidgetsBindingObserver {
  final _adblock = AdBlockService.instance;
  bool _updatingList = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _adblock.refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _adblock.refresh();
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      final started = await _adblock.start();
      if (!mounted) return;
      if (!started && !_adblock.running) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                SettingsService.instance.tr('adblock_approve')),
          ),
        );
      }
    } else {
      await _adblock.stop();
    }
  }

  Future<void> _updateList() async {
    setState(() => _updatingList = true);
    final ok = await _adblock.updateBlocklist();
    if (!mounted) return;
    setState(() => _updatingList = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? SettingsService.instance.tr('adblock_list_updated')
            : SettingsService.instance.tr('adblock_list_failed')),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: _adblock,
      builder: (context, _) {
        return _settingsBody(children: [
          GlassPanel(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: _adblock.running
                        ? AppColors.accentGradient
                        : null,
                    color: _adblock.running
                        ? null
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    _adblock.running
                        ? Icons.shield_rounded
                        : Icons.shield_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adblock.running
                            ? settings.tr('adblock_on')
                            : settings.tr('adblock_off'),
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${settings.tr('adblock_status')}: ${_adblock.running ? settings.tr('adblock_running') : settings.tr('adblock_stopped')}',
                        style: TextStyle(
                            color: AppColors.textFaintOf(context), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: _adblock.running,
                  activeColor: AppColors.glowCyan,
                  onChanged: _toggle,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassPanel(
            child: Row(
              children: [
                Icon(Icons.block_rounded,
                    color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${settings.tr('adblock_blocked')}: ${_adblock.blockedCount}',
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _NoteCard(text: settings.tr('adblock_body')),
          const SizedBox(height: 12),
          _NoteCard(text: settings.tr('adblock_limit')),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: _updatingList
                  ? settings.tr('adblock_updating')
                  : settings.tr('adblock_update_list'),
              icon: Icons.refresh_rounded,
              onPressed: _updatingList ? null : _updateList,
            ),
          ),
          const SizedBox(height: 12),
          _NoteCard(text: settings.tr('adblock_private_dns_body')),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: settings.tr('adblock_private_dns'),
              icon: Icons.settings_rounded,
              gradient: const LinearGradient(
                colors: [Color(0xFF334155), Color(0xFF475569)]),
              onPressed: () async {
                // Opens top-level Android Settings; the user then goes to
                // Network & internet → Private DNS → hostname
                // dns.adguard-dns.com (see the note above).
                try {
                  await AdBlockService.openSystemSettings();
                } catch (e) {
                  LogService.instance.error(LogCategory.ui,
                      'Could not open system settings', '$e');
                }
              },
            ),
          ),
          if (!_adblock.supported) ...[
            const SizedBox(height: 12),
            _NoteCard(
                text:
                    settings.tr('adblock_unavailable')),
          ],
        ]);
      },
    );
  }
}

// ------------------------------------------------------------------ updates

/// Updates — Apple-layout, SnapDL liquid glass (v1.0.7).
///
/// Top: automatic-updates switch. Below it, a floating 3D glass card
/// (a second layer above the app, strong soft shadow — not flat):
/// the app icon, 'SnapDL {version}' + file size, the new version's
/// features, a big full-width 'Update Now' button and an
/// 'Update Tonight' link under it. 'Update Now' downloads the APK
/// inside the app — percent ABOVE the bar, live speed, ETA — then
/// offers 'Install Now' / 'Install Later'. The download-tool section
/// below the card is unchanged (v1.0.5 behavior).
class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  String _version = '1.0.0';
  bool _checking = false;
  // v1.0.5: download-tool update state (generic wording only).
  bool _toolUpdating = false;
  String? _toolStatusKey;
  // v1.0.7: in-app update state.
  UpdateCheck? _check;
  bool _downloading = false;
  UpdateDownloadProgress? _dlProgress;
  String? _downloadedPath;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }
  }

  Future<void> _runCheck() async {
    setState(() {
      _checking = true;
      _downloadedPath = null;
      _dlProgress = null;
    });
    final check = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _check = check;
    });
    if (!check.available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(check.error ??
              SettingsService.instance.tr('updates_latest')),
        ),
      );
    }
  }

  String _formatSize(int bytes) {
    if (bytes <= 0) return '—';
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  Future<void> _startDownload() async {
    final check = _check;
    final url = check?.apkUrl;
    if (check == null || url == null || url.isEmpty) return;
    setState(() {
      _downloading = true;
      _dlProgress = null;
      _downloadedPath = null;
    });
    try {
      final file = await UpdateService.instance.downloadUpdate(
        url: url,
        totalBytes: check.sizeBytes,
        onProgress: (p) {
          if (mounted) setState(() => _dlProgress = p);
        },
      );
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _downloadedPath = file.path;
      });
    } catch (_) {
      // The service already throws the localized generic message.
      if (!mounted) return;
      setState(() => _downloading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(SettingsService.instance.tr('updates_download_failed')),
        ),
      );
    }
  }

  Future<void> _installNow(String path) async {
    final ok = await UpdateService.instance.installUpdate(path);
    if (!mounted) return;
    if (ok) {
      await SettingsService.instance.setPendingUpdatePath('');
      await SettingsService.instance.setUpdateTonight(false);
      setState(() => _downloadedPath = null);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(SettingsService.instance.tr('download_failed')),
        ),
      );
    }
  }

  Future<void> _installLater(String path) async {
    await SettingsService.instance.setPendingUpdatePath(path);
    if (!mounted) return;
    setState(() => _downloadedPath = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(SettingsService.instance.tr('updates_install_later_saved')),
      ),
    );
  }

  Future<void> _updateTonight() async {
    await SettingsService.instance.setUpdateTonight(true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(SettingsService.instance.tr('updates_tonight_scheduled')),
      ),
    );
  }

  // v1.0.5: update the download tool on demand. Runs in the
  // background on first use and weekly on its own; this button is for
  // when a link fails to read and the user wants the newest tool now.
  Future<void> _updateTool() async {
    setState(() {
      _toolUpdating = true;
      _toolStatusKey = null;
    });
    final result = await EngineService.instance.updateTool();
    if (!mounted) return;
    setState(() {
      _toolUpdating = false;
      _toolStatusKey = switch (result) {
        ToolUpdateResult.done => 'tool_updated',
        ToolUpdateResult.upToDate => 'tool_up_to_date',
        ToolUpdateResult.failed => 'tool_update_failed',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final check = _check;
    final pendingPath = settings.pendingUpdatePath;
    final hasPending = pendingPath.isNotEmpty &&
        (() {
          try {
            return File(pendingPath).existsSync();
          } catch (_) {
            return false;
          }
        })();
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return _settingsBody(children: [
          // Automatic updates — top of the screen.
          _SwitchRow(
            title: settings.tr('updates_auto'),
            subtitle: settings.tr('settings_updates_sub'),
            value: settings.autoCheckUpdates,
            onChanged: (v) => settings.setAutoCheckUpdates(v),
          ),
          const SizedBox(height: 14),
          // The floating 3D update card.
          _FloatingGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/snapdl-logo.png',
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, _, __) => Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius:
                                BorderRadius.all(Radius.circular(16)),
                          ),
                          child: const Icon(Icons.system_update_rounded,
                              color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            check?.available == true
                                ? 'SnapDL ${check!.version ?? ''}'
                                : 'SnapDL $_version',
                            style: TextStyle(
                              color: AppColors.textPrimaryOf(context),
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            check?.available == true
                                ? settings.trf('updates_size',
                                    {'s': _formatSize(check!.sizeBytes)})
                                : settings.tr('updates_current'),
                            style: TextStyle(
                                color: AppColors.textFaintOf(context),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (check?.available == true) ...[
                  if ((check!.notes ?? '').isNotEmpty) ...[
                    Text(
                      settings.tr('updates_features'),
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      check.notes!,
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 13,
                          height: 1.5),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_downloadedPath != null) ...[
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        label: settings.tr('updates_install_now'),
                        icon: Icons.download_rounded,
                        onPressed: () => _installNow(_downloadedPath!),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        label: settings.tr('common_later'),
                        icon: Icons.schedule_rounded,
                        gradient: const LinearGradient(
                            colors: [Color(0xFF334155), Color(0xFF475569)]),
                        onPressed: () => _installLater(_downloadedPath!),
                      ),
                    ),
                  ] else if (_downloading) ...[
                    // Percent ABOVE the bar, then bar, speed + ETA.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          settings.tr('updates_downloading'),
                          style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '${((_dlProgress?.percent ?? 0) * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GlassProgressBar(
                        progress: _dlProgress?.percent ?? 0),
                    const SizedBox(height: 8),
                    Text(
                      '${_dlProgress?.speedText ?? '—'} · ${_dlProgress?.etaText ?? '00:00'}',
                      style: TextStyle(
                          color: AppColors.textSecondaryOf(context),
                          fontSize: 13),
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        label: settings.tr('updates_update_now'),
                        icon: Icons.system_update_rounded,
                        onPressed: _startDownload,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: _updateTonight,
                        child: Text(
                          settings.tr('updates_update_tonight'),
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ] else ...[
                  Text(
                    _checking
                        ? settings.tr('updates_checking')
                        : settings.tr('updates_latest'),
                    style: TextStyle(
                        color: AppColors.textSecondaryOf(context),
                        fontSize: 13,
                        height: 1.5),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: GlassButton(
                      label: _checking
                          ? settings.tr('updates_checking')
                          : settings.tr('updates_check'),
                      icon: Icons.refresh_rounded,
                      onPressed: _checking ? null : _runCheck,
                    ),
                  ),
                  if (hasPending) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: GlassButton(
                        label: settings.tr('updates_install_now'),
                        icon: Icons.download_rounded,
                        onPressed: () => _installNow(pendingPath),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          // v1.0.5: download-tool update — same screen, its own section.
          const SizedBox(height: 14),
          GlassPanel(
            child: Row(
              children: [
                const Icon(Icons.build_circle_outlined,
                    color: AppColors.glowCyan, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.tr('tool_update_title'),
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _toolUpdating
                            ? settings.tr('tool_updating')
                            : _toolStatusKey != null
                                ? settings.tr(_toolStatusKey!)
                                : settings.tr('tool_update_body'),
                        style: TextStyle(
                            color: AppColors.textFaintOf(context),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: _toolUpdating
                  ? settings.tr('tool_updating')
                  : settings.tr('tool_update_now'),
              icon: Icons.refresh_rounded,
              onPressed: _toolUpdating ? null : _updateTool,
            ),
          ),
        ]);
      },
    );
  }
}

/// Floating 3D glass: a GlassPanel lifted off the background by a
/// strong soft shadow (blur 32, offset (0, 16), #1E2A32 at 0.18) —
/// a second layer floating above the app, not flat against it.
/// (Theme.dart is untouched — this treatment lives here.)
class _FloatingGlassCard extends StatelessWidget {
  const _FloatingGlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2A32).withOpacity(0.18),
            blurRadius: 32,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: GlassPanel(child: child),
    );
  }
}
