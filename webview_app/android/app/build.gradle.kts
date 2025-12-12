import java.util.Properties
import java.io.FileInputStream

// Load keystore properties from key.properties
// key.properties is in the Flutter project root (parent of android directory)
val keyPropertiesFile = rootProject.file("../key.properties")
val keyProperties = Properties()
var keystorePropertiesLoaded = false
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
    keystorePropertiesLoaded = true
    println("INFO: Loaded key.properties from ${keyPropertiesFile.absolutePath}")
} else {
    println("WARNING: key.properties not found at ${keyPropertiesFile.absolutePath}")
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter Gradle Plugin
}

android {
    namespace = "com.example.webview_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.webview_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        if (keystorePropertiesLoaded) {
            val storeFilePath = keyProperties["storeFile"]?.toString()
            val keyAliasValue = keyProperties["keyAlias"]?.toString()
            val keyPasswordValue = keyProperties["keyPassword"]?.toString()
            val storePasswordValue = keyProperties["storePassword"]?.toString()
            
            if (!storeFilePath.isNullOrEmpty() && !keyAliasValue.isNullOrEmpty() && 
                !keyPasswordValue.isNullOrEmpty() && !storePasswordValue.isNullOrEmpty()) {
                // storeFilePath is relative to Flutter project root, so use parent directory
                val keystoreFile = rootProject.file("../$storeFilePath")
                if (keystoreFile.exists()) {
                    create("release") {
                        keyAlias = keyAliasValue!!
                        keyPassword = keyPasswordValue!!
                        storeFile = keystoreFile
                        storePassword = storePasswordValue!!
                    }
                    println("INFO: Release signing config created successfully")
                } else {
                    println("WARNING: Keystore file not found: ${keystoreFile.absolutePath}")
                }
            } else {
                println("WARNING: Some keystore properties are missing or empty")
            }
        } else {
            println("WARNING: key.properties file not found")
        }
    }

    buildTypes {
        getByName("debug") {
            isMinifyEnabled = false
            isShrinkResources = false // 🔥 Prevents the "unused resources" error
        }
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            val releaseSigningConfig = signingConfigs.findByName("release")
            if (releaseSigningConfig != null) {
                signingConfig = releaseSigningConfig
                println("INFO: Release signing config applied")
            } else {
                println("WARNING: Release signing config not found - bundle will be unsigned!")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
