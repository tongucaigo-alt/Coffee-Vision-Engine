import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingFile = rootProject.file("key.properties")
// Flutter test generates a temporary listener target outside integration_test/.
// Fail closed: only explicit production entrypoints may own contributor data.
val atlasTarget = providers.gradleProperty("target").orElse("lib/main.dart")
    .get().replace('\\', '/')
val atlasProductionTargets = listOf("lib/main.dart", "lib/offline_main.dart")
val atlasTestTarget = atlasProductionTargets.none {
    atlasTarget == it || atlasTarget.endsWith("/$it")
}
val signing = Properties().apply { if (signingFile.exists()) signingFile.inputStream().use { load(it) } }
if (gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) } && !signingFile.exists()) {
    throw GradleException("Founder signing key is required for a release APK. Debug signing is not a distribution key.")
}

android {
    namespace = "com.coffeeplatform.atlas_contribution_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (atlasTestTarget) {
            "com.coffeeplatform.atlas_contribution_app.diagnostic"
        } else {
            "com.coffeeplatform.atlas_contribution_app"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingFile.exists()) create("founder") {
            keyAlias = signing.getProperty("keyAlias")
            keyPassword = signing.getProperty("keyPassword")
            storeFile = file(signing.getProperty("storeFile"))
            storePassword = signing.getProperty("storePassword")
        }
    }
    buildTypes {
        release {
            if (signingFile.exists()) signingConfig = signingConfigs.getByName("founder")
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
