// SPDX-FileCopyrightText: 2026 CarbonFarm OS contributors
// SPDX-License-Identifier: GPL-3.0-or-later
plugins {
    id("com.android.application")
    // Flutter Gradle Plugin phải đứng sau plugin Android và Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "vn.carbonfarmos.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "vn.carbonfarmos.app"
        // flutter_secure_storage 11 cần Android 6.0 (API 23) trở lên
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        // Lấy từ "version:" trong pubspec.yaml (0.7.0+1)
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Scheme đường quay về sau đăng nhập Keycloak (flutter_appauth tự thêm intent filter cho RedirectUriReceiverActivity)
        manifestPlaceholders["appAuthRedirectScheme"] = "vn.carbonfarmos.app"
    }

    buildTypes {
        release {
            // Chưa có khóa ký phát hành: APK release ký bằng khóa debug để cài thử được (không dùng để lên cửa hàng).
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
