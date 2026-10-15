// RevenueCat wrapper: entitlement `premium`, offerings, purchase, restore, customer-info flow. No UI.
plugins {
    alias(libs.plugins.android.library)
}

val revenuecatKey = rootProject.extra["app.revenuecatAndroidApiKey"] as String?
val premiumEntitlement = rootProject.extra["app.premiumEntitlement"] as String

android {
    namespace = "app.billing"
    buildFeatures { buildConfig = true }
    defaultConfig {
        // From config/app.json `revenuecat`. A null key leaves billing unconfigured (not premium).
        buildConfigField("String", "REVENUECAT_API_KEY", revenuecatKey?.let { "\"$it\"" } ?: "null")
        buildConfigField("String", "PREMIUM_ENTITLEMENT", "\"$premiumEntitlement\"")
    }
}

dependencies {
    api(libs.revenuecat.purchases)
    implementation(libs.kotlinx.coroutines.android)

    testImplementation(libs.bundles.robolectric.test)
}
