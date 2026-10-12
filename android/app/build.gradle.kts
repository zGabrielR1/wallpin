plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.wallpin.app"
    compileSdk = flutter.compileSdkVersion
    // flutter_inappwebview's `jni` dependency compiles native interop; use the
    // NDK it requires (backward compatible with Flutter's default).
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.wallpin.app"
        // WallpaperManager.FLAG_LOCK (lock-screen wallpaper) needs API 24.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Signed with the debug keys so `flutter build apk --release`
            // produces an installable APK without a personal keystore.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Native background worker (WallpaperWorker) — no Dart involved.
    implementation("androidx.work:work-runtime-ktx:2.9.0")
}
