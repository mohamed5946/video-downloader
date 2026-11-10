import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import 'log_service.dart';

/// Dart side of the DNS-level ad blocker (Android VpnService).
///
/// Flow: start() → native 'prepare' → if the system needs the user's
/// consent, 'launchConsent' opens the Android VPN dialog; when the user
/// approves, the native side starts the service and reports back via
/// 'vpnConsentResult'. Status is also re-checked whenever the app
/// resumes, so the toggle always reflects reality.
///
/// On web / in widget tests there is no native service — every call
/// fails safe (running = false) and the UI shows the feature as
/// unavailable on this device.
class AdBlockService extends ChangeNotifier {
  AdBlockService._();

  static final AdBlockService instance = AdBlockService._();

  static const _channel = MethodChannel('com.valor.snapdl/adblock');

  bool running = false;
  int blockedCount = 0;
  bool supported = true;
  bool _handlerSet = false;

  void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'vpnConsentResult') {
        final granted =
            (call.arguments as Map?)?['granted'] as bool? ?? false;
        if (granted) {
          await refresh();
        } else {
          LogService.instance.add(
              LogCategory.adblock, 'VPN permission denied by user');
          running = false;
          notifyListeners();
        }
      }
    });
  }

  Future<void> refresh() async {
    _ensureHandler();
    try {
      running = await _channel.invokeMethod<bool>('isRunning') ?? false;
      blockedCount = await _channel.invokeMethod<int>('blockedCount') ?? 0;
      supported = true;
    } on MissingPluginException {
      supported = false;
      running = false;
    } catch (e) {
      supported = false;
      running = false;
      LogService.instance
          .error(LogCategory.adblock, 'Ad blocker status failed', '$e');
    }
    notifyListeners();
  }

  /// Returns true if the service started now, false if the user still
  /// has to approve the VPN dialog (or it failed).
  Future<bool> start() async {
    _ensureHandler();
    try {
      final prep =
          await _channel.invokeMapMethod<String, dynamic>('prepare') ?? {};
      if (prep['needsConsent'] == true) {
        await _channel.invokeMethod<bool>('launchConsent');
        LogService.instance
            .add(LogCategory.adblock, 'Waiting for VPN permission…');
        return false; // consent result arrives via the handler
      }
      await _channel.invokeMethod<bool>('start');
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await refresh();
      if (running) {
        LogService.instance.add(LogCategory.adblock, 'Ad blocker started');
      }
      return running;
    } catch (e) {
      LogService.instance
          .error(LogCategory.adblock, 'Ad blocker start failed', '$e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _channel.invokeMethod<bool>('stop');
    } catch (e) {
      LogService.instance
          .error(LogCategory.adblock, 'Ad blocker stop failed', '$e');
    }
    await refresh();
    if (!running) {
      LogService.instance.add(LogCategory.adblock, 'Ad blocker stopped');
    }
  }

  /// Open Android's top-level Settings (Private DNS fallback:
  /// Network & internet → Private DNS → hostname dns.adguard-dns.com).
  static Future<void> openSystemSettings() async {
    await _channel.invokeMethod<void>('openSystemSettings');
  }

  /// Download the latest StevenBlack hosts file (used on next service
  /// start). Returns true on success.
  Future<bool> updateBlocklist() async {
    try {
      final ok =
          await _channel.invokeMethod<bool>('updateBlocklist') ?? false;
      LogService.instance.add(LogCategory.adblock,
          ok ? 'Blocklist updated' : 'Blocklist update failed');
      return ok;
    } catch (e) {
      LogService.instance
          .error(LogCategory.adblock, 'Blocklist update failed', '$e');
      return false;
    }
  }
}
