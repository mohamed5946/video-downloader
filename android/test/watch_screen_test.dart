// v1.0.8 — in-app YouTube download-button activation: which URLs count
// as a video page.
//
// Regression test for the field bug: Mohamed played a video inside the
// app and the download button never activated, because _currentUrl was
// only refreshed in onPageFinished and m.youtube.com navigates SPA-style
// (history.pushState, no page reload). The detection itself is a pure
// function so it is pinned here; the live-URL tracking (onUrlChange +
// 1-second location poll) feeds it the real URL.
import 'package:flutter_test/flutter_test.dart';
import 'package:snapdl/screens/watch_screen.dart';

void main() {
  group('isVideoPageUrl', () {
    test('plain watch URLs activate the button', () {
      expect(
          isVideoPageUrl(
              'https://m.youtube.com/watch?v=aqz-KE-bpKQ'),
          isTrue);
      expect(
          isVideoPageUrl(
              'https://www.youtube.com/watch?v=aqz-KE-bpKQ&t=42s'),
          isTrue);
      // v= need not be the first query parameter.
      expect(
          isVideoPageUrl(
              'https://m.youtube.com/watch?feature=shared&v=aqz-KE-bpKQ'),
          isTrue);
    });

    test('Shorts, live streams and youtu.be links activate the button',
        () {
      expect(isVideoPageUrl('https://m.youtube.com/shorts/abc123XYZ'),
          isTrue);
      expect(isVideoPageUrl('https://www.youtube.com/live/dQw4w9WgXcQ'),
          isTrue);
      expect(isVideoPageUrl('https://youtu.be/aqz-KE-bpKQ'), isTrue);
    });

    test('home, search, channel and playlist pages do NOT activate it',
        () {
      expect(isVideoPageUrl('https://m.youtube.com'), isFalse);
      expect(isVideoPageUrl('https://m.youtube.com/'), isFalse);
      expect(
          isVideoPageUrl(
              'https://m.youtube.com/results?search_query=flutter'),
          isFalse);
      expect(isVideoPageUrl('https://m.youtube.com/@NesoAcademy'),
          isFalse);
      expect(isVideoPageUrl('https://m.youtube.com/shorts'), isFalse);
      expect(isVideoPageUrl('https://m.youtube.com/live'), isFalse);
      expect(
          isVideoPageUrl(
              'https://m.youtube.com/playlist?list=PLxIvc-MGOs6iQXFnjF_STbhGdrZBphrv_'),
          isFalse);
      expect(isVideoPageUrl('https://accounts.google.com/signin'),
          isFalse);
    });

    test('non-YouTube URLs never activate it, even with watch?v= in them',
        () {
      expect(
          isVideoPageUrl(
              'https://example.com/watch?v=aqz-KE-bpKQ'),
          isFalse);
      expect(isVideoPageUrl('not a url at all'), isFalse);
      expect(isVideoPageUrl(''), isFalse);
    });
  });
}
