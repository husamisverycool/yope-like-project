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
)
