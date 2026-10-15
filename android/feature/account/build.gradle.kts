// Feature module: the account group's screens (design/surfaces/, docs/SCREENS_BRIEF.md).
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
}

// config/app.json `legal.*` (BLOCKED while null: the links have no destination and the rows that
// need them are omitted). Read here so the module needs no change when the owner sets them.
@Suppress("UNCHECKED_CAST")
val appConfig = groovy.json.JsonSlurper().parse(rootProject.extra["app.configFile"] as File) as Map<String, Any?>
fun configString(vararg path: String): String? {
    var node: Any? = appConfig
    for (key in path) node = (node as? Map<*, *>)?.get(key) ?: return null
    return node as? String
}
fun quoted(value: String?): String = value?.let { "\"$it\"" } ?: "null"

android {
    namespace = "app.feature.account"
    buildFeatures {
        compose = true
        buildConfig = true
    }
    defaultConfig {
        buildConfigField("String", "LEGAL_TERMS_URL", quoted(configString("legal", "termsUrl")))
        buildConfigField("String", "LEGAL_PRIVACY_URL", quoted(configString("legal", "privacyUrl")))
        // Support address for "Contact Us" (settings.root Gaps: not in config/app.json yet).
        buildConfigField("String", "SUPPORT_EMAIL", quoted(configString("support", "email")))
        buildConfigField("String", "APPLICATION_ID", quoted(configString("android", "applicationId")))
    }
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
    // groups.screen places the memory pass's entries (On This Day, year story, birthday requests).
    implementation(project(":feature:memory"))
    implementation(libs.androidx.core)
    implementation(libs.androidx.activity.compose)
    implementation(libs.kotlinx.coroutines.android)
    // Invite install path (design/surfaces/invite.web.md → Android): Play Install Referrer API.
    implementation("com.android.installreferrer:installreferrer:2.2")
    // auth.code (Android): SMS User Consent API (docs/PLATFORM_CONSTRAINTS.md §7).
    implementation("com.google.android.gms:play-services-auth-api-phone:18.2.0")
    // In-app browser for legal links (auth.phone footer, paywall, settings: Custom Tabs).
    implementation("androidx.browser:browser:1.9.0")
    // auth.phone: region calling code prefill, E.164 normalisation and display formatting.
    implementation("com.googlecode.libphonenumber:libphonenumber:9.0.30")
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.bundles.robolectric.test)
    // Real sample photos (fixtures/photos/) for the snapshot fixtures.
    testImplementation(project(":core:testing"))
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)
}
