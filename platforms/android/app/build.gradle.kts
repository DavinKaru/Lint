import java.util.Properties

plugins {
    id("com.android.application")
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.lint.share"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.lint.share"
        minSdk = 24
        targetSdk = 36
        versionCode = 5
        versionName = "0.4.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        // Only wired up if keystore.properties exists locally (gitignored, never committed) --
        // release builds without it fail fast with a clear "keystore not found" error rather
        // than silently falling back to an unsigned or debug-signed APK.
        if (keystorePropertiesFile.exists()) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }

    testOptions {
        unitTests.all { test ->
            // The link-case test set shared with iOS (see shared/tests/README.md). Declared as an
            // input so Gradle re-runs the tests when it changes.
            val sharedLinkCases = rootProject.file("../../shared/tests/link-cases.json")
            test.inputs.file(sharedLinkCases)
            test.systemProperty("lint.sharedLinkCases", sharedLinkCases.absolutePath)
        }
    }
}

dependencies {
    implementation("com.google.android.material:material:1.14.0")
    testImplementation("junit:junit:4.13.2")
    // Real org.json for reading shared/tests/link-cases.json: the copy in android.jar is a stub in
    // JVM unit tests.
    testImplementation("org.json:json:20240303")
}
