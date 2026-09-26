plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.aethernav.aethernav_edge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.aethernav.aethernav_edge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ML Kit (object detection, text recognition) requires a minimum of API 24.
        minSdk = maxOf(24, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Prefer arm64-v8a (every current Android phone, incl. the target
        // device). NOTE: abiFilters only constrains ABIs for code the Android
        // NDK build compiles here — it does NOT filter the prebuilt .so libs
        // that ship inside the llama.cpp / ML Kit / Flutter AARs. Even
        // `--target-platform android-arm64` leaves ML Kit's per-ABI .so in a
        // universal APK. To ship a true single-ABI build, use
        // `flutter build apk --release --split-per-abi` and install the
        // app-arm64-v8a-release.apk split.
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")

            // Keep R8 code/resource shrinking off for release. ML Kit's
            // TextRecognizer references optional language models (Chinese,
            // Devanagari, Japanese, Korean) we don't bundle; full-mode R8
            // treats those missing classes as fatal and fails the build. The
            // APK size is dominated by native .so libs (llama.cpp, ML Kit),
            // which R8 doesn't touch, so shrinking buys little here.
            isMinifyEnabled = false
            isShrinkResources = false
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
