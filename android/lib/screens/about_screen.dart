import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models.dart';
import '../services/engine_service.dart';
import '../services/settings_service.dart';
import '../services/log_service.dart';
import '../services/update_service.dart';
import '../theme.dart';
import '../widgets/staggered_entrance.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '1.0.0';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    // Start the engine (its health is logged to سجل التشخيص only —
    // no engine status is shown on any main screen).
    await EngineService.instance.version();
    if (mounted) {
      setState(() {
        _version = '${info.version} (${info.buildNumber})';
      });
    }
  }

  Future<void> _openPortfolio() async {
    final uri = Uri.parse(UpdateService.portfolioUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      LogService.instance.error(
          LogCategory.ui, 'Could not open portfolio link');
    }
  }

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    final check = await UpdateService.instance.checkForUpdate();
    if (!mounted) return;
    setState(() => _checkingUpdate = false);
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
                  style: TextStyle(color: AppColors.textSecondary)),
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
          content: Text(check.error ?? SettingsService.instance.tr('updates_latest')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: StaggeredScope(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StaggeredItem(
            index: 0,
            child: GlassPanel(
              child: Column(
                children: [
                  ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.asset(
                    'assets/images/snapdl-logo.png',
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SnapDL',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  SettingsService.instance.trf('about_version', {'v': _version}),
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  SettingsService.instance.tr('about_tagline'),
                  style: TextStyle(
                      color: AppColors.textFaint, fontSize: 13),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: GlassButton(
                    label: SettingsService.instance.tr('about_portfolio'),
                    icon: Icons.language_rounded,
                    onPressed: _openPortfolio,
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 14),
          StaggeredItem(
            index: 1,
            child: GlassPanel(
              child: Column(
                children: [
                  _InfoRow(
                    label: SettingsService.instance.tr('about_developer'), value: 'Mohamed El Sayed'),
                Divider(color: AppColors.glassBorder, height: 20),
                _InfoRow(
                    label: SettingsService.instance.tr('about_platforms'),
                    value: 'YouTube · TikTok · Instagram · Facebook · X'),
                Divider(color: AppColors.glassBorder, height: 20),
                _InfoRow(
                    label: SettingsService.instance.tr('about_storage'),
                    value: 'Downloads / SnapDL'),
              ],
            ),
          )),
          const SizedBox(height: 14),
          StaggeredItem(
            index: 2,
            child: SizedBox(
              width: double.infinity,
              child: GlassButton(
              label: _checkingUpdate
                  ? SettingsService.instance.tr('updates_checking')
                  : SettingsService.instance.tr('updates_check'),
              icon: Icons.system_update_rounded,
              onPressed: _checkingUpdate ? null : _checkUpdate,
            ),
          )),
          const SizedBox(height: 14),
          StaggeredItem(
            index: 3,
            child: Text(
              SettingsService.instance.tr('about_disclaimer'),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          )),
        ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: TextStyle(
                  color: AppColors.textFaint, fontSize: 13)),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
                color: AppColors.textPrimary, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
