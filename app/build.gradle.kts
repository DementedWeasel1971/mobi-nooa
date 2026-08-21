// Minimal Android application host module. Its only purpose is to satisfy
// the Flutter Gradle plugin's add-to-app requirement that a real
// `com.android.application` project exist as the "host app" for merging
// Flutter/Dart AOT assets — the Flutter plugin cannot attach directly to an
// `com.android.library` module. See docs/decisions/0007-close-dart-android-bridge-gap.md.
//
// It depends on android_mobi_nooa (the real library with MobiNooaService /
// MobiNooaWorker / MobiNooaBridge) so `./gradlew :app:assembleDebug` builds
// and packages a runnable demo APK end-to-end.
plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.mobi.nooa.app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.mobi.nooa.app"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation(project(":android_mobi_nooa"))
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.6.2")
}


