// Shared UI components (owned by the account screens pass) and navigation helpers used by every
// feature module. Components take their values from generated Tokens / R.string only.
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
}

android {
    namespace = "app.ui"
    buildFeatures { compose = true }
}

roborazzi {
    // Component baselines live with the tests: `./gradlew :core:ui:recordRoborazziDebug`.
    outputDir.set(layout.projectDirectory.dir("src/test/snapshots"))
}

dependencies {
    api(project(":core:designsystem"))
    api(project(":core:model"))
    api(libs.androidx.navigation.compose)
    api(libs.androidx.lifecycle.runtime.compose)
    api(libs.coil.compose)
    // System surfaces (settings, safety, permissions, dialogs, sheets) are native Material 3
    // components (design/surfaces/settings.root.md, layout.global.system.typography). Version from
    // the Compose BOM that core:designsystem exports.
    api("androidx.compose.material3:material3")
    implementation(libs.androidx.core)
    implementation(libs.androidx.activity.compose)

    testImplementation(libs.bundles.robolectric.test)
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
    debugImplementation(libs.compose.ui.test.manifest)
}
