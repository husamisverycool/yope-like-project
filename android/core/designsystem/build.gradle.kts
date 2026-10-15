// Design-system primitives (fonts, shadows, springs, reduced motion, haptics, text) and the
// generated Tokens.kt / strings.xml from tools/designgen.mjs. Generated files are never edited.
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "app.designsystem"
    buildFeatures { compose = true }
}

dependencies {
    api(platform(libs.compose.bom))
    api(libs.compose.ui)
    api(libs.compose.ui.graphics)
    api(libs.compose.foundation)
    api(libs.compose.animation)
    // Generated icon tokens reference Material Symbols vectors from this artifact.
    api(libs.compose.material.icons.extended)
    implementation(libs.androidx.core)

    testImplementation(libs.bundles.robolectric.test)
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.compose.ui.test.manifest)
}
