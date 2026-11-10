import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/speed_test_service.dart';
import '../theme.dart';
import '../widgets/staggered_entrance.dart';

/// Internet speed test — on-demand only (v1.0.4).
///
/// The test NEVER starts by itself: the user is often on mobile data,
/// so it only runs when they tap the button. It uses about 12 MB
/// (10 MB download, 2 MB upload) and reports download / upload / ping.
class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  final SpeedTestService _service = SpeedTestService.instance;

  @override
  void dispose() {
    _service.cancel();
    super.dispose();
  }

  String _formatSpeed(double? mbps) {
    if (mbps == null) return '—';
    return '${mbps.toStringAsFixed(1)} Mbps';
  }

  String _formatPing(double? ms) {
    if (ms == null) return '—';
    return '${ms.toStringAsFixed(0)} ms';
  }

  String _phaseLabel(SpeedTestService s, SettingsService settings) {
    switch (s.phase) {
      case SpeedTestPhase.ping:
        return settings.tr('speedtest_ping');
      case SpeedTestPhase.download:
        return settings.tr('speedtest_download');
      case SpeedTestPhase.upload:
        return settings.tr('speedtest_upload');
      case SpeedTestPhase.done:
        return settings.tr('speedtest_retry');
      case SpeedTestPhase.error:
        return settings.tr('speedtest_failed');
      case SpeedTestPhase.idle:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final s = _service;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: StaggeredScope(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StaggeredItem(
                  index: 0,
                  child: GlassPanel(
                    opacity: 0.05,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            color: AppColors.textFaintOf(context), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            settings.tr('speedtest_note'),
                            style: TextStyle(
                                color: AppColors.textSecondaryOf(context),
                                fontSize: 13,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                StaggeredItem(
                  index: 1,
                  child: _ResultCard(
                    icon: Icons.download_rounded,
                    label: settings.tr('speedtest_download'),
                    value: _formatSpeed(s.downloadMbps),
                    active: s.phase == SpeedTestPhase.download,
                  ),
                ),
                StaggeredItem(
                  index: 2,
                  child: _ResultCard(
                    icon: Icons.upload_rounded,
                    label: settings.tr('speedtest_upload'),
                    value: _formatSpeed(s.uploadMbps),
                    active: s.phase == SpeedTestPhase.upload,
                  ),
                ),
                StaggeredItem(
                  index: 3,
                  child: _ResultCard(
                    icon: Icons.speed_rounded,
                    label: settings.tr('speedtest_ping'),
                    value: _formatPing(s.pingMs),
                    active: s.phase == SpeedTestPhase.ping,
                  ),
                ),
                const SizedBox(height: 12),
                if (s.running) ...[
                  StaggeredItem(
                    index: 4,
                    child: GlassPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${settings.tr('speedtest_measuring')} — ${_phaseLabel(s, settings)}',
                                  style: TextStyle(
                                      color:
                                          AppColors.textPrimaryOf(context),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GlassProgressBar(progress: s.progress),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (s.phase == SpeedTestPhase.error) ...[
                  StaggeredItem(
                    index: 4,
                    child: GlassPanel(
                      child: Text(
                        settings.tr('speedtest_failed'),
                        style: TextStyle(
                            color: AppColors.danger, fontSize: 13, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                StaggeredItem(
                  index: 5,
                  child: GlassButton(
                    label: s.phase == SpeedTestPhase.done ||
                            s.phase == SpeedTestPhase.error
                        ? settings.tr('speedtest_retry')
                        : settings.tr('speedtest_start'),
                    icon: Icons.speed_rounded,
                    enabled: !s.running,
                    onPressed: s.running
                        ? null
                        : () {
                            if (s.phase == SpeedTestPhase.done ||
                                s.phase == SpeedTestPhase.error) {
                              s.reset();
                            }
                            s.run();
                          },
                  ),
                ),
                if (s.running) ...[
                  const SizedBox(height: 10),
                  StaggeredItem(
                    index: 6,
                    child: Center(
                      child: TextButton(
                        onPressed: () => s.cancel(),
                        child: Text(
                          settings.tr('common_cancel'),
                          style: TextStyle(
                              color: AppColors.textSecondaryOf(context)),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            if (active)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              Text(
                value,
                style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
