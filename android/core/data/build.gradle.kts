// Data layer: supabase-kt client (auth, PostgREST, storage, realtime), typed repositories for every
// client-facing operation of docs/API.md, WorkManager media uploads, signed-URL cache, offline page
// cache, connectivity, and the session glue (push token, billing identity, widgets). No UI, no copy:
// errors are typed (DataError) and mapped to string resources by the screens.
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.serialization)
}

val supabaseUrl = rootProject.extra["app.supabaseUrl"] as String?
val supabaseAnonKey = rootProject.extra["app.supabaseAnonKey"] as String?

android {
    namespace = "app.data"
    buildFeatures { buildConfig = true }
    defaultConfig {
        // config/app.json `supabase.url` / `supabase.anonKey`; null leaves the data layer unconfigured.
        buildConfigField("String", "SUPABASE_URL", supabaseUrl?.let { "\"$it\"" } ?: "null")
        buildConfigField("String", "SUPABASE_ANON_KEY", supabaseAnonKey?.let { "\"$it\"" } ?: "null")
    }
}

dependencies {
    api(project(":core:model"))
    implementation(project(":core:push"))
    implementation(project(":core:billing"))
    implementation(project(":core:widget"))

    api(platform(libs.supabase.bom))
    api(libs.supabase.auth)
    api(libs.supabase.postgrest)
    api(libs.supabase.storage)
    api(libs.supabase.realtime)
    implementation(libs.ktor.client.okhttp)
    api(libs.work.runtime)
    implementation(libs.androidx.core)
    implementation(libs.kotlinx.coroutines.android)
    api(libs.kotlinx.serialization.json)

    testImplementation(libs.bundles.robolectric.test)
    testImplementation(libs.work.testing)
    testImplementation(libs.ktor.client.mock)
}

// ---------------------------------------------------------------------------------------------
// Integration tests (app.data.integration.*) talk to the local Supabase stack
// (`cd backend && npm run db:start`). They skip, with the reason printed, when it is not reachable.
// Override the target with -PsupabaseTestUrl=… (and -PsupabaseTestAnonKey / -PsupabaseTestServiceKey),
// or the SUPABASE_URL / SUPABASE_ANON_KEY / SUPABASE_SERVICE_ROLE_KEY environment variables.
// ---------------------------------------------------------------------------------------------
val testStackUrl = providers.gradleProperty("supabaseTestUrl")
    .orElse(providers.environmentVariable("SUPABASE_URL"))
    .orElse("http://127.0.0.1:54321")
val testStackAnonKey = providers.gradleProperty("supabaseTestAnonKey").orElse(providers.environmentVariable("SUPABASE_ANON_KEY"))
val testStackServiceKey = providers.gradleProperty("supabaseTestServiceKey").orElse(providers.environmentVariable("SUPABASE_SERVICE_ROLE_KEY"))

tasks.withType<Test>().configureEach {
    val url = testStackUrl.get()
    systemProperty("supabase.test.url", url)
    testStackAnonKey.orNull?.let { systemProperty("supabase.test.anonKey", it) }
    testStackServiceKey.orNull?.let { systemProperty("supabase.test.serviceKey", it) }
    // The live stack is external state: never reuse a cached or up-to-date result.
    outputs.upToDateWhen { false }
    outputs.cacheIf { false }
    testLogging {
        events("failed", "skipped")
        exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL
    }
    doFirst {
        val reachable = try {
            val connection = java.net.URI("$url/auth/v1/health").toURL().openConnection() as java.net.HttpURLConnection
            connection.connectTimeout = 1500
            connection.readTimeout = 1500
            val code = connection.responseCode
            connection.disconnect()
            code in 200..499
        } catch (_: Exception) {
            false
        }
        if (reachable) {
            logger.lifecycle("core:data integration tests: local Supabase stack reachable at $url — running against it.")
        } else {
            logger.lifecycle("core:data integration tests: local Supabase stack NOT reachable at $url — they will be skipped (start it with `cd backend && npm run db:start`).")
        }
    }
}
