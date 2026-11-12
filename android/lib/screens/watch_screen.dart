import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../theme.dart';

/// In-app YouTube watch page (WebView).
///
/// Ads are shown normally — Mohamed explicitly does not care about
/// YouTube ads here (he downloads instead). Google sign-in is
/// best-effort: Google often blocks sign-in inside embedded WebViews,
/// so a failure shows a clear message instead of pretending to work.
/// The floating button hands the current video URL to the download flow.
class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key, required this.onDownloadUrl});

  /// Called with the current video URL when the user taps the download
  /// button; the parent switches to Home and fetches its formats.
  final void Function(String url) onDownloadUrl;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

/// Is [url] a YouTube video page — i.e. should the floating download
/// button be shown for it?
///
/// v1.0.8: the old check was a plain `contains('watch?v=')` on a URL
/// that was only refreshed in onPageFinished. m.youtube.com is an SPA,
/// so tapping a video navigates with history.pushState and never fires
/// onPageFinished — the button never appeared even while a video
/// played. This check also covers Shorts, live streams and youtu.be
/// links, and parses the URL instead of substring-matching so a search
/// or channel page can never count as a video.
bool isVideoPageUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  const youTubeHosts = {
    'm.youtube.com',
    'www.youtube.com',
    'youtube.com',
    'youtu.be',
  };
  if (!youTubeHosts.contains(host)) return false;
  if (host == 'youtu.be') return uri.pathSegments.isNotEmpty;
  if (uri.path == '/watch' && uri.queryParameters.containsKey('v')) {
    return true;
  }
  if (uri.pathSegments.isNotEmpty &&
      (uri.pathSegments.first == 'shorts' ||
          uri.pathSegments.first == 'live')) {
    return uri.pathSegments.length > 1;
  }
  return false;
}

class _WatchScreenState extends State<WatchScreen> {
  WebViewController? _webController;
  String _currentUrl = 'https://m.youtube.com';
  bool _signInNoteShown = false;
  // v1.0.8: backstop poll of the WebView's live URL (see _pollLiveUrl).
  Timer? _urlPollTimer;
  bool _polling = false;

  /// Record a new current URL (from any of the three trackers below).
  /// No setState when nothing changed, so the poll doesn't rebuild
  /// the page every second.
  void _updateCurrentUrl(String? url) {
    if (url == null || url.isEmpty || url == _currentUrl) return;
    if (!mounted) return;
    setState(() => _currentUrl = url);
  }

  /// Backstop for SPA navigations: ask the page itself where it is.
  /// onUrlChange normally catches pushState navigations, but if the
  /// platform ever misses one, this poll still activates the button
  /// within a second of the video opening.
  Future<void> _pollLiveUrl() async {
    final controller = _webController;
    if (controller == null || _polling || !mounted) return;
    _polling = true;
    try {
      final raw = await controller
          .runJavaScriptReturningResult('window.location.href');
      // Android returns the string JSON-encoded (with quotes).
      final href = raw
          .toString()
          .replaceAll(RegExp('^["\']|["\']\$'), '');
      _updateCurrentUrl(href);
    } catch (_) {
      // The page may be mid-navigation — the next tick retries.
    } finally {
      _polling = false;
    }
  }

  @override
  void dispose() {
    _urlPollTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // No WebView platform exists in widget tests / previews — the
    // placeholder is shown there instead, so skip creating the controller.
    if (SnapDLApp.testPreview != null) return;
    _webController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0A0F1E))
      ..setNavigationDelegate(
        NavigationDelegate(
          // v1.0.8: fires on SPA (pushState) navigations too — this is
          // what actually tracks a video opening on m.youtube.com.
          onUrlChange: (change) => _updateCurrentUrl(change.url),
          onPageFinished: (url) {
            if (!mounted) return;
            _updateCurrentUrl(url);
            if (url.contains('accounts.google.com') && !_signInNoteShown) {
              _signInNoteShown = true;
              final settings = SettingsService.instance;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(settings.tr('watch_signin_note')),
                  duration: const Duration(seconds: 6),
                  action: SnackBarAction(
                    label: settings.tr('watch_open_browser'),
                    textColor: AppColors.glowCyan,
                    onPressed: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              );
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://m.youtube.com'));
    // v1.0.8: poll the live URL once a second while the page is open —
    // the backstop if onUrlChange ever misses an SPA navigation.
    _urlPollTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _pollLiveUrl());
  }

  bool get _isVideoPage => isVideoPageUrl(_currentUrl);

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    // Widget-test previews have no real WebView — show the same chrome
    // with a placeholder panel instead of a blank platform view.
    final previewMode = SnapDLApp.testPreview != null;
    return Stack(
      children: [
        if (previewMode || _webController == null)
          _YouTubePlaceholder(currentUrl: _currentUrl)
        else
          WebViewWidget(controller: _webController!),
        if (_isVideoPage || previewMode)
          Positioned(
            right: 16,
            // Floats above the bottom nav pill (extendBody layout).
            bottom: 100,
            child: FloatingActionButton.extended(
              backgroundColor: AppColors.glowCyan,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.download_rounded),
              label: Text(
                settings.tr('watch_download'),
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              onPressed: () => widget.onDownloadUrl(_currentUrl),
            ),
          ),
      ],
    );
  }
}

class _YouTubePlaceholder extends StatelessWidget {
  const _YouTubePlaceholder({required this.currentUrl});

  final String currentUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F0F0F),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.youtube,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text(
                'YouTube',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_outline_rounded,
                      color: Colors.white38, size: 56),
                  const SizedBox(height: 10),
                  Text(
                    SettingsService.instance.tr('watch_placeholder'),
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'youtube.com',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
