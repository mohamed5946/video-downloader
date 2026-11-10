import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import '../models.dart';
import '../services/download_controller.dart';
import '../services/settings_service.dart';
import '../theme.dart';
import '../widgets/staggered_entrance.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final DownloadController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final TextEditingController _urlCtrl;
  Timer? _fetchDebounce;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(text: widget.controller.url);
    widget.controller.addListener(_sync);
  }

  void _sync() {
    if (_urlCtrl.text != widget.controller.url) {
      _urlCtrl.text = widget.controller.url;
    }
    if (mounted) setState(() {});
  }

  /// A pasted/typed link auto-loads its preview card (debounced so typing
  /// does not fire a fetch per keystroke).
  void _onUrlChanged(String value) {
    widget.controller.setUrl(value);
    _fetchDebounce?.cancel();
    final looksLikeUrl =
        (value.startsWith('http://') || value.startsWith('https://')) &&
            value.contains('.');
    if (!looksLikeUrl) return;
    _fetchDebounce = Timer(const Duration(milliseconds: 700), () {
      if (mounted && widget.controller.url == value.trim()) {
        widget.controller.fetchFormats();
      }
    });
  }

  @override
  void dispose() {
    _fetchDebounce?.cancel();
    widget.controller.removeListener(_sync);
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final settings = SettingsService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([c, settings]),
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),
              Text(
                settings.tr('home_title1'),
                style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              Text(
                settings.tr('home_title2'),
                style: TextStyle(
                  color: AppColors.textPrimaryOf(context),
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                settings.tr('home_subtitle'),
                style: TextStyle(color: AppColors.textSecondaryOf(context), fontSize: 13),
              ),
              const SizedBox(height: 16),
              GlassPanel(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _urlCtrl,
                            onChanged: _onUrlChanged,
                            style: TextStyle(
                                color: AppColors.textPrimaryOf(context), fontSize: 14),
                            decoration: InputDecoration(
                              hintText: settings.tr('home_hint'),
                              hintStyle: TextStyle(
                                  color: AppColors.textFaintOf(context), fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GlassIconButton(
                          icon: Icons.content_paste_rounded,
                          tooltip: settings.tr('tooltip_paste'),
                          onPressed: () async {
                            await c.pasteFromClipboard();
                            HapticFeedback.lightImpact();
                            if (c.url.isNotEmpty) c.fetchFormats();
                          },
                        ),
                        const SizedBox(width: 8),
                        GlassIconButton(
                          icon: Icons.clear_rounded,
                          tooltip: settings.tr('tooltip_clear'),
                          onPressed: c.url.isEmpty
                              ? null
                              : () {
                                  _urlCtrl.clear();
                                  c.setUrl('');
                                },
                        ),
                      ],
                    ),
                    if (c.url.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _PlatformChip(platform: c.platform),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              c.url,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: AppColors.textFaintOf(context), fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Preview card: hidden until a link is pasted.
              if (c.url.isNotEmpty) ...[
                const SizedBox(height: 14),
                if (c.fetchingFormats)
                  _PreviewLoading(settings: settings)
                else if (c.formats.isNotEmpty)
                  _PreviewCard(controller: c),
              ],
              if (c.fetchError != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: c.fetchError!),
              ],
              if (c.url.isNotEmpty && c.formats.isEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: c.fetchingFormats
                      // v1.0.3: while the download service is still being
                      // prepared (first run can take a while), show a
                      // disabled preparing button — the red error only
                      // appears after the setup actually fails.
                      ? GlassButton(
                          label: settings.tr('home_preparing'),
                          icon: Icons.hourglass_top_rounded,
                          onPressed: null,
                          enabled: false,
                        )
                      : GlassButton(
                          label: settings.tr('home_get_options'),
                          icon: Icons.search_rounded,
                          onPressed: () => c.fetchFormats(),
                        ),
                ),
              ],
              if (c.active.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionTitle(title: settings.tr('home_downloading')),
                const SizedBox(height: 10),
                StaggeredScope(
                  child: Column(
                    children: [
                      ...c.active.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: StaggeredItem(
                              index: e.key,
                              child: _DownloadCard(
                                  item: e.value, controller: c),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
              if (c.active.isEmpty && c.formats.isEmpty && c.url.isEmpty) ...[
                const SizedBox(height: 26),
                const _HintCard(),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.textPrimaryOf(context),
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PlatformChip extends StatelessWidget {
  const _PlatformChip({required this.platform});

  final PlatformKind platform;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: platform.color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: platform.color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(platform.badgeIcon, color: platform.color, size: 14),
          const SizedBox(width: 5),
          Text(platform.label,
              style: TextStyle(
                  color: platform.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      opacity: 0.10,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ preview card

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading({required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: Row(
        children: [
          Container(
            width: 96,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.tr('card_loading'),
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 140,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The link preview card: thumbnail (+ optional play), title, platform,
/// duration and the quality picker — confirm the right video first.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.controller});

  final DownloadController controller;

  String get _durationText {
    final s = controller.videoDurationSeconds;
    if (s <= 0) return '--:--';
    final m = s ~/ 60;
    final sec = s % 60;
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final settings = SettingsService.instance;
    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(
                url: c.thumbnailUrl,
                platform: c.platform,
                hasStream: c.streamUrl.isNotEmpty,
                onPlay: c.streamUrl.isEmpty
                    ? null
                    : () => _playPreview(context, c.streamUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.videoTitle.isEmpty
                          ? settings.tr('video_fallback')
                          : c.videoTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimaryOf(context),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _PlatformChip(platform: c.platform),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded,
                                  size: 13, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                _durationText,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _SectionTitle(title: settings.tr('home_choose_quality')),
          const SizedBox(height: 10),
          _QualityPicker(controller: c),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              label: settings.tr('home_download'),
              icon: Icons.download_rounded,
              onPressed: () => c.startDownload(),
            ),
          ),
        ],
      ),
    );
  }

  void _playPreview(BuildContext context, String streamUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => _VideoPlayerDialog(streamUrl: streamUrl),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
    required this.url,
    required this.platform,
    required this.hasStream,
    required this.onPlay,
  });

  final String url;
  final PlatformKind platform;
  final bool hasStream;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return Container(
      width: 96,
      height: 72,
      decoration: BoxDecoration(
        color: platform.color.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: platform.color.withOpacity(0.30)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (url.isNotEmpty)
            Image.network(
              url,
              width: 96,
              height: 72,
              fit: BoxFit.cover,
              errorBuilder: (context, _, __) =>
                  _ThumbFallback(platform: platform),
            )
          else
            _ThumbFallback(platform: platform),
          if (hasStream)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.85),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: settings.tr('card_play'),
                icon: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 20),
                onPressed: onPlay,
              ),
            ),
        ],
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback({required this.platform});

  final PlatformKind platform;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 72,
      color: platform.color.withOpacity(0.10),
      alignment: Alignment.center,
      child: Icon(platform.badgeIcon, color: platform.color, size: 30),
    );
  }
}

/// Optional in-app preview player (plays the direct stream URL).
class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({required this.streamUrl});

  final String streamUrl;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late final VideoPlayerController _player;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _player = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl));
    _player.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
      _player.play();
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
      return null;
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: GlassPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.tr('player_title'),
                    style: TextStyle(
                      color: AppColors.textPrimaryOf(context),
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: settings.tr('common_close'),
                  size: 38,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.textPrimaryOf(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: _failed
                    ? Center(
                        child: Text(
                          settings.tr('player_error'),
                          style: const TextStyle(color: Colors.white),
                        ),
                      )
                    : _player.value.isInitialized
                        ? Stack(
                            alignment: Alignment.center,
                            children: [
                              VideoPlayer(_player),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _player.value.isPlaying
                                        ? _player.pause()
                                        : _player.play();
                                  });
                                },
                                child: Container(
                                  color: Colors.transparent,
                                  alignment: Alignment.center,
                                  child: AnimatedOpacity(
                                    opacity:
                                        _player.value.isPlaying ? 0 : 0.9,
                                    duration:
                                        const Duration(milliseconds: 200),
                                    child: const Icon(
                                      Icons.play_circle_fill_rounded,
                                      color: Colors.white,
                                      size: 54,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ quality picker

class _QualityPicker extends StatelessWidget {
  const _QualityPicker({required this.controller});

  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    // Two-per-row compact grid, single-line chips.
    return StaggeredScope(
      child: GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        // Roomy enough that the two-line chip content never overflows
        // the cell (was 2.9 — overflowed by 1.6px at 390px width).
        childAspectRatio: 2.7,
      ),
      itemCount: controller.formats.length,
      itemBuilder: (context, index) {
        final f = controller.formats[index];
        final selected = controller.selectedFormat?.id == f.id;
        return StaggeredItem(
          index: index,
          child: GestureDetector(
          onTap: () {
            controller.selectFormat(f);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: selected ? AppColors.accentGradient : null,
              color: selected
                  ? null
                  : AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? Colors.white.withOpacity(0.35)
                    : AppColors.glassBorderOf(context),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.isAudioOnly
                          ? Icons.music_note_rounded
                          : Icons.high_quality_rounded,
                      size: 15,
                      color: selected
                          ? Colors.white
                          : AppColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        settings.qualityLabel(f.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimaryOf(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                if (f.detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    settings.qualityDetail(f.label, f.detail),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withOpacity(0.85)
                          : AppColors.textFaintOf(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ));
      },
    ),
    );
  }
}

// ----------------------------------------------------------- download card

class _DownloadCard extends StatelessWidget {
  const _DownloadCard({required this.item, required this.controller});

  final ActiveDownload item;
  final DownloadController controller;

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final isPaused = item.status == DownloadStatus.paused;
    final isError = item.status == DownloadStatus.error;
    final isQueued = item.status == DownloadStatus.queued;
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
                  color: item.platform.color.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: item.platform.color.withOpacity(0.35)),
                ),
                alignment: Alignment.center,
                child: Icon(item.platform.badgeIcon,
                    color: item.platform.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  settings.qualityLabel(item.qualityLabel),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
              if (isError)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (isQueued) ...[
            GlassProgressBar(progress: 0),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  settings.tr('dl_queued'),
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  settings.tr('dl_queued_hint'),
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(context), fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: GlassIconButton(
                icon: Icons.close_rounded,
                tooltip: settings.tr('home_cancel'),
                onPressed: () => controller.cancel(item.id),
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.percentText,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 24,
                    height: 1,
                  ),
                ),
                const Spacer(),
                if (item.speed.isNotEmpty && !isPaused)
                  _StatPill(
                      icon: Icons.speed_rounded, text: item.speed),
                if (item.speed.isNotEmpty && !isPaused)
                  const SizedBox(width: 8),
                _StatPill(
                  icon: Icons.schedule_rounded,
                  text: isPaused
                      ? settings.tr('dl_paused')
                      : settings.trf('dl_eta', {'t': item.etaText}),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GlassProgressBar(progress: item.progress),
          ],
          if (isError && item.error != null) ...[
            const SizedBox(height: 8),
            Text(
              item.error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ],
          if (!isQueued) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (isPaused)
                  Expanded(
                    child: GlassButton(
                      label: settings.tr('home_resume'),
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => controller.resume(item.id),
                    ),
                  )
                else
                  Expanded(
                    child: GlassButton(
                      label: settings.tr('home_pause'),
                      icon: Icons.pause_rounded,
                      onPressed: () => controller.pause(item.id),
                    ),
                  ),
                const SizedBox(width: 10),
                GlassIconButton(
                  icon: Icons.close_rounded,
                  tooltip: settings.tr('home_cancel'),
                  onPressed: () => controller.cancel(item.id),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    return GlassPanel(
      opacity: 0.05,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.bolt_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  settings.tr('home_how'),
                  style: TextStyle(
                    color: AppColors.textPrimaryOf(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  settings.tr('home_how_body'),
                  style: TextStyle(
                      color: AppColors.textSecondaryOf(context), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
