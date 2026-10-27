import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// An existing private signing configuration may stay outside the checkout.
// Values are loaded locally and are never Gradle command-line arguments.
val signingFile = providers.gradleProperty("ATLAS_SIGNING_PROPERTIES").orNull
    ?.let { file(it) } ?: rootProject.file("key.properties")
val atlasReleaseTask = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
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
val atlasPlayTest = "ATLAS_PLAY_TEST=true" in atlasDefines
if (atlasPlayTest && ("ATLAS_AI_LAB=true" in atlasDefines || atlasDefines.any { it.startsWith("ATLAS_KIMI_TEST_KEY=") && it.substringAfter('=').isNotBlank() })) {
    throw GradleException("Play builds must not include laboratory mode or a bundled provider credential.")
}
val atlasAiLab = "ATLAS_AI_LAB=true" in atlasDefines
// Explicit sideload-only migration of the installed local Atlas test app.
// Reuse the established Kimi/laboratory runtime while preserving its records.
val atlasKimiLocalTest = "ATLAS_KIMI_LOCAL_TEST=true" in atlasDefines
if (atlasKimiLocalTest && (atlasPlayTest || !atlasAiLab || !atlasDefines.any {
    it.startsWith("ATLAS_KIMI_TEST_KEY=") && it.substringAfter('=').isNotBlank()
})) {
    throw GradleException("Local Kimi testing requires laboratory mode and a private build credential; it is not a Play build.")
}
// Flutter queries the application id separately without the integration target
// when uninstalling. Keep that query on the diagnostic identity as well.
val atlasDiagnostic = atlasTestTarget || "ATLAS_DIAGNOSTIC=true" in atlasDefines
// Visual-only fixtures must never open or replace the user's test package.
val atlasUiPreview = "ATLAS_UI_PREVIEW=true" in atlasDefines
if (atlasUiPreview && !atlasTestTarget) {
    throw GradleException("Visual preview requires an auxiliary entrypoint.")
}
val atlasLocalImageScreen = "ATLAS_IMAGE_SCREEN=true" in atlasDefines
if (atlasPlayTest && atlasReleaseTask) {
    if (atlasDiagnostic || atlasUiPreview || atlasKimiLocalTest ||
        !(atlasTarget == "lib/offline_main.dart" || atlasTarget.endsWith("/lib/offline_main.dart"))) {
        throw GradleException("Play release requires the existing offline production entrypoint and production package identity.")
    }
    if (!atlasLocalImageScreen) {
        throw GradleException("Play release must preserve the current local image-screen model and behavior.")
    }
}
val signing = Properties().apply { if (signingFile.exists()) signingFile.inputStream().use { load(it) } }
if (atlasReleaseTask && !signingFile.exists()) {
    throw GradleException("Founder signing key is required for a release APK. Debug signing is not a distribution key.")
}

android {
    if (atlasLocalImageScreen) {
        sourceSets.getByName("main").java.srcDir("src/imageScreen/kotlin")
        sourceSets.getByName("main").assets.srcDir("src/imageScreen/assets")
    }
    namespace = "com.coffeeplatform.atlas_contribution_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = if (atlasUiPreview) {
            "com.coffeeplatform.atlas_contribution_app.ui_preview"
        } else if (atlasDiagnostic) {
            "com.coffeeplatform.atlas_contribution_app.diagnostic"
        } else if (atlasAiLab && !atlasKimiLocalTest) {
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
        val atlasBaseLabel = if (atlasUiPreview) "Atlas Görsel Önizleme" else if (atlasDiagnostic) "Atlas Fotoğraf Testi" else if (atlasKimiLocalTest) "Atlas Kimi Test" else if (atlasAiLab) "Atlas AI Beta" else if (atlasPlayTest) "Atlas" else "Atlas Katkı"
        manifestPlaceholders["atlasLabel"] = if (atlasDiagnostic || atlasAiLab) "$atlasBaseLabel V${flutter.versionCode}" else atlasBaseLabel
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
            proguardFiles("proguard-rules.pro")
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
    implementation("org.opencv:opencv:4.13.0")
    implementation("com.google.mediapipe:tasks-vision:0.10.26.1")
    if (atlasLocalImageScreen) implementation("com.microsoft.onnxruntime:onnxruntime-android:1.30.0")
}
