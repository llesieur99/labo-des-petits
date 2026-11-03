import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingFile = System.getenv("LUDIBALLON_KEY_PROPERTIES")?.let { file(it) }
    ?: rootProject.file("key.properties")
val releaseSigning = Properties().apply {
    if (signingFile.isFile) signingFile.inputStream().use { load(it) }
}
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("release", ignoreCase = true) }
if (releaseRequested && !signingFile.isFile) {
    throw GradleException("Signature Ludiballon manquante : définir LUDIBALLON_KEY_PROPERTIES ou android/key.properties. Aucune signature de debug pour une release.")
}

android {
    namespace = "ca.lesieur.jeuxEnfants"
    // Versions figées (pas flutter.compileSdkVersion) pour garantir la même
    // config sur macOS (iOS) et Windows (Android).
    // targetSdk 36 : obligatoire pour toute nouvelle app sur Google Play
    // depuis le 31 août 2026. audio_session impose minSdk 24 ; le build
    // Gradle sur Android échoue à 23 lors de la fusion du manifeste.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ca.lesieur.jeuxEnfants"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingFile.isFile) {
            create("release") {
                storeFile = file(releaseSigning.getProperty("storeFile"))
                storePassword = releaseSigning.getProperty("storePassword")
                keyAlias = releaseSigning.getProperty("keyAlias")
                keyPassword = releaseSigning.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
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
