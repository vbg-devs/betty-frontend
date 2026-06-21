import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    // NB: google-services is applied CONDITIONALLY below, never here — an eager apply
    // hard-fails the build when the gitignored google-services.json is absent.
}

// Firebase carve-out (CLAUDE.md): the com.google.gms.google-services plugin HARD-FAILS the
// build with "File google-services.json is missing" when the (gitignored) file is absent —
// which is the state locally and on every PR runner until a maintainer decodes
// GOOGLE_SERVICES_JSON_BASE64 (release env) in android-playstore.yml. Apply it ONLY when the
// file is present, so builds stay green with push degraded to disabled. firebase-messaging
// itself links fine with no json (its FirebaseInitProvider just no-ops at runtime). This
// mirrors iOS gating FirebaseApp.configure() on the GoogleService-Info.plist's presence.
if (file("google-services.json").exists()) {
    pluginManager.apply(libs.plugins.google.services.get().pluginId)
    logger.lifecycle("google-services.json present — Firebase Messaging enabled.")
} else {
    logger.lifecycle("google-services.json ABSENT — building without google-services; push disabled.")
}

android {
    // `namespace` is the code/R/BuildConfig package; `applicationId` is the store identity.
    // The Play app is `social.betty.android` (a fresh app — the older `social.betty.app`
    // registration's upload key was lost). Debug uses the `.debug` suffix.
    namespace = "social.betty"
    compileSdk = 36

    defaultConfig {
        applicationId = "social.betty.android"
        minSdk = 26
        targetSdk = 36
        // Build numbers ascend like iOS; CI overrides via -PversionCode/-PversionName.
        versionCode = (project.findProperty("versionCode") as String?)?.toInt() ?: 1
        versionName = (project.findProperty("versionName") as String?) ?: "1.0.0"

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }

    signingConfigs {
        // Release signing is supplied by CI from secrets (keystore decoded to a file).
        // Locally these properties are absent and release builds fall back to debug
        // signing so `assembleRelease` still works for smoke checks.
        create("release") {
            val storeFilePath = project.findProperty("RELEASE_STORE_FILE") as String?
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
                storePassword = project.findProperty("RELEASE_STORE_PASSWORD") as String?
                keyAlias = project.findProperty("RELEASE_KEY_ALIAS") as String?
                keyPassword = project.findProperty("RELEASE_KEY_PASSWORD") as String?
            }
        }
    }

    buildTypes {
        getByName("debug") {
            applicationIdSuffix = ".debug"
            isDebuggable = true
        }
        getByName("release") {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig =
                if (project.findProperty("RELEASE_STORE_FILE") != null) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            isReturnDefaultValues = true
        }
    }

    lint {
        // Lint is informational in CI (reported, not gating) — keep local builds unblocked.
        abortOnError = false
        checkReleaseBuilds = false
    }

    packaging {
        resources {
            excludes += setOf(
                "/META-INF/{AL2.0,LGPL2.1}",
                "/META-INF/versions/9/previous-compilation-data.bin",
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.lifecycle.runtime.ktx)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.activity.compose)

    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.graphics)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.material.icons.core)

    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.okhttp)
    implementation(libs.coil.compose)
    // Firebase Messaging ONLY (the "Firebase Messaging carve-out", CLAUDE.md). Auth stays
    // REST-only — DO NOT add com.google.firebase:firebase-auth here.
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)
    implementation(libs.androidx.security.crypto)
    implementation(libs.androidx.browser)

    debugImplementation(libs.androidx.compose.ui.tooling)
    debugImplementation(libs.androidx.compose.ui.test.manifest)

    testImplementation(libs.junit)
    testImplementation(libs.robolectric)
    testImplementation(libs.androidx.test.core)
    testImplementation(libs.androidx.test.core.ktx)
    testImplementation(libs.androidx.junit)
    testImplementation(libs.kotlinx.coroutines.test)

    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.junit)
    androidTestImplementation(libs.androidx.test.core)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.rules)
    androidTestImplementation(libs.espresso.core)
    androidTestImplementation(libs.uiautomator)
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.kotlinx.coroutines.test)
}
