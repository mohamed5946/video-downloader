import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../services/log_service.dart';
import '../widgets/staggered_entrance.dart';
import '../services/settings_service.dart';
import '../theme.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  LogCategory? _filter;

  @override
  Widget build(BuildContext context) {
    final log = LogService.instance;
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([log, settings]),
      builder: (context, _) {
        final entries = _filter == null
            ? log.entries
            : log.entries.where((e) => e.category == _filter).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _FilterChip(
                            label: settings.tr('logs_all'),
                            selected: _filter == null,
                            onTap: () => setState(() => _filter = null),
                          ),
                          ...LogCategory.values.map((c) => Padding(
                                padding: const EdgeInsets.only(left: 6),
                                child: _FilterChip(
                                  label: c.label,
                                  selected: _filter == c,
                                  color: c.color,
                                  onTap: () =>
                                      setState(() => _filter = c),
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: settings.tr('logs_copy'),
                    size: 38,
                    onPressed: entries.isEmpty
                        ? null
                        : () async {
                            final text = await log.exportText();
                            await Clipboard.setData(
                                ClipboardData(text: text));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(settings.tr('logs_copied'))),
                              );
                            }
                          },
                  ),
                  const SizedBox(width: 8),
                  GlassIconButton(
                    icon: Icons.delete_sweep_rounded,
                    tooltip: settings.tr('logs_clear'),
                    size: 38,
                    color: AppColors.danger,
                    onPressed: entries.isEmpty ? null : () => log.clear(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        settings.tr('logs_empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13),
                      ),
                    )
                  : StaggeredScope(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final e = entries[entries.length - 1 - i];
                          return StaggeredItem(
                            index: i,
                            child: _LogRow(entry: e),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? AppColors.glowCyan).withOpacity(0.22)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
            color: selected
                ? (color ?? AppColors.glowCyan).withOpacity(0.5)
                : Colors.white.withOpacity(0.10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (color ?? AppColors.glowCyan)
                : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final LogEntry entry;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      borderRadius: 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: entry.category.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.category.label,
                      style: TextStyle(
                        color: entry.category.color,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      entry.timeText,
                      style: TextStyle(
                          color: AppColors.textFaint, fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  entry.message,
                  style: TextStyle(
                      color: AppColors.textPrimary, fontSize: 13),
                ),
                if (entry.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.detail!,
                    style: TextStyle(
                        color: AppColors.textFaint, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
