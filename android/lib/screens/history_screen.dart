import 'package:flutter/material.dart';
import '../models.dart';
import '../services/download_controller.dart';
import '../widgets/staggered_entrance.dart';
import '../services/settings_service.dart';
import '../theme.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.controller});

  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge(
          [controller, controller.historyListenable, settings]),
      builder: (context, _) {
        final items = controller.history;
        if (items.isEmpty) {
          return _EmptyHistory(settings: settings);
        }
        return StaggeredScope(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final entry = items[i];
              return StaggeredItem(
                index: i,
                child: _HistoryCard(entry: entry, controller: controller),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.glassBorderOf(context)),
              ),
              child: Icon(Icons.history_rounded,
                  color: AppColors.textFaintOf(context), size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              settings.tr('hist_empty_title'),
              style: TextStyle(
                color: AppColors.textPrimaryOf(context),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              settings.tr('hist_empty_body'),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry, required this.controller});

  final HistoryEntry entry;
  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: entry.platform.color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: entry.platform.color.withOpacity(0.35)),
                ),
                alignment: Alignment.center,
                child: Icon(entry.platform.badgeIcon,
                    color: entry.platform.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${entry.platform.label} · ${settings.qualityLabel(entry.qualityLabel)} · ${entry.sizeText}',
                      style: TextStyle(
                          color: AppColors.textFaintOf(context), fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.dateTextFor(settings.language),
                      style: TextStyle(
                          color: AppColors.textFaintOf(context), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  label: settings.tr('hist_open'),
                  icon: Icons.play_circle_outline_rounded,
                  compact: true,
                  // v1.0.6: opening a missing file says so instead of
                  // silently doing nothing (2026-11-11 field report).
                  onPressed: () async {
                    final ok =
                        await controller.openFile(entry.filePath);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text(settings.tr('file_not_found')),
                        ),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassButton(
                  label: settings.tr('hist_again'),
                  icon: Icons.download_rounded,
                  compact: true,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5B8A9E), Color(0xFF436A7D)],
                  ),
                  onPressed: () => controller.redownload(entry),
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: settings.tr('hist_delete'),
                color: AppColors.danger,
                size: 38,
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final settings = SettingsService.instance;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(settings.tr('hist_delete_title')),
        content: Text(
          settings.trf('hist_delete_body', {'title': entry.title}),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(settings.tr('common_keep'),
                style: TextStyle(color: AppColors.textSecondaryOf(context))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(settings.tr('common_delete'),
                style: const TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteHistory(entry.id);
    }
  }
}
