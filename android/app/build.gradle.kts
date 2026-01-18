plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin 必须放在 Android / Kotlin 之后
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.sunriseinc.target_notebook"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // ===============================
    // ✅ Flavor 定义（JP / TW）
    // ===============================
    flavorDimensions += "region"

    productFlavors {
        create("jp") {
            dimension = "region"
            applicationId = "com.sunriseinc.target_notebook.jp"
            resValue("string", "app_name", "Target Notebook JP")
        }
        create("tw") {
            dimension = "region"
            applicationId = "com.sunriseinc.target_notebook.tw"
            resValue("string", "app_name", "Target Notebook TW")
        }
    }

    defaultConfig {
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ⚠️ 正式上架前请替换为你自己的 signingConfig
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
