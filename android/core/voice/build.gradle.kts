// Voice messages and voice notes: MediaRecorder (AAC in .m4a) with amplitude sampling for
// waveforms, Media3 playback. Durations are milliseconds throughout.
plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "app.voice"
}

dependencies {
    api(libs.media3.exoplayer)
    implementation(libs.androidx.core)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.bundles.robolectric.test)
}
