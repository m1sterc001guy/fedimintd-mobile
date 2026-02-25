import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties if it exists
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasSigningConfig = keystorePropertiesFile.exists()

if (hasSigningConfig) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "org.fedimint.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.3.13750724"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "org.fedimint.mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters.add("arm64-v8a")
        }
    }

    // Only configure signing if key.properties exists
    // F-Droid builds unsigned APKs and signs them with their own key
    if (hasSigningConfig) {
        signingConfigs {
            create("release") {
                storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeType = "pkcs12"
            }
        }
    }

    buildTypes {
        release {
            if (hasSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

// Exclude Google Play Core dependencies for F-Droid compatibility
// These are pulled in transitively but not needed for this app
configurations.all {
    exclude(group = "com.google.android.play", module = "core")
    exclude(group = "com.google.android.play", module = "core-ktx")
    exclude(group = "com.google.android.play", module = "core-common")
    exclude(group = "com.google.android.play", module = "feature-delivery")
    exclude(group = "com.google.android.play", module = "feature-delivery-ktx")
    exclude(group = "com.google.android.play", module = "app-update")
    exclude(group = "com.google.android.play", module = "app-update-ktx")
    exclude(group = "com.google.android.play", module = "review")
    exclude(group = "com.google.android.play", module = "review-ktx")
}
