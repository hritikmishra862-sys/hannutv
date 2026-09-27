plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") // Add Google Services plugin
}

android {
    namespace = "com.example.onyxtube"
    
    // Yahan 36 kar diya hai taaki Codemagic error na de
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.onyxtube"
        minSdk = flutter.minSdkVersion // Video player ke liye mandatory
        targetSdk = 34 // Android 12+ crash bypass ke liye isko 34 hi rakhna hai
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
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