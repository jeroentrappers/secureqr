import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
}

// Release signing — three sources tried in order (same scheme as gpsinfo):
//   1. keystore.properties in this directory (gitignored; the normal path)
//   2. FASTLANE_SECUREQR_* environment variables (CI-friendly)
//   3. No signing config — gradle still builds, just an unsigned artifact
//
//   storeFile      / FASTLANE_SECUREQR_KEYSTORE_FILE      absolute path to the .jks
//   storePassword  / FASTLANE_SECUREQR_KEYSTORE_PASSWORD
//   keyAlias       / FASTLANE_SECUREQR_KEY_ALIAS
//   keyPassword    / FASTLANE_SECUREQR_KEY_PASSWORD
val keystoreProperties = Properties().apply {
    val file = rootProject.file("keystore.properties")
    if (file.isFile) file.inputStream().use { load(it) }
}

fun signingValue(propertyName: String, envName: String): String? =
    keystoreProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }
        ?: System.getenv(envName)?.takeIf { it.isNotBlank() }

val releaseStoreFile = signingValue("storeFile", "FASTLANE_SECUREQR_KEYSTORE_FILE")
val releaseStorePassword = signingValue("storePassword", "FASTLANE_SECUREQR_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "FASTLANE_SECUREQR_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "FASTLANE_SECUREQR_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseStoreFile, releaseStorePassword, releaseKeyAlias, releaseKeyPassword,
).all { it != null }

val apiBaseUrlOverride = providers.gradleProperty("secureqr.apiBaseUrl").orNull?.takeIf { it.isNotBlank() }

fun apiBaseUrl(default: String): String =
    "\"${(apiBaseUrlOverride ?: default).trimEnd('/')}\""

android {
    namespace = "be.appmire.secureqr"
    compileSdk = 36

    defaultConfig {
        applicationId = "be.appmire.secureqr"
        minSdk = 26
        targetSdk = 36
        // Literals on purpose: `fastlane bump` rewrites these two lines.
        versionCode = 1
        versionName = "1.0.0"
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = rootProject.file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".debug"
            buildConfigField("String", "API_BASE_URL", apiBaseUrl("http://10.0.2.2:8080"))
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            buildConfigField("String", "API_BASE_URL", apiBaseUrl("https://qr.appmire.be"))
            signingConfig = signingConfigs.findByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }

    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
    }

    lint {
        abortOnError = true
        checkReleaseBuilds = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.androidx.lifecycle.viewmodel.compose)
    implementation(libs.androidx.datastore.preferences)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.foundation)
    implementation(libs.compose.material3)
    implementation(libs.compose.ui.tooling.preview)
    debugImplementation(libs.compose.ui.tooling)

    implementation(libs.camerax.core)
    implementation(libs.camerax.camera2)
    implementation(libs.camerax.lifecycle)
    implementation(libs.camerax.view)
    implementation(libs.mlkit.barcode)

    implementation(libs.okhttp)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.kotlinx.coroutines.android)
    implementation(libs.coil.compose)
    implementation(libs.coil.network.okhttp)

    testImplementation(libs.junit)
}
