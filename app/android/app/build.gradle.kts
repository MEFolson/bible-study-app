import com.android.build.api.variant.FilterConfiguration
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing. Create android/key.properties (gitignored, never committed) with
// storeFile, storePassword, keyAlias and keyPassword, pointing at the release keystore kept
// off the repository (CI writes both from repository secrets). Since 1.0.2 a release build
// without key.properties stops with an error instead of quietly signing with the Flutter
// debug key; set ZAGROS_ALLOW_DEBUG_RELEASE=1 only for a local test build.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
val allowDebugRelease = System.getenv("ZAGROS_ALLOW_DEBUG_RELEASE") == "1"

// Android versionCode scheme (since 1.0.2):
//   versionCode = pubspec build number * 10 + ABI digit
//   ABI digit: 1 armeabi-v7a, 2 arm64-v8a, 4 x86_64, 9 universal APK
// Every APK of a newer build therefore has a higher code than every APK of an older build,
// whichever ABI or universal file the phone had, so upgrades always install. Within one build
// the universal APK is highest, so it can replace a per ABI APK of the same build.
// Flutter's own per ABI offset (1000 * ABI) is switched off here so it cannot clash.
extra["force-version-code-ignoring-abi"] = "true"

android {
    namespace = "com.mfolson.biblestudy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    defaultConfig {
        applicationId = "com.mfolson.biblestudy"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Base value only; each APK's final versionCode is set in androidComponents below.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

androidComponents {
    onVariants { variant ->
        for (output in variant.outputs) {
            val abi =
                output.filters
                    .firstOrNull { it.filterType == FilterConfiguration.FilterType.ABI }
                    ?.identifier
            val digit =
                when (abi) {
                    null -> 9
                    "armeabi-v7a" -> 1
                    "arm64-v8a" -> 2
                    "x86_64" -> 4
                    else -> throw GradleException("No versionCode digit for ABI $abi")
                }
            output.versionCode.set(flutter.versionCode * 10 + digit)
        }
    }
}

gradle.taskGraph.whenReady {
    val releasePackaging = allTasks.any { it.name.startsWith("package") && it.name.endsWith("Release") }
    if (releasePackaging && !keystorePropertiesFile.exists() && !allowDebugRelease) {
        throw GradleException(
            "android/key.properties is missing, so this release build would be signed with the " +
                "debug key. Add key.properties (see app/README.md) or set ZAGROS_ALLOW_DEBUG_RELEASE=1 " +
                "for a local test build.",
        )
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
