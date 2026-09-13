plugins {
    id("com.android.application")
}

android {
    namespace = "com.lint.share"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.lint.share"
        minSdk = 24
        targetSdk = 36
        versionCode = 2
        versionName = "0.2.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

dependencies {
    implementation("com.google.android.material:material:1.14.0")
    testImplementation("junit:junit:4.13.2")
}
