import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension
import org.gradle.process.CommandLineArgumentProvider

plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
    alias(libs.plugins.google.services) apply false
    alias(libs.plugins.roborazzi) apply false
}

// ---------------------------------------------------------------------------------------------
// config/app.json is the single source of app configuration (owner-controlled; see
// docs/OWNER_SETUP.md). Values are exposed to modules as root-project extras.
// ---------------------------------------------------------------------------------------------
val appConfigFile = rootDir.resolve("../config/app.json")

@Suppress("UNCHECKED_CAST")
val appConfig = groovy.json.JsonSlurper().parse(appConfigFile) as Map<String, Any?>

fun configValue(vararg path: String): Any? {
    var node: Any? = appConfig
    for (key in path) node = (node as? Map<*, *>)?.get(key) ?: return null
    return node
}

extra["app.configFile"] = appConfigFile
extra["app.applicationId"] = configValue("android", "applicationId") as String
extra["app.minSdk"] = (configValue("android", "minSdk") as Number).toInt()
extra["app.targetSdk"] = (configValue("android", "targetSdk") as Number).toInt()
// compileSdk only selects which APIs are visible to the compiler; runtime behaviour follows
// targetSdk above. Compose 1.12 (BOM 2026.09.00) and navigation-compose 2.10 declare
// minCompileSdk 37, so the compile level is the higher of the two.
extra["app.compileSdk"] = maxOf((configValue("android", "targetSdk") as Number).toInt(), 37)
extra["app.domain"] = configValue("domain", "value") as String?
extra["app.displayName"] = configValue("displayName", "value") as String?
extra["app.revenuecatAndroidApiKey"] = configValue("revenuecat", "androidApiKey") as String?
extra["app.premiumEntitlement"] = configValue("revenuecat", "entitlement") as String

// ---------------------------------------------------------------------------------------------
// Shared Android module setup.
// ---------------------------------------------------------------------------------------------
val compileSdkLevel = extra["app.compileSdk"] as Int
val minSdkLevel = extra["app.minSdk"] as Int
val targetSdkLevel = extra["app.targetSdk"] as Int

/**
 * Robolectric runs offline against the android-all jar that Gradle resolves (from the project's
 * own repositories, with Gradle's cache), instead of downloading it from inside the test JVM.
 */
class RobolectricOfflineArgs(
    @get:InputFiles
    @get:PathSensitive(PathSensitivity.NONE)
    val sdkJars: FileCollection,
) : CommandLineArgumentProvider {
    override fun asArguments(): Iterable<String> = listOf(
        "-Drobolectric.offline=true",
        "-Drobolectric.dependency.dir=${sdkJars.singleFile.parentFile.absolutePath}",
    )
}

fun Project.configureAndroidTests() {
    val robolectricSdk = configurations.create("robolectricSdk") {
        isCanBeConsumed = false
        isCanBeResolved = true
        isTransitive = false
    }
    dependencies.add(robolectricSdk.name, rootProject.libs.robolectric.androidAll)
    tasks.withType<Test>().configureEach {
        jvmArgumentProviders.add(RobolectricOfflineArgs(robolectricSdk))
        maxHeapSize = "3g"
        // Robolectric's API 36 sandbox reflects into jdk.internal.access on JDK 21.
        jvmArgs("--add-opens=java.base/jdk.internal.access=ALL-UNNAMED")
        testLogging { events("failed"); exceptionFormat = org.gradle.api.tasks.testing.logging.TestExceptionFormat.FULL }
    }
}

subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileSdk = compileSdkLevel
            defaultConfig { minSdk = minSdkLevel }
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
            testOptions {
                targetSdk = targetSdkLevel
                unitTests.isIncludeAndroidResources = true
            }
            lint { targetSdk = targetSdkLevel }
        }
        configureAndroidTests()
    }
    pluginManager.withPlugin("com.android.application") {
        extensions.configure<ApplicationExtension> {
            compileSdk = compileSdkLevel
            defaultConfig {
                minSdk = minSdkLevel
                targetSdk = targetSdkLevel
            }
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
            testOptions { unitTests.isIncludeAndroidResources = true }
        }
        configureAndroidTests()
    }
}
