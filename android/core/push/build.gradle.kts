// FCM: data-message handling (widget refresh, daily-invitation countdown, alerts),
// notification channels, token hand-off. Firebase initialises lazily and is optional.
plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "app.push"
}

dependencies {
    api(project(":core:model"))
    implementation(project(":core:links"))
    implementation(project(":core:widget"))
    implementation(platform(libs.firebase.bom))
    implementation(libs.firebase.messaging)
    implementation(libs.androidx.core)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.bundles.robolectric.test)
    testImplementation(libs.work.testing)
}
