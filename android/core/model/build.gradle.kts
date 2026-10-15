import org.jetbrains.kotlin.gradle.dsl.JvmTarget

// Pure Kotlin/JVM: routing, gates, time math and widget models — unit-tested without Android.
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions { jvmTarget.set(JvmTarget.JVM_17) }
}

dependencies {
    api(libs.kotlinx.serialization.json)
    api(libs.kotlinx.coroutines.core)

    testImplementation(libs.junit)
    testImplementation(libs.kotlinx.coroutines.test)
}

// CI runs `testDebugUnitTest` across the build; a JVM module has only `test`, so alias it.
tasks.register("testDebugUnitTest") {
    group = "verification"
    description = "Runs this JVM module's unit tests (alias of `test` for the Android-wide task name)."
    dependsOn(tasks.named("test"))
}
