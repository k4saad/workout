import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. See docs/00-audit.md A4: shipping debug-signed release APKs and
// switching to a real keystore later forces an uninstall, which deletes the training
// database AND every progress photo. So the real key exists from Phase 0.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "de.saad.keller_twelve"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 19.x uses java.time on minSdk 24, which
        // only exists from API 26. Desugaring back-ports it. Without this the
        // release build fails at :app:checkReleaseAarMetadata, and the rest
        // timer is the feature that depends on it.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "de.saad.kellertwelve"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // NEVER point this at signingConfigs.debug. Changing the signing key later
            // means uninstall-to-update, which wipes the DB and the photos.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                throw GradleException(
                    "android/key.properties is missing. A release build MUST be signed " +
                    "with the real keystore — see docs/03-build-plan.md Phase 0.3."
                )
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Required by the compileOptions block above. Keep in step with what
    // flutter_local_notifications asks for; it currently needs 2.1.4+.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
