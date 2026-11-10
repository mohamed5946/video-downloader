import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../services/adblock_service.dart';
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

class UpdatesScreen extends StatefulWidget {
  const UpdatesScreen({super.key});

  @override
  State<UpdatesScreen> createState() => _UpdatesScreenState();
}

class _UpdatesScreenState extends State<UpdatesScreen> {
  String _version = '1.0.0';
  bool _checking = false;

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

  Future<void> _check() async {
    setState(() => _checking = true);
    final check = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
    setState(() => _checking = false);
    if (check.available) {
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(SettingsService.instance.trf('updates_dialog_title', {'v': check.version ?? ''})),
          content: Text(check.notes?.isNotEmpty == true
              ? check.notes!
              : SettingsService.instance.tr('updates_dialog_body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(SettingsService.instance.tr('common_later'),
                  style: TextStyle(color: AppColors.textSecondaryOf(context))),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(SettingsService.instance.tr('common_download'),
                  style: TextStyle(color: AppColors.glowCyan)),
            ),
          ],
        ),
      );
      if (go == true && check.apkUrl != null && check.apkUrl!.isNotEmpty) {
        final uri = Uri.parse(check.apkUrl!);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(check.error ??
              SettingsService.instance.tr('updates_latest')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        return _settingsBody(children: [
          GlassPanel(
            child: Row(
              children: [
                const Icon(Icons.system_update_rounded,
                    color: AppColors.glowCyan, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.tr('updates_current'),
                        style: TextStyle(
                            color: AppColors.textFaintOf(context), fontSize: 12),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'SnapDL $_version',
                        style: TextStyle(
                          color: AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: _checking
                  ? SettingsService.instance.tr('updates_checking')
                  : settings.tr('updates_check'),
              icon: Icons.refresh_rounded,
              onPressed: _checking ? null : _check,
            ),
          ),
          const SizedBox(height: 12),
          _SwitchRow(
            title: settings.tr('updates_auto'),
            subtitle: settings.tr('settings_updates_sub'),
            value: settings.autoCheckUpdates,
            onChanged: (v) => settings.setAutoCheckUpdates(v),
          ),
        ]);
      },
    );
  }
}
