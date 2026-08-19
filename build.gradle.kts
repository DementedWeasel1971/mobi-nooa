// Root build file. Individual module configuration lives in each module's
// build.gradle.kts (e.g. android_mobi_nooa/build.gradle.kts).

// Explicit repositories on every subproject (in addition to
// dependencyResolutionManagement in settings.gradle.kts). Needed because
// detached configurations created by AGP tasks (e.g. resolving aapt2) don't
// always honor dependencyResolutionManagement the same way regular
// dependency configurations do.
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}
