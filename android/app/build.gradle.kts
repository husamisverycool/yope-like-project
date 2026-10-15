// Single-activity Compose host. Store identity (applicationId) and the invite-link domain come
// from config/app.json; Kotlin namespaces are fixed (app.*) so owner changes need no code edits.
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
}

val appId = rootProject.extra["app.applicationId"] as String
val appDomain = rootProject.extra["app.domain"] as String?
val appDisplayName = rootProject.extra["app.displayName"] as String?
val appConfigFile = rootProject.extra["app.configFile"] as File

// Firebase config is git-ignored and absent on CI: apply google-services only when it exists.
// Without it the app builds and runs; push is simply unavailable (core:push FirebaseBootstrap).
if (file("google-services.json").exists()) {
    apply(plugin = libs.plugins.google.services.get().pluginId)
}

android {
    namespace = "app.main"
    defaultConfig {
        applicationId = appId
        versionCode = 1
        versionName = "0.1.0"
        // App Links host for https://<domain>/i/<token>. While `domain` is BLOCKED a reserved
        // never-resolving name (RFC 2606 .invalid) keeps the filter inert.
        manifestPlaceholders["appLinkHost"] = appDomain ?: "unset.invalid"
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }
}

roborazzi {
    // Baselines live with the tests: `./gradlew :app:recordRoborazziDebug` writes them,
    // `./gradlew :app:verifyRoborazziDebug` compares against them.
    outputDir.set(layout.projectDirectory.dir("src/test/snapshots"))
}

// config/app.json: release builds refuse BLOCKED owner values (docs/OWNER_SETUP.md).
val checkReleaseConfig = tasks.register("checkReleaseConfig") {
    val blocked = listOfNotNull(
        "displayName".takeIf { appDisplayName == null },
        "domain".takeIf { appDomain == null },
    )
    val config = appConfigFile.path
    doLast {
        if (blocked.isNotEmpty()) throw GradleException("$config: BLOCKED values must be set for a release build: ${blocked.joinToString()}")
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(checkReleaseConfig) }

dependencies {
    implementation(project(":core:designsystem"))
    implementation(project(":core:model"))
    implementation(project(":core:media"))
    implementation(project(":core:voice"))
    implementation(project(":core:widget"))
    implementation(project(":core:push"))
    implementation(project(":core:billing"))
    implementation(project(":core:links"))
    implementation(project(":core:data"))
    implementation(project(":core:ui"))
    implementation(project(":feature:account"))
    implementation(project(":feature:capture"))
    implementation(project(":feature:social"))
    implementation(project(":feature:memory"))

    implementation(libs.androidx.core)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.coil.compose)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.bundles.robolectric.test)
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
}
