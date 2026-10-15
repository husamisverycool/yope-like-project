// App Links + in-app deep links: Intent → DeepLink, and DeepLink → explicit Intent / PendingIntent.
plugins {
    alias(libs.plugins.android.library)
}

val appDomain = rootProject.extra["app.domain"] as String?

android {
    namespace = "app.links"
    buildFeatures { buildConfig = true }
    defaultConfig {
        // config/app.json `domain` (null while BLOCKED: invite links are then not recognised).
        buildConfigField("String", "APP_LINK_DOMAIN", appDomain?.let { "\"$it\"" } ?: "null")
    }
}

dependencies {
    api(project(":core:model"))
    implementation(libs.androidx.core)

    testImplementation(libs.bundles.robolectric.test)
}
