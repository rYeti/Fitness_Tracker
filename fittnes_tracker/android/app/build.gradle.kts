import java.io.File
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase Cloud Messaging -- the push transport, and nothing else from Firebase.
//
// Applied only when the config file is actually present. The google-services
// plugin fails the build outright on a missing google-services.json, and that
// file is obtained per developer from the Firebase console rather than committed
// by whoever clones the repo first. Without this guard a fresh checkout cannot
// build the Android app at all, which is a far worse default than shipping
// without notifications.
//
// It also keeps CI honest: no workflow builds Android on a PR, so nothing there
// would have caught the breakage before a release tag did.
val googleServicesJson = file("google-services.json")
if (googleServicesJson.exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.lifecycle(
        "google-services.json not found -- building without push notifications. " +
        "Download it from the Firebase console into android/app/ to enable them."
    )
}

// Load signing credentials from key.properties
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) load(keyPropertiesFile.inputStream())
}

android {
    namespace = "com.forgeform.app"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.forgeform.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String
            keyPassword = keyProperties["keyPassword"] as String
            storeFile = keyProperties["storeFile"]?.let { file(it as String) }
            storePassword = keyProperties["storePassword"] as String
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// Was `android { kotlinOptions { jvmTarget = "1.8" } }`, which Kotlin 2.2
// turned from a deprecation warning into an error and AGP 9 removes outright.
// Same target, current DSL. Stays on 1.8 to match compileOptions above.
kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_1_8
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
