import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use(keystoreProperties::load)
}

fun signingValue(propertyName: String, environmentName: String): String? =
    System.getenv(environmentName)?.takeIf { it.isNotBlank() }
        ?: keystoreProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val releaseStoreFilePath = signingValue("storeFile", "ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingValue("storePassword", "ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingValue("keyAlias", "ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingValue("keyPassword", "ANDROID_KEY_PASSWORD")
val hasReleaseSigningConfig =
    listOf(
        releaseStoreFilePath,
        releaseStorePassword,
        releaseKeyAlias,
        releaseKeyPassword,
    ).all { it != null }

val releaseBuildRequested =
    gradle.startParameter.taskNames.any { taskName ->
        taskName.contains("release", ignoreCase = true)
    }

if (releaseBuildRequested && !hasReleaseSigningConfig) {
    throw GradleException(
        """
        Konfigurasi signing release belum lengkap.
        Salin android/key.properties.example menjadi android/key.properties,
        lalu isi storeFile, storePassword, keyAlias, dan keyPassword.
        Alternatif CI: gunakan ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD,
        ANDROID_KEY_ALIAS, dan ANDROID_KEY_PASSWORD.
        """.trimIndent(),
    )
}

val releaseStoreFile =
    releaseStoreFilePath?.let { path ->
        rootProject.file(path)
    }

if (releaseBuildRequested && releaseStoreFile?.exists() == false) {
    throw GradleException(
        "File keystore tidak ditemukan: ${releaseStoreFile.absolutePath}",
    )
}

val configuredApplicationId =
    System.getenv("ANDROID_APPLICATION_ID")?.takeIf { it.isNotBlank() }
        ?: providers.gradleProperty("WEBVIEW_APPLICATION_ID").orNull
        ?: "com.tukugaming.app"
val configuredAppName =
    System.getenv("ANDROID_APP_NAME")?.takeIf { it.isNotBlank() }
        ?: providers.gradleProperty("WEBVIEW_APP_NAME").orNull
        ?: "WebView App"

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.webview.wrapper"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = configuredApplicationId
        manifestPlaceholders["appName"] = configuredAppName
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = requireNotNull(releaseStoreFile)
                storePassword = requireNotNull(releaseStorePassword)
                keyAlias = requireNotNull(releaseKeyAlias)
                keyPassword = requireNotNull(releaseKeyPassword)
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            }
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
