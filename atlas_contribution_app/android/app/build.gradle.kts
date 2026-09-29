import java.util.Properties
import java.util.Base64

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
val atlasDefines = providers.gradleProperty("dart-defines").orElse("").get()
    .split(",").filter { it.isNotBlank() }.map { String(Base64.getDecoder().decode(it)) }
val atlasAiLab = "ATLAS_AI_LAB=true" in atlasDefines
// Flutter queries the application id separately without the integration target
// when uninstalling. Keep that query on the diagnostic identity as well.
val atlasDiagnostic = atlasTestTarget || "ATLAS_DIAGNOSTIC=true" in atlasDefines
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
        applicationId = if (atlasDiagnostic) {
            "com.coffeeplatform.atlas_contribution_app.diagnostic"
        } else if (atlasAiLab) {
            "com.coffeeplatform.atlas_contribution_app.beta"
        } else {
            "com.coffeeplatform.atlas_contribution_app"
        }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["atlasCleartext"] = if (atlasAiLab) "true" else "false"
        manifestPlaceholders["atlasLabel"] = if (atlasAiLab) "Atlas AI Beta" else "Atlas Katkı"
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

dependencies {
    implementation("com.google.mediapipe:tasks-vision:0.10.21")
}
