import 'package:flutter/material.dart';
import 'services/settings_service.dart';

/// Supported platforms, detected from the pasted URL.
enum PlatformKind { youtube, tiktok, instagram, facebook, twitter, unknown }

extension PlatformKindX on PlatformKind {
  String get label {
    switch (this) {
      case PlatformKind.youtube:
        return 'YouTube';
      case PlatformKind.tiktok:
        return 'TikTok';
      case PlatformKind.instagram:
        return 'Instagram';
      case PlatformKind.facebook:
        return 'Facebook';
      case PlatformKind.twitter:
        return 'X (Twitter)';
      case PlatformKind.unknown:
        return 'Web';
    }
  }

  Color get color {
    switch (this) {
      case PlatformKind.youtube:
        return const Color(0xFFFF0000);
      case PlatformKind.tiktok:
        return const Color(0xFF25F4EE);
      case PlatformKind.instagram:
        return const Color(0xFFE1306C);
      case PlatformKind.facebook:
        return const Color(0xFF1877F2);
      case PlatformKind.twitter:
        return const Color(0xFF1D9BF0);
      case PlatformKind.unknown:
        return const Color(0xFF9AA7BD);
    }
  }

  /// Material icon for the platform badge. The old text glyphs ('▶', '♪',
  /// '◎', '𝕏') are not in the Cairo font, so they rendered as empty boxes
  /// in previews — icons render everywhere, on device and in screenshots.
  IconData get badgeIcon {
    switch (this) {
      case PlatformKind.youtube:
        return Icons.play_arrow_rounded;
      case PlatformKind.tiktok:
        return Icons.music_note_rounded;
      case PlatformKind.instagram:
        return Icons.camera_alt_rounded;
      case PlatformKind.facebook:
        return Icons.facebook;
      case PlatformKind.twitter:
        // No X logo in Material Icons — a bold X reads the same at
        // badge size.
        return Icons.close_rounded;
      case PlatformKind.unknown:
        return Icons.download_rounded;
    }
  }

  static PlatformKind detect(String url) {
    final u = url.toLowerCase();
    if (u.contains('youtube.com') || u.contains('youtu.be')) {
      return PlatformKind.youtube;
    }
    if (u.contains('tiktok.com')) return PlatformKind.tiktok;
    if (u.contains('instagram.com')) return PlatformKind.instagram;
    if (u.contains('facebook.com') || u.contains('fb.watch')) {
      return PlatformKind.facebook;
    }
    if (u.contains('twitter.com') || u.contains('x.com')) {
      return PlatformKind.twitter;
    }
    return PlatformKind.unknown;
  }
}

enum DownloadStatus { queued, downloading, paused, done, error, cancelled }

/// Metadata about a pasted link, from `yt-dlp -J`: the video's original
/// title, duration and thumbnail, plus the best single-file direct stream
/// URL for the optional in-app preview player.
class VideoInfo {
  VideoInfo({
    required this.title,
    required this.durationSeconds,
    required this.thumbnailUrl,
    required this.streamUrl,
    required this.formats,
  });

  final String title;
  final int durationSeconds; // 0 when unknown
  final String thumbnailUrl;
  final String streamUrl; // '' when no playable direct stream
  final List<FormatOption> formats;

  String get durationText {
    if (durationSeconds <= 0) return '--:--';
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// One downloadable format returned by yt-dlp -J.
class FormatOption {
  FormatOption({
    required this.id,
    required this.label,
    required this.detail,
    required this.isAudioOnly,
    required this.height,
    required this.sizeText,
    this.sizeBytes = 0,
  });

  final String id; // yt-dlp format selector, e.g. "137+140" or "best"
  final String label; // e.g. "1080p", "Highest", "Audio MP3"
  final String detail; // e.g. "mp4 · 1920×1080 · 8.4 MB"
  final bool isAudioOnly;
  final int height; // 0 for audio / unknown
  final String sizeText;
  // v1.0.6: total bytes of all files this option downloads (video +
  // audio), 0 when any part is unknown. The native side uses it to
  // show overall progress across phases (video → audio → merge)
  // instead of restarting the bar at 0% for each file, and to seed
  // the bar from existing .part files on resume.
  final int sizeBytes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'detail': detail,
        'isAudioOnly': isAudioOnly,
        'height': height,
        'sizeText': sizeText,
        'sizeBytes': sizeBytes,
      };

  factory FormatOption.fromJson(Map<String, dynamic> j) => FormatOption(
        id: j['id'] as String,
        label: j['label'] as String,
        detail: j['detail'] as String,
        isAudioOnly: j['isAudioOnly'] as bool,
        height: (j['height'] as num).toInt(),
        sizeText: j['sizeText'] as String,
        sizeBytes: (j['sizeBytes'] as num?)?.toInt() ?? 0,
      );
}

/// A download in progress (or paused).
class ActiveDownload {
  ActiveDownload({
    required this.id,
    required this.url,
    required this.title,
    required this.platform,
    required this.qualityLabel,
    required this.isAudioOnly,
    this.progress = 0,
    this.speed = '',
    this.etaSeconds = 0,
    this.status = DownloadStatus.downloading,
    this.filePath,
    this.fileSizeBytes = 0,
    this.error,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now(),
       lastEventAt = startedAt ?? DateTime.now();

  final String id;
  final String url;
  final String title;
  final PlatformKind platform;
  final String qualityLabel;
  final bool isAudioOnly;
  double progress; // 0.0 – 1.0
  String speed; // e.g. "4.2 MB/s"
  int etaSeconds;
  DownloadStatus status;
  String? filePath;
  int fileSizeBytes;
  String? error;
  // v1.0.6: completion watchdog — when the last progress event arrived
  // (any event counts: progress, done, error) and when the download
  // started (the folder check only trusts files newer than this).
  final DateTime startedAt;
  DateTime lastEventAt;
  // v1.0.6: how many times this item was resumed (progress must never
  // drop back to 0 on resume — it continues from the .part).
  int resumeCount = 0;

  String get etaText {
    if (etaSeconds <= 0) return '--:--';
    final m = etaSeconds ~/ 60;
    final s = etaSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get percentText => '${(progress * 100).toStringAsFixed(0)}%';
}

/// One finished download, kept in local history.
class HistoryEntry {
  HistoryEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.platform,
    required this.qualityLabel,
    required this.isAudioOnly,
    required this.date,
    required this.filePath,
    required this.fileSizeBytes,
  });

  final String id;
  final String url;
  final String title;
  final PlatformKind platform;
  final String qualityLabel;
  final bool isAudioOnly;
  final DateTime date;
  final String filePath;
  final int fileSizeBytes;

  String get sizeText {
    if (fileSizeBytes <= 0) return '—';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    if (fileSizeBytes < 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Localised date: Arabic month names in Arabic mode, English in English mode.
  String dateTextFor(String language) {
    final d = date;
    const monthsEn = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const monthsAr = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    final months = language == 'ar' ? monthsAr : monthsEn;
    return '${d.day} ${months[d.month - 1]} ${d.year} · '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'title': title,
        'platform': platform.name,
        'qualityLabel': qualityLabel,
        'isAudioOnly': isAudioOnly,
        'date': date.toIso8601String(),
        'filePath': filePath,
        'fileSizeBytes': fileSizeBytes,
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: j['id'] as String,
        url: j['url'] as String,
        title: j['title'] as String,
        platform: PlatformKind.values.firstWhere(
          (p) => p.name == j['platform'],
          orElse: () => PlatformKind.unknown,
        ),
        qualityLabel: j['qualityLabel'] as String,
        isAudioOnly: j['isAudioOnly'] as bool,
        date: DateTime.parse(j['date'] as String),
        filePath: j['filePath'] as String,
        fileSizeBytes: (j['fileSizeBytes'] as num).toInt(),
      );
}

/// Diagnostics log categories (standing build rule: logs from day one).
enum LogCategory { engine, download, network, storage, update, ui, adblock }

extension LogCategoryX on LogCategory {
  String get label {
    final s = SettingsService.instance;
    return switch (this) {
      LogCategory.engine => s.tr('logcat_engine'),
      LogCategory.download => s.tr('logcat_download'),
      LogCategory.network => s.tr('logcat_network'),
      LogCategory.storage => s.tr('logcat_storage'),
      LogCategory.update => s.tr('logcat_update'),
      LogCategory.ui => s.tr('logcat_ui'),
      LogCategory.adblock => s.tr('logcat_adblock'),
    };
  }

  Color get color {
    switch (this) {
      case LogCategory.engine:
        return const Color(0xFF22D3EE);
      case LogCategory.download:
        return const Color(0xFFA78BFA);
      case LogCategory.network:
        return const Color(0xFF34D399);
      case LogCategory.storage:
        return const Color(0xFFFBBF24);
      case LogCategory.update:
        return const Color(0xFFF472B6);
      case LogCategory.ui:
        return const Color(0xFF9AA7BD);
      case LogCategory.adblock:
        return const Color(0xFF34D399);
    }
  }
}

class LogEntry {
  LogEntry({
    required this.time,
    required this.category,
    required this.message,
    this.detail,
  });

  final DateTime time;
  final LogCategory category;
  final String message;
  final String? detail;

  String get timeText =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'category': category.name,
        'message': message,
        'detail': detail,
      };

  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(
        time: DateTime.parse(j['time'] as String),
        category: LogCategory.values.firstWhere(
          (c) => c.name == j['category'],
          orElse: () => LogCategory.ui,
        ),
        message: j['message'] as String,
        detail: j['detail'] as String?,
      );
}
