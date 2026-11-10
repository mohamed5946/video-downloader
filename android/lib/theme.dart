import 'dart:ui';
import 'package:flutter/material.dart';

/// SnapDL design system — EXACT approved palette (2026-11-10):
/// primary #4E7A8E (blue-grey — buttons, accents, headers, active states)
/// background #F7F4E9 (warm off-white — backgrounds, cards).
/// Light theme throughout. No dark navy/purple, no light green.
/// Font: Cairo (bundled locally, Regular 400 / Bold 700 / Black 900).
class AppColors {
  static const Color primary = Color(0xFF4E7A8E);
  static const Color primaryLight = Color(0xFF7BA7B8);
  static const Color primaryDeep = Color(0xFF3E6274);
  static const Color primaryPale = Color(0xFFDCE8EC);

  // Warm off-white surfaces.
  static const Color bgTop = Color(0xFFF7F4E9);
  static const Color bgMid = Color(0xFFFAF7EE);
  static const Color bgBottom = Color(0xFFF1ECDC);

  // Aliases kept for existing references (all resolve to palette tones).
  static const Color glowBlue = primary;
  static const Color glowCyan = primary;
  static const Color glowViolet = primaryLight;
  static const Color glowGreen = primaryLight;
  static const Color glowPink = Color(0xFFC9A86A); // warm sand, sparing use

  // Dark slate text (readable on the off-white).
  static const Color textPrimary = Color(0xFF1E2A32);
  static const Color textSecondary = Color(0xFF5A6B76);
  static const Color textFaint = Color(0xFF8A9BA5);

  // ---- Night mode (v1.0.4) — same identity, dark slate surfaces. ----
  // Backgrounds: deep slate; cards: the #1F2A33 slate itself.
  static const Color darkBgTop = Color(0xFF141C22);
  static const Color darkBgMid = Color(0xFF1A242C);
  static const Color darkBgBottom = Color(0xFF10161B);
  static const Color darkSurface = Color(0xFF1F2A33);
  static const Color darkCard = Color(0xFF26343E);
  static const Color darkTextPrimary = Color(0xFFE9EFF2);
  static const Color darkTextSecondary = Color(0xFFA9BCC6);
  static const Color darkTextFaint = Color(0xFF7C93A0);
  static const Color darkGlassBorder = Color(0xFF33454F);
  // Primary lightened for contrast on dark surfaces.
  static const Color darkPrimary = Color(0xFF7BA7B8);

  /// Brightness-aware text colors — use these (not the consts above)
  /// in widget code so Light / Night both stay readable.
  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color textPrimaryOf(BuildContext context) =>
      isDark(context) ? darkTextPrimary : textPrimary;

  static Color textSecondaryOf(BuildContext context) =>
      isDark(context) ? darkTextSecondary : textSecondary;

  static Color textFaintOf(BuildContext context) =>
      isDark(context) ? darkTextFaint : textFaint;

  static Color glassBorderOf(BuildContext context) =>
      isDark(context) ? darkGlassBorder : glassBorder;

  /// Glass panel fill for the current brightness.
  static Color panelFillOf(BuildContext context) => isDark(context)
      ? const Color(0xFF1F2A33).withOpacity(0.82)
      : Colors.white.withOpacity(0.78);

  /// Circular icon-button fill — 0.70 white in light mode (as before),
  /// dark slate on night mode.
  static Color iconFillOf(BuildContext context) => isDark(context)
      ? const Color(0xFF1F2A33).withOpacity(0.82)
      : Colors.white.withOpacity(0.7);

  /// Bottom-nav pill fill — 0.72 white in light mode (as before).
  static Color navPillOf(BuildContext context) => isDark(context)
      ? const Color(0xFF1F2A33).withOpacity(0.88)
      : Colors.white.withOpacity(0.72);

  // Glass: warm-white panels on the off-white background.
  static const Color glassFill = Color(0xCCFFFFFF);
  static const Color glassBorder = Color(0xFFE0D9C3);
  static const Color glassHighlight = Color(0xFFFFFFFF);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFB45309);
  static const Color danger = Color(0xFFB91C1C);
  static const Color youtube = Color(0xFFFF0000);
  static const Color tiktok = Color(0xFF0F766E);
  static const Color instagram = Color(0xFFE1306C);
  static const Color facebook = Color(0xFF1877F2);
  static const Color twitter = Color(0xFF1D9BF0);

  static const LinearGradient accentGradient = LinearGradient(
    colors: [Color(0xFF5B8A9E), Color(0xFF436A7D)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient progressGradient = LinearGradient(
    colors: [Color(0xFF5B8A9E), primary, primaryDeep],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppTheme {
  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Cairo',
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: Color(0xFFF7F4E9),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 26),
        titleLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20),
        titleMedium: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16),
        bodyLarge: TextStyle(color: AppColors.textPrimary, fontSize: 15),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.textFaint, fontSize: 12),
        labelLarge: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF1E2A32),
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Colors.white,
        titleTextStyle: TextStyle(
            color: Color(0xFF1E2A32),
            fontWeight: FontWeight.w900,
            fontSize: 18),
        contentTextStyle: TextStyle(color: Color(0xFF5A6B76)),
      ),
    );
  }

  /// Night mode (v1.0.4) — same blue-grey identity on dark slate:
  /// background #141C22 family, surfaces #1F2A33, primary lightened
  /// to #7BA7B8 where text/accent contrast needs it, light text.
  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.transparent,
      fontFamily: 'Cairo',
      colorScheme: const ColorScheme.dark(
        primary: AppColors.darkPrimary,
        secondary: AppColors.primary,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkTextPrimary,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 26),
        titleLarge: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 20),
        titleMedium: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16),
        bodyLarge: TextStyle(color: AppColors.darkTextPrimary, fontSize: 15),
        bodyMedium:
            TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.darkTextFaint, fontSize: 12),
        labelLarge: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: Color(0xFF2A3942),
        contentTextStyle: TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.darkSurface,
        titleTextStyle: TextStyle(
            color: AppColors.darkTextPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 18),
        contentTextStyle: TextStyle(color: AppColors.darkTextSecondary),
      ),
    );
  }
}

/// Translucent glass panel with blur, soft border and top highlight.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 24,
    this.blur = 18,
    this.opacity = 0.08,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blur;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    // v1.0.4: dark glass on night mode, warm-white glass on light mode.
    final bool dark = AppColors.isDark(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColors.panelFillOf(context),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
                color: AppColors.glassBorderOf(context), width: 1),
            gradient: LinearGradient(
              colors: dark
                  ? const [
                      Color(0xD91F2A33),
                      Color(0xB31F2A33),
                    ]
                  : const [
                      Color(0xD9FFFFFF),
                      Color(0xB3FFFFFF),
                    ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E2A32).withOpacity(0.06),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Gradient pill button with press feedback.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.gradient = AppColors.accentGradient,
    this.enabled = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Gradient gradient;
  final bool enabled;

  /// Smaller padding + text, for tight rows (e.g. history actions).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && onPressed != null;
    final double hPad = compact ? 10 : 18;
    final double vPad = compact ? 10 : 13;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      opacity: active ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: active ? onPressed : null,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.18),
          child: Ink(
            decoration: BoxDecoration(
              gradient: active ? gradient : null,
              color: active
                  ? null
                  : const Color(0xFF1E2A32).withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFF1E2A32).withOpacity(0.10)),
            ),
            child: Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: compact ? 16 : 18, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 13 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular glass icon button.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.size = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        splashColor: AppColors.primary.withOpacity(0.16),
        child: Ink(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.iconFillOf(context),
            border: Border.all(color: AppColors.glassBorderOf(context)),
          ),
          child: Icon(icon,
              size: 20, color: color ?? AppColors.textPrimaryOf(context)),
        ),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Smooth animated progress bar (gradient fill, no popping).
class GlassProgressBar extends StatelessWidget {
  const GlassProgressBar({super.key, required this.progress});

  /// 0.0 – 1.0
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: Container(
        height: 12,
        // v1.0.4: light track on night mode, slate track on light mode.
        color: AppColors.isDark(context)
            ? Colors.white.withOpacity(0.12)
            : const Color(0xFF1E2A32).withOpacity(0.10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              width: constraints.maxWidth * progress.clamp(0, 1),
              decoration: const BoxDecoration(
                gradient: AppColors.progressGradient,
                borderRadius: BorderRadius.all(Radius.circular(99)),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Background: warm off-white gradient + two soft orbs
/// (blue-grey top-left, warm sand bottom-right).
class AppBackground extends StatelessWidget {
  const AppBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // v1.0.4: dark slate gradient on night mode.
    final bool dark = AppColors.isDark(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [
                  AppColors.darkBgTop,
                  AppColors.darkBgMid,
                  AppColors.darkBgBottom,
                ]
              : const [
                  AppColors.bgTop,
                  AppColors.bgMid,
                  AppColors.bgBottom,
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -70,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.14),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Container(),
              ),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -70,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC9A86A).withOpacity(0.16),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
                child: Container(),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
