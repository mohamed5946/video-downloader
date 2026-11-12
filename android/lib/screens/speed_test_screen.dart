import 'dart:math';
import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/speed_test_service.dart';
import '../theme.dart';
import '../widgets/staggered_entrance.dart';

/// Internet speed test — on-demand only (v1.0.4), Speedtest-style
/// gauge in SnapDL liquid glass (v1.0.7).
///
/// The test NEVER starts by itself: the user is often on mobile data,
/// so it only runs when they tap the button. It uses about 12 MB
/// (10 MB download, 2 MB upload) and reports download / upload /
/// ping / jitter. The needle follows the live instantaneous speed
/// while data flows, then rests on the final average.
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

  String _formatSpeed(double? mbps, SettingsService settings) {
    if (mbps == null) return '—';
    return SpeedTestService.formatSpeed(mbps, settings.speedUnit);
  }

  String _formatMs(double? ms) {
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
        return settings.tr('speedtest_download');
      case SpeedTestPhase.error:
        return settings.tr('speedtest_failed');
      case SpeedTestPhase.idle:
        return '';
    }
  }

  /// The value the gauge shows: live while running, the final
  /// download average once done, 0 at rest.
  double _gaugeMbps(SpeedTestService s) {
    if (s.running) return s.currentMbps;
    if (s.phase == SpeedTestPhase.done) {
      return s.downloadMbps ?? s.uploadMbps ?? 0;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([_service, settings]),
      builder: (context, _) {
        final s = _service;
        final gaugeMbps = _gaugeMbps(s);
        final fraction = SpeedTestService.gaugeFraction(gaugeMbps);
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
                // Unit toggle — Mbps | MB/s, persisted in settings.
                StaggeredItem(
                  index: 1,
                  child: _UnitToggle(
                    unit: settings.speedUnit,
                    onChanged: (u) => settings.setSpeedUnit(u),
                  ),
                ),
                const SizedBox(height: 12),
                // Download / Upload cards on top.
                StaggeredItem(
                  index: 2,
                  child: Row(
                    children: [
                      Expanded(
                        child: _ResultCard(
                          icon: Icons.download_rounded,
                          label: settings.tr('speedtest_download'),
                          value: _formatSpeed(s.downloadMbps, settings),
                          active: s.phase == SpeedTestPhase.download,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ResultCard(
                          icon: Icons.upload_rounded,
                          label: settings.tr('speedtest_upload'),
                          value: _formatSpeed(s.uploadMbps, settings),
                          active: s.phase == SpeedTestPhase.upload,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // The gauge — a floating second glass layer, not flat.
                StaggeredItem(
                  index: 3,
                  child: _FloatingGlassCard(
                    child: Column(
                      children: [
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                              begin: 0, end: fraction),
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOutCubic,
                          builder: (context, animatedFraction, _) {
                            return SizedBox(
                              width: 260,
                              height: 260,
                              child: CustomPaint(
                                painter: _GaugePainter(
                                  fraction: animatedFraction,
                                  isDark: AppColors.isDark(context),
                                ),
                              ),
                            );
                          },
                        ),
                        // v1.0.8 (Ookla-style): the big speed number +
                        // phase label sit BELOW the dial, not inside it.
                        const SizedBox(height: 4),
                        if (s.running)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              gradient: AppColors.accentGradient,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              settings.tr('speedtest_live'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        if (s.running) const SizedBox(height: 6),
                        Text(
                          SpeedTestService.formatSpeed(
                              gaugeMbps, settings.speedUnit),
                          style: TextStyle(
                            color: AppColors.textPrimaryOf(context),
                            fontWeight: FontWeight.w900,
                            fontSize: 34,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _phaseLabel(s, settings),
                          style: TextStyle(
                            color: AppColors.textSecondaryOf(context),
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        if (s.running) ...[
                          const SizedBox(height: 8),
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Ping + Jitter below the gauge.
                StaggeredItem(
                  index: 4,
                  child: Row(
                    children: [
                      Expanded(
                        child: _ResultCard(
                          icon: Icons.speed_rounded,
                          label: settings.tr('speedtest_ping'),
                          value: _formatMs(s.pingMs),
                          active: s.phase == SpeedTestPhase.ping,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ResultCard(
                          icon: Icons.show_chart_rounded,
                          label: settings.tr('speedtest_jitter'),
                          value: _formatMs(s.jitterMs),
                          active: false,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (s.phase == SpeedTestPhase.error) ...[
                  StaggeredItem(
                    index: 5,
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
                  index: 6,
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
                    index: 7,
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

/// Segmented Mbps | MB/s control — the selected half gets the accent
/// gradient, the other stays plain glass.
class _UnitToggle extends StatelessWidget {
  const _UnitToggle({required this.unit, required this.onChanged});

  final String unit;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return GlassPanel(
      padding: const EdgeInsets.all(6),
      borderRadius: 18,
      child: Row(
        children: [
          _unitHalf(context, 'Mbps', settings.tr('speedtest_unit_mbps')),
          _unitHalf(context, 'MB/s', settings.tr('speedtest_unit_mbs')),
        ],
      ),
    );
  }

  Widget _unitHalf(BuildContext context, String value, String label) {
    final selected = unit == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.accentGradient : null,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : AppColors.textSecondaryOf(context),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
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
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
                ),
            ],
          ),
          const SizedBox(height: 10),
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
    );
  }
}

/// Speedtest-style dial: 270° sweep (135° → 405°), tick marks at
/// 0, 5, 10, 50, 100, 200, 500, 750, 1000 placed at EQUAL arc spacing
/// (v1.0.8, Ookla-style — the marks sit at fraction i/8, so 100 is at
/// the exact middle / top-center), a progress arc in the
/// progress-gradient colors, and a needle that rotates with [fraction].
/// The big speed number + phase label live BELOW the dial, not inside
/// it (v1.0.8).
class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.fraction, required this.isDark});

  final double fraction;
  final bool isDark;

  static const List<double> _marks = [
    0, 5, 10, 50, 100, 200, 500, 750, 1000
  ];
  static const double _startAngle = 3 * pi / 4; // 135°
  static const double _sweep = 3 * pi / 2; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 18;
    final trackColor = (isDark ? Colors.white : const Color(0xFF1E2A32))
        .withOpacity(0.10);

    // Track arc.
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _startAngle,
      _sweep,
      false,
      trackPaint,
    );

    // Progress arc in the progress-gradient colors.
    if (fraction > 0) {
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..shader = AppColors.progressGradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        );
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        _startAngle,
        _sweep * fraction.clamp(0.0, 1.0),
        false,
        progressPaint,
      );
    }

    // Tick marks + labels at equal arc spacing (v1.0.8): each mark
    // sits at fraction i/8 via the piecewise-linear gaugeFraction.
    final tickPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF1E2A32))
          .withOpacity(0.35)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final labelColor =
        (isDark ? const Color(0xFFA9BCC6) : const Color(0xFF5A6B76));
    for (final mark in _marks) {
      final f = SpeedTestService.gaugeFraction(mark);
      final angle = _startAngle + _sweep * f;
      final dir = Offset(cos(angle), sin(angle));
      final outer = center + dir * (radius - 14);
      final inner = center + dir * (radius - 24);
      canvas.drawLine(inner, outer, tickPaint);
      final label = mark >= 1000
          ? '1000'
          : mark == mark.truncateToDouble()
              ? mark.toInt().toString()
              : mark.toString();
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          // v1.0.8: explicit Cairo — a CustomPainter's TextPainter does
          // not inherit the theme's font, so without this the tick
          // numbers fall back to the system font (and render as tofu
          // boxes where no system font exists, e.g. widget tests).
          style: TextStyle(
              color: labelColor, fontSize: 10, fontFamily: 'Cairo'),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelPos = center + dir * (radius - 38);
      tp.paint(
        canvas,
        labelPos - Offset(tp.width / 2, tp.height / 2),
      );
    }

    // Needle — rotates live with the current speed.
    final needleAngle = _startAngle + _sweep * fraction.clamp(0.0, 1.0);
    final needleDir = Offset(cos(needleAngle), sin(needleAngle));
    final needlePaint = Paint()
      ..color = const Color(0xFF3E6274)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center - needleDir * 12,
      center + needleDir * (radius - 48),
      needlePaint,
    );
    canvas.drawCircle(center, 7, Paint()..color = const Color(0xFF3E6274));
    canvas.drawCircle(center, 3.5, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.isDark != isDark;
}
