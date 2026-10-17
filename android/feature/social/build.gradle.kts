// Feature module: the social group's screens (design/surfaces/, docs/SCREENS_BRIEF.md).
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.roborazzi)
}

android {
    namespace = "app.feature.social"
    buildFeatures { compose = true }
}

roborazzi {
    // Baselines live with the tests (our own renders): recordRoborazziDebug writes them.
    outputDir.set(layout.projectDirectory.dir("src/test/snapshots"))
}

dependencies {
    implementation(project(":core:ui"))
    implementation(project(":core:designsystem"))
    implementation(project(":core:model"))
    implementation(project(":core:data"))
    implementation(project(":core:media"))
    implementation(project(":core:voice"))
    implementation(project(":core:widget"))
    implementation(project(":core:push"))
    implementation(project(":core:billing"))
    implementation(project(":core:links"))
    // The "i'm in this" self-tag control (design/surfaces/tagging.md) is the memory group's component.
    implementation(project(":feature:memory"))
    implementation(libs.androidx.core)
    implementation(libs.androidx.activity.compose)
    implementation(libs.kotlinx.serialization.json)
    // Native components the specs name for Android (M3 ModalBottomSheet, DropdownMenu, AlertDialog,
    // pull-to-refresh), versioned by the Compose BOM that core:designsystem exports.
    implementation("androidx.compose.material3:material3")
    // Coil 3 loads signed https URLs only with a network fetcher (core:ui exports coil-compose).
    implementation("io.coil-kt.coil3:coil-network-okhttp:3.6.3")
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.bundles.robolectric.test)
    // Real sample photos (fixtures/photos/) for the snapshot fixtures.
    testImplementation(project(":core:testing"))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
}
