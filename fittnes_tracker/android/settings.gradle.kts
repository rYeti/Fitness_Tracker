pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

// Three versions the Flutter Gradle plugin version-checks on every build, and
// hard-fails below its floor. The release workflow tracks the stable channel
// unpinned, so a Flutter release can raise a floor with nothing here having
// changed — which is what broke the 1.0.2+11 release build: Gradle 8.11.1 was
// "lower than Flutter's minimum supported version of 8.14.0". AGP 8.9.1 and
// Kotlin 2.1.0 were below their floors too and would have failed the next two
// runs in turn, since the checks run one after another.
//
// Floors are in Flutter's DependencyVersionChecker.kt (error* fails the build,
// warn* is a deprecation notice that becomes an error in some later release):
//
//              here      error     warn
//   Gradle     8.14.5    8.14.0    9.1.0     (wrapper, not set here)
//   AGP        8.13.0    8.11.1    9.0.1
//   Kotlin     2.3.21    2.2.20    2.3.20
//
// AGP stays on the 8.x line deliberately rather than following Flutter's own
// template (Gradle 9.3.1 / AGP 9.1.0 / KGP 2.4.0). AGP 9 defaults both
// `android.newDsl` and `android.builtInKotlin` to true: the first is what the
// failing build's Flutter Fix hint warned breaks applying the Flutter plugin,
// and the second replaces the `org.jetbrains.kotlin.android` plugin this module
// applies. It also requires Gradle >= 9.1. That is a migration to make on its
// own, not a side effect of unblocking a release — so the remaining warn
// thresholds stay unmet for now.
//
// The three versions above are inside each other's supported ranges: AGP 8.13
// needs Gradle >= 8.13 and JDK 17 (the workflow installs 17), and KGP 2.3.21
// supports Gradle 7.6.3-9.3.0 with AGP 8.2.2-9.0.0.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.13.0" apply false
    id("org.jetbrains.kotlin.android") version "2.3.21" apply false
    // Declared here, applied conditionally in app/build.gradle.kts -- the plugin
    // hard-fails the build when google-services.json is absent, and that file is
    // per-developer setup rather than something the repo can guarantee.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
