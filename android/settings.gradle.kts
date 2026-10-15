pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "groupphotos"

include(
    ":app",
    ":core:designsystem",
    ":core:model",
    ":core:media",
    ":core:voice",
    ":core:widget",
    ":core:push",
    ":core:billing",
    ":core:links",
    ":core:data",
    ":core:ui",
    // Unit-test helpers only (sample photos from fixtures/photos/); never an app dependency.
    ":core:testing",
    ":feature:account",
    ":feature:capture",
    ":feature:social",
    ":feature:memory",
)
