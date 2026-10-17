// Single-activity Compose host. Store identity (applicationId) and the invite-link domain come
// from config/app.json; Kotlin namespaces are fixed (app.*) so owner changes need no code edits.
plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.roborazzi)
}

val appId = rootProject.extra["app.applicationId"] as String
val appDomain = rootProject.extra["app.domain"] as String?
val appDisplayName = rootProject.extra["app.displayName"] as String?
val appConfigFile = rootProject.extra["app.configFile"] as File

// Firebase config is git-ignored and absent on CI: apply google-services only when it exists.
// Without it the app builds and runs; push is simply unavailable (core:push FirebaseBootstrap).
if (file("google-services.json").exists()) {
    apply(plugin = libs.plugins.google.services.get().pluginId)
}

// Release signing and build number ("send Jolt to Google Play", tools/release/android_key.py): the upload key comes
// from the environment, never from the repository; -Papp.versionCode=<n> sets the build number. Without them release
// builds are unsigned with versionCode 1.
val uploadStoreFile = providers.environmentVariable("ANDROID_UPLOAD_STORE_FILE").orNull
val releaseVersionCode = providers.gradleProperty("app.versionCode").orNull?.toInt()

android {
    namespace = "app.main"
    signingConfigs {
        if (uploadStoreFile != null) {
            create("upload") {
                val storePass = providers.environmentVariable("ANDROID_KEYSTORE_PASSWORD").get()
                storeFile = file(uploadStoreFile)
                storePassword = storePass
                keyAlias = providers.environmentVariable("ANDROID_UPLOAD_KEY_ALIAS").orNull ?: "upload"
                keyPassword = providers.environmentVariable("ANDROID_UPLOAD_KEY_PASSWORD").orNull ?: storePass
            }
        }
    }
    defaultConfig {
        applicationId = appId
        versionCode = releaseVersionCode ?: 1
        // The same version as the iPhone app (ios/Config/Base.xcconfig MARKETING_VERSION); the build number is versionCode.
        versionName = "1.0"
        // App Links host for https://<domain>/i/<token>. While `domain` is BLOCKED a reserved
        // never-resolving name (RFC 2606 .invalid) keeps the filter inert.
        manifestPlaceholders["appLinkHost"] = appDomain ?: "unset.invalid"
        // The name under the icon: config/app.json displayName (owner decision 0.1); release builds refuse a missing one.
        manifestPlaceholders["appLabel"] = appDisplayName ?: "{app_name}"
        // On-device end-to-end journey (src/androidTest/kotlin/app/main/e2e/JourneyTest.kt): the runner points the app at the Supabase stack
        // named by the instrumentation arguments `supabaseUrl` / `supabaseAnonKey` before the app starts.
        testInstrumentationRunner = "app.main.e2e.E2eRunner"
    }
    testOptions {
        // Window and transition animations off while instrumented tests run (AGP passes --no-window-animation).
        animationsDisabled = true
    }
    buildFeatures {
        compose = true
        buildConfig = true
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            if (uploadStoreFile != null) signingConfig = signingConfigs.getByName("upload")
        }
    }
}

roborazzi {
    // Baselines live with the tests: `./gradlew :app:recordRoborazziDebug` writes them,
    // `./gradlew :app:verifyRoborazziDebug` compares against them.
    outputDir.set(layout.projectDirectory.dir("src/test/snapshots"))
}

// config/app.json: release builds refuse BLOCKED owner values (docs/OWNER_SETUP.md).
val checkReleaseConfig = tasks.register("checkReleaseConfig") {
    val blocked = listOfNotNull(
        "displayName".takeIf { appDisplayName == null },
        "domain".takeIf { appDomain == null },
    )
    val config = appConfigFile.path
    doLast {
        if (blocked.isNotEmpty()) throw GradleException("$config: BLOCKED values must be set for a release build: ${blocked.joinToString()}")
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(checkReleaseConfig) }

dependencies {
    implementation(project(":core:designsystem"))
    implementation(project(":core:model"))
    implementation(project(":core:media"))
    implementation(project(":core:voice"))
    implementation(project(":core:widget"))
    implementation(project(":core:push"))
    implementation(project(":core:billing"))
    implementation(project(":core:links"))
    implementation(project(":core:data"))
    implementation(project(":core:ui"))
    implementation(project(":feature:account"))
    implementation(project(":feature:capture"))
    implementation(project(":feature:social"))
    implementation(project(":feature:memory"))

    implementation(libs.androidx.core)
    implementation(libs.androidx.activity.compose)
    implementation(libs.androidx.navigation.compose)
    implementation(libs.androidx.lifecycle.runtime.compose)
    implementation(libs.coil.compose)
    debugImplementation(libs.compose.ui.tooling)
    debugImplementation(libs.compose.ui.test.manifest)

    testImplementation(libs.bundles.robolectric.test)
    testImplementation(libs.compose.ui.test.junit4)
    testImplementation(libs.roborazzi)
    testImplementation(libs.roborazzi.compose)
    testImplementation(libs.roborazzi.junit.rule)

    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.rules)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.core)
}

// The end-to-end journey's "camera" photo: the emulator camera cannot take a real photo, so the test's camera controller
// (src/androidTest, through the capture group's `CameraControllers.factory` seam) returns this sample photo from
// fixtures/photos/ (licence: fixtures/photos/LICENSE.md). Packaged into the test APK's assets only.
abstract class E2eFixturesTask : DefaultTask() {
    @get:InputFile
    @get:PathSensitive(PathSensitivity.NONE)
    abstract val photo: RegularFileProperty

    @get:OutputDirectory
    abstract val outputDir: DirectoryProperty

    @TaskAction
    fun copy() {
        val dir = outputDir.get().asFile
        dir.deleteRecursively()
        dir.mkdirs()
        photo.get().asFile.copyTo(File(dir, "e2e-photo.jpg"))
    }
}

val e2eFixtures = tasks.register<E2eFixturesTask>("e2eFixtures") {
    photo.set(rootDir.resolve("../fixtures/photos/coffee-cup-top-1x1.jpg"))
    outputDir.set(layout.buildDirectory.dir("generated/e2e/assets"))
}

androidComponents {
    onVariants(selector().withBuildType("debug")) { variant ->
        variant.deviceTests.values.forEach { test -> test.sources.assets?.addGeneratedSourceDirectory(e2eFixtures, E2eFixturesTask::outputDir) }
    }
}
