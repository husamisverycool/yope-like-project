// Test-only helpers shared by the modules' unit tests (`testImplementation` only; never part of the app):
// the real sample photos in fixtures/photos/ at the repository root (see its INDEX.md) as files,
// bitmaps, painters and a Coil image loader. The root build script passes the photo directory to
// every unit-test JVM (`-Dapp.samplePhotos`).
plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "app.testing"
}

dependencies {
    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui.graphics)
    // Screens that load storage URLs through Coil (`AsyncImage`) get the photos from an interceptor.
    implementation(libs.coil.compose)
}
