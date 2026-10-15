// Camera (CameraX: still, video, concurrent front+back with sequential fallback), permission
// states, image encoding (downscale, JPEG, no location), Photo Picker import.
plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "app.media"
}

dependencies {
    api(libs.camerax.core)
    api(libs.camerax.lifecycle)
    api(libs.camerax.video)
    // CameraXViewfinder for the screens pass's preview composables.
    api(libs.camerax.compose)
    implementation(libs.camerax.camera2)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.exifinterface)
    implementation(libs.androidx.core)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.bundles.robolectric.test)
}
