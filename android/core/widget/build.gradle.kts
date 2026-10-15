// Home-screen widgets: per-group rendition store, Glance widget + receiver, configuration
// activity container, and the WorkManager worker that downloads renditions and refreshes widgets.
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
}

android {
    namespace = "app.widget"
    buildFeatures { compose = true }
}

dependencies {
    api(project(":core:model"))
    implementation(project(":core:links"))
    // Widget UI (surfaces widget.android, widget.home.*, widget.arrival): tokens and copy.
    implementation(project(":core:designsystem"))
    api(libs.glance.appwidget)
    api(libs.work.runtime)
    implementation(libs.androidx.core)
    implementation(libs.androidx.activity.compose)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.bundles.robolectric.test)
    testImplementation(libs.work.testing)
}
