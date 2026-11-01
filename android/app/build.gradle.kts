plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.yjlee.well_spent_log"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.yjlee.well_spent_log"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// A stale Flutter build cache can report success while omitting bundle files.
// Check the generated bundle before copying it into the APK, on every build.
tasks.matching { it.name.startsWith("copyFlutterAssets") }.configureEach {
    outputs.upToDateWhen { false }
    doFirst {
        val variant = name.removePrefix("copyFlutterAssets")
            .replaceFirstChar { it.lowercaseChar() }
        val bundle = layout.buildDirectory
            .dir("intermediates/flutter/$variant/flutter_assets").get().asFile
        val requiredAssets = listOf(
            "AssetManifest.bin",
            "FontManifest.json",
            "fonts/MaterialIcons-Regular.otf",
            "assets/fonts/Moneygraphy%20Font/TTF/Moneygraphy-Rounded.ttf",
            "assets/fonts/NotoSansKR-Variable.ttf",
            "shaders/ink_sparkle.frag",
            "shaders/stretch_effect.frag",
        )
        val missing = requiredAssets.filter { asset ->
            val file = bundle.resolve(asset)
            !file.isFile || file.length() == 0L
        }
        check(missing.isEmpty()) {
            "Flutter asset bundle is incomplete: ${missing.joinToString()}. " +
                "Close running builds, remove only .dart_tool/flutter_build " +
                "from the project root, then rebuild. App data is unaffected."
        }
    }
}
