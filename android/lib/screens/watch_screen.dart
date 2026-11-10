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

class _WatchScreenState extends State<WatchScreen> {
  WebViewController? _webController;
  String _currentUrl = 'https://m.youtube.com';
  bool _signInNoteShown = false;

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
          onPageFinished: (url) {
            if (!mounted) return;
            setState(() => _currentUrl = url);
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
  }

  bool get _isVideoPage => _currentUrl.contains('watch?v=');

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
