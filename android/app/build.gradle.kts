import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Kunci tanda tangan release dari android/key.properties (tidak di-commit, lihat android/.gitignore).
// Isi: storeFile, storePassword, keyAlias, keyPassword. Contoh: android/key.properties.example.
val kunciRilis = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
    namespace = "id.kateringkita.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // ID tetap aplikasi di HP dan Play Store; jangan diganti setelah rilis pertama (HP menganggapnya aplikasi lain)
        applicationId = "id.kateringkita.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // versionCode/versionName dari pubspec.yaml (version: x.y.z+N)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (!kunciRilis.isEmpty) {
            create("release") {
                storeFile = file(kunciRilis.getProperty("storeFile"))
                storePassword = kunciRilis.getProperty("storePassword")
                keyAlias = kunciRilis.getProperty("keyAlias")
                keyPassword = kunciRilis.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Tanpa key.properties (mis. laptop anggota tim) build release tetap jalan dengan kunci debug,
            // tetapi APK itu tidak bisa memperbarui APK resmi. APK untuk dibagikan wajib dibangun dengan key.properties.
            signingConfig = if (kunciRilis.isEmpty) signingConfigs.getByName("debug") else signingConfigs.getByName("release")
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
