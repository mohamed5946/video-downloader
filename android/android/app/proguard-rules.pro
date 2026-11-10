# SnapDL proguard rules — belt and braces for v1.0.4.
#
# The release build must NOT shrink/obfuscate: R8 stripped a class the
# download service needs at runtime (v1.0.3 field log: NoClassDefFoundError
# "vr" — the obfuscated name of the missing class). Shrinking is disabled
# via --no-shrink in CI and isMinifyEnabled=false here; these rules protect
# the engine classes if shrinking is ever re-enabled by mistake.

# Download engine (youtubedl-android) and ffmpeg — keep everything.
-keep class com.yausername.youtubedl_android.** { *; }
-keep class com.arthenica.** { *; }

# Flutter embedding + plugins must never be stripped either.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class com.valor.snapdl.** { *; }
