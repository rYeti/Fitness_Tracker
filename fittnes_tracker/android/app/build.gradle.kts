plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.fittnes_tracker"
    compileSdk = flutter.compileSdkVersion

    defaultConfig {
        applicationId = "com.example.fittnes_tracker"
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    signingConfigs {
        create("release") {
            keyAlias = "my-key-alias"
            keyPassword = "ForgeForm"
            storeFile = file("C:/Users/Lifebook E536/my-release-key.jks")
            storePassword = "ForgeForm"
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}