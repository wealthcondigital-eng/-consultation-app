import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}

android {
    namespace = "consult.nesliferesearch.com"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications schedules with java.time, which minSdk 24
        // does not have. Desugaring backports it; without this the release
        // build refuses to link the plugin at all.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "consult.nesliferesearch.com"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The upload key. A release signed with the debug key is what Play Protect
    // blocks as harmful on install: that certificate ships with every SDK, so
    // it identifies no one. The keystore and its passwords live outside the
    // project (android/key.properties, gitignored) and are never committed.
    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

// Refuse a release build with no upload key rather than quietly producing an
// APK that will not install. Debug builds are unaffected.
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    doFirst {
        if (keystoreProperties.isEmpty()) {
            throw GradleException(
                "android/key.properties is missing, so the release build has no upload key. " +
                    "See https://docs.flutter.dev/deployment/android#sign-the-app"
            )
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
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    // Google Play in-app updates, called from AppUpdateBridge.kt.
    implementation("com.google.android.play:app-update:2.1.0")
}
