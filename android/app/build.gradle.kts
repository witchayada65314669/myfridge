plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // ⚠️ ต้องให้ plugin Flutter อยู่หลัง android/kotlin
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.myfridge_test"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // ✅ เปิดใช้ desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
    applicationId = "com.example.myfridge_test"
    // ✅ ตั้งค่าต่ำสุดให้รองรับ Firebase Auth 23.0.0
    minSdk = flutter.minSdkVersion
    targetSdk = 36
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}

    buildTypes {
    debug {
        // ปิด shrink สำหรับ debug
        isMinifyEnabled = false
        isShrinkResources = false
    }
    release {
        // ปิด shrink และ minify ทั้งคู่ (หากยังไม่ต้องการ optimize)
        isMinifyEnabled = false
        isShrinkResources = false
        signingConfig = signingConfigs.getByName("debug")
    }
}
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Firebase BOM เพื่อจัดการเวอร์ชันอัตโนมัติ
    implementation(platform("com.google.firebase:firebase-bom:33.4.0"))

    // ✅ โมดูลที่ใช้ในโปรเจกต์
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")

    // ✅ สำหรับ Kotlin extensions (ไม่จำเป็น แต่ช่วยให้สะดวก)
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.appcompat:appcompat:1.7.0")

    // ✅ สำหรับ desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
