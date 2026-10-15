// Shared UI components (owned by the account screens pass) and navigation helpers used by every
// feature module. Components take their values from generated Tokens / R.string only.
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "app.ui"
    buildFeatures { compose = true }
}

dependencies {
    api(project(":core:designsystem"))
    api(project(":core:model"))
    api(libs.androidx.navigation.compose)
    api(libs.androidx.lifecycle.runtime.compose)
    api(libs.coil.compose)
    implementation(libs.androidx.core)

    testImplementation(libs.bundles.robolectric.test)
    testImplementation(libs.compose.ui.test.junit4)
}
