plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.valor.snapdl"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.valor.snapdl"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // v1.0.1: NO ndk abiFilters here — the CI build uses
        // --split-per-abi (arm64 only) and AGP rejects abiFilters when
        // splits are configured ("Conflicting configuration").
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The download engine ships its runtime as .so files that must be
    // extracted at install (legacy packaging) — the AGP 8 replacement for
    // android:extractNativeLibs="true" in the manifest.
    packagingOptions {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    // v1.0.2: PERMANENT release signing. The keystore lives ONLY as the
    // KEYSTORE_BASE64 GitHub secret (decoded to release.keystore by CI) and
    // as a local backup in the workspace — never in the repo. Earlier builds
    // used a fresh debug key per CI runner, so v1.0.0 and v1.0.1 had
    // different certificates and Android refused updates between them.
    // Locally (no release.keystore) the build falls back to the debug key
    // so `flutter run --release` keeps working.
    signingConfigs {
        create("release") {
            val keystoreFile = rootProject.file("release.keystore")
            if (keystoreFile.exists()) {
                storeFile = keystoreFile
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS") ?: "snapdl"
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // v1.0.4: R8 shrinking/obfuscation OFF, explicitly. The
            // release build shrinks by default and R8 stripped a class
            // the download service needs at runtime (v1.0.3 field log:
            // NoClassDefFoundError "vr"). The workflow also passes
            // --no-shrink; this is the second lock. proguard-rules.pro
            // keeps the engine classes if anything ever re-enables it.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (rootProject.file("release.keystore").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // yt-dlp engine + ffmpeg, Maven Central (same engine Seal / YTDLnis use).
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
