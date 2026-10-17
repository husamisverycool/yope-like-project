// Feature module: the capture group's screens (design/surfaces/, docs/SCREENS_BRIEF.md):
// camera.capture, camera.sendto, camera.fromwidget, daily.capture (+ daily.dualimage),
// collage.view, collage.share, and the widget configuration picker (widget.android).
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
}

android {
    namespace = "app.feature.capture"
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
    implementation(platform(libs.compose.bom))
    // The widget configuration picker is a system surface: Material 3 list (widget.android).
    implementation("androidx.compose.material3:material3")
    implementation("androidx.lifecycle:lifecycle-viewmodel-compose:${libs.versions.lifecycle.get()}")
    implementation(libs.kotlinx.coroutines.android)
    // camera.trim: a library video longer than camera.capture.duration.videoMax is clipped on the device.
    implementation(libs.media3.exoplayer)
    implementation("androidx.media3:media3-transformer:${libs.versions.media3.get()}")
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.bundles.robolectric.test)
    // Real sample photos (fixtures/photos/) for the snapshot fixtures.
    testImplementation(project(":core:testing"))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
    testImplementation(libs.work.testing)
}
