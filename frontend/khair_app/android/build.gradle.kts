plugins {
    id("com.google.gms.google-services") version "4.4.2" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// flutter_app_badger 1.5.0 declares Android SDK 29, but its merged AndroidX
// resources reference android:lStar (introduced in API 31). Keep the plugin
// enabled while compiling its library resources with the application's SDK.
subprojects {
    afterEvaluate {
        if (name == "flutter_app_badger") {
            extensions.findByType<com.android.build.api.dsl.LibraryExtension>()
                ?.compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
