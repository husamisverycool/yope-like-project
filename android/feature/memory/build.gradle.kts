// Feature module: the memory group's screens (design/surfaces/, docs/SCREENS_BRIEF.md).
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
}

android {
    namespace = "app.feature.memory"
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
    implementation(libs.androidx.core)
    implementation(libs.androidx.activity.compose)
    // ViewModels per destination (version from the shared lifecycle line).
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:${libs.versions.lifecycle.get()}")
    // Platform activity indicator (CircularProgressIndicator, easing.global.native activityIndicator).
    implementation("androidx.compose.material3:material3")
    // birthday.tribute: Media3 PlayerView with default controls (layout.birthday.tribute.player).
    implementation(libs.media3.exoplayer)
    implementation("androidx.media3:media3-ui:${libs.versions.media3.get()}")
    // Coil fetches signed https URLs only with a network fetcher on the classpath (auto-registered).
    implementation("io.coil-kt.coil3:coil-network-okhttp:${libs.versions.coil.get()}")
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.bundles.robolectric.test)
    // Real sample photos (fixtures/photos/) for the snapshot fixtures.
    testImplementation(project(":core:testing"))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
}
